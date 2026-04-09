-- Tier-based thermoregulation runtime effects for equipped clothing.

require "ZItemTiers/core"

local logger = ZItemTiers.logger

local DRYING_PER_THERMO_POINT       = 0.10
local MAX_DRYING_PER_MINUTE         = 12.0
local NORMAL_SKIN_TEMP_C            = 33.0
local NORMAL_CORE_TEMP_C            = 37.0
local CORE_COOLING_PER_THERMO_POINT = 0.004
local MAX_CORE_COOLING_PER_MINUTE   = 0.20

local function clamp(v, minV, maxV)
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

local function getBonusValueFromItem(item, getterName, fallbackBonusKey)
    if item[getterName] then
        return item[getterName](item) or 0
    end

    local zit = ZItemTiers.GetZIT(item)
    local bonus = zit and zit.bonuses and fallbackBonusKey and zit.bonuses[fallbackBonusKey]
    return bonus and bonus.modified or 0
end

local function getClothingThermoregulation(clothing)
    return getBonusValueFromItem(clothing, "getThermoregulation", "Thermoregulation")
end

local function applySelfDrying(clothing, thermoreg)
    if not clothing or not clothing.getWetness or not clothing.setWetness then return false end

    local wetness = clothing:getWetness()
    if not wetness or wetness <= 0 then return false end

    if thermoreg <= 0 then return false end

    local dryingPerMinute = thermoreg * DRYING_PER_THERMO_POINT
    if dryingPerMinute <= 0 then return false end

    dryingPerMinute = clamp(dryingPerMinute, 0, MAX_DRYING_PER_MINUTE)
    local newWetness = math.max(0, wetness - dryingPerMinute)
    if newWetness >= wetness then return false end

    logger:debug("Drying clothing '%s': wetness %.2f -> %.2f (thermoreg=%.2f)", clothing:getName(), wetness, newWetness, thermoreg)
    clothing:setWetness(newWetness)
    return true
end

local function applyBodyCooling(player, totalThermoreg)
    if not player or totalThermoreg <= 0 then return false end
    if not player.getBodyDamage or not player.getTemperature or not player.setTemperature then return false end

    local bodyDamage = player:getBodyDamage()
    if not bodyDamage or not bodyDamage.getBodyParts then return false end

    local bodyParts = bodyDamage:getBodyParts()
    if not bodyParts then return false end

    local overheatedParts = 0
    for i = 0, bodyParts:size() - 1 do
        local bp = bodyParts:get(i)
        if bp and bp.getSkinTemperature then
            local skinTemp = bp:getSkinTemperature()
            if skinTemp and skinTemp > NORMAL_SKIN_TEMP_C then
                overheatedParts = overheatedParts + 1
                logger:debug("body part '%s' is overheated: skin temp=%.2fC", bp:getType(), skinTemp)
            end
        end
    end

    if overheatedParts <= 0 then return false end

    local currentCoreTemp = player:getTemperature()
    if not currentCoreTemp or currentCoreTemp <= NORMAL_CORE_TEMP_C then
        return false
    end

    local coolingDelta = totalThermoreg * CORE_COOLING_PER_THERMO_POINT
    coolingDelta = clamp(coolingDelta, 0, MAX_CORE_COOLING_PER_MINUTE)
    if coolingDelta <= 0 then return false end

    local newCoreTemp = math.max(NORMAL_CORE_TEMP_C, currentCoreTemp - coolingDelta)
    if newCoreTemp >= currentCoreTemp then return false end

    player:setTemperature(newCoreTemp)
    return true
end

local function forEachEquippedClothing(player, fn)
    if not player or player:isDead() then return end
    if not player.getWornItems then return end

    local wornItems = player:getWornItems()
    if not wornItems then return end

    local count = wornItems:size()
    for i = 0, count - 1 do
        local worn = wornItems:get(i)
        local item = worn and worn:getItem() or nil
        if item and instanceof(item, "Clothing") then
            fn(item)
        end
    end
end

local function onEveryOneMinute()
    local totalDryingOps = 0
    local totalCoolingOps = 0

    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        local totalThermoreg = 0
        forEachEquippedClothing(player, function(clothing)
            local thermoreg = getClothingThermoregulation(clothing)
            if thermoreg > 0 then
                totalThermoreg = totalThermoreg + thermoreg
            end

            if applySelfDrying(clothing, thermoreg) then
                totalDryingOps = totalDryingOps + 1
            end
        end)

        if applyBodyCooling(player, totalThermoreg) then
            totalCoolingOps = totalCoolingOps + 1
        end
    end

    if totalDryingOps > 0 or totalCoolingOps > 0 then
        logger:debug("Applied thermoregulation effects: drying=%d, cooling=%d", totalDryingOps, totalCoolingOps)
    end
end

Events.EveryOneMinute.Add(onEveryOneMinute)

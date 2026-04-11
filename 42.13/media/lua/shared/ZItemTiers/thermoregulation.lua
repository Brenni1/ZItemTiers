-- Tier-based thermoregulation runtime effects for equipped clothing.

require "ZItemTiers/core"

local logger = ZItemTiers.logger

local DRYING_PER_THERMO_POINT       = 0.10
local MAX_DRYING_PER_MINUTE         = 12.0
local NORMAL_SKIN_TEMP_C            = 33.0
local THERMO_RANGE_SCALE            = 0.01 -- Thermoregulation points to insulation range (10 => +/-0.10)
local MAX_TEMP_DELTA_FOR_FULL_ADAPT = 2.0  -- C above/below normal to reach full +/- range

local function clamp(v, minV, maxV)
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

local function getBonusValueFromItem(item, getterName, fallbackBonusKey)
    if item[getterName] then return item[getterName](item) or 0 end
    local zit = ZItemTiers.GetZIT(item)
    local bonus = zit and zit.bonuses and fallbackBonusKey and zit.bonuses[fallbackBonusKey]
    return bonus and bonus.modified or 0
end

local function getClothingThermoregulation(clothing)
    return getBonusValueFromItem(clothing, "getThermoregulation", "Thermoregulation")
end

local function applySelfDrying(clothing, thermoreg)
    local wetness = clothing:getWetness()
    if wetness <= 0 or thermoreg <= 0 then return false end

    local dryingPerMinute = thermoreg * DRYING_PER_THERMO_POINT
    dryingPerMinute = clamp(dryingPerMinute, 0, MAX_DRYING_PER_MINUTE) -- mostly for future tuning safety
    local newWetness = math.max(0, wetness - dryingPerMinute)
    if newWetness == wetness then return false end

    logger:debug("Drying clothing '%s': wetness %.2f -> %.2f (thermoreg=%.2f)", clothing:getName(), wetness, newWetness, thermoreg)
    clothing:setWetness(newWetness)
    return true
end

local function applyThermoregulatedInsulation(player, clothing, thermoreg)
    local bodyDamage = player:getBodyDamage()
    local coveredParts = clothing:getCoveredParts()
    if thermoreg < 5 or coveredParts:size() == 0 then return false end

    local thermoRegulator = bodyDamage:getThermoregulator()
    local totalSkinTemp = 0
    local coveredCount = 0
    for i = 0, coveredParts:size() - 1 do
        local node = thermoRegulator:getNodeForBloodType( coveredParts:get(i) )
        if node then
            totalSkinTemp = totalSkinTemp + node:getSkinCelcius()
            coveredCount = coveredCount + 1
        end
    end
    if coveredCount == 0 then return false end

    local avgSkinTemp = totalSkinTemp / coveredCount
    logger:debug("Average skin temp for '%s': %.2fC (thermoreg=%.2f)", clothing, avgSkinTemp, thermoreg)

    local baseInsulation = clothing:getScriptItem():getInsulation()
    local range = thermoreg * THERMO_RANGE_SCALE
    local minIns = clamp(baseInsulation - range, 0, 1)
    local maxIns = clamp(baseInsulation + range, 0, 1)

    local tempDelta = avgSkinTemp - NORMAL_SKIN_TEMP_C
    local intensity = clamp(math.abs(tempDelta) / MAX_TEMP_DELTA_FOR_FULL_ADAPT, 0, 1)
    local targetInsulation = baseInsulation

    if tempDelta > 0 then
        -- Covered part is hot: reduce insulation.
        targetInsulation = baseInsulation - range * intensity
    elseif tempDelta < 0 then
        -- Covered part is cold: increase insulation.
        targetInsulation = baseInsulation + range * intensity
    end

    targetInsulation = clamp(targetInsulation, minIns, maxIns)
    local currentInsulation = clothing:getInsulation()
    if math.abs(targetInsulation - currentInsulation) < 0.001 then return false end

    clothing:setInsulation(targetInsulation)
    logger:debug(
        "Thermoregulated insulation '%s': %.3f -> %.3f (base=%.3f, temp=%.2fC, thermoreg=%.2f)",
        clothing:getName(), currentInsulation, targetInsulation, baseInsulation, avgSkinTemp, thermoreg
    )
    return true
end

local function forEachEquippedClothing(player, fn)
    if not player or player:isDead() then return end

    local wornItems = player:getWornItems()
    for i = 0, wornItems:size() - 1 do
        local worn = wornItems:get(i)
        local item = worn:getItem()
        if item and instanceof(item, "Clothing") then
            fn(item)
        end
    end
end

local function onEveryOneMinute()
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        forEachEquippedClothing(player, function(clothing)
            local thermoreg = getClothingThermoregulation(clothing)
            if thermoreg > 0 then
                applySelfDrying(clothing, thermoreg)
                applyThermoregulatedInsulation(player, clothing, thermoreg)
            end
        end)
    end
end

Events.EveryOneMinute.Add(onEveryOneMinute)

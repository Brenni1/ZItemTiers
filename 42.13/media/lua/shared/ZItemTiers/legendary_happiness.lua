local function forEachEquippedLegendaryItem(player, fn)
    if not player or player:isDead() then return end

    local wornItems = player:getWornItems()
    for i = 0, wornItems:size() - 1 do
        local worn = wornItems:get(i)
        local item = worn:getItem()
        if item and ZItemTiers.GetItemTierIndex0(item) == ZItemTiers.T0_LEGENDARY then
            fn(item)
        end
    end
end

local function applyLegendaryHappiness()
    local delta = -ZItemTiers.Legendary_Happiness

    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        local stats = player and player.getStats and player:getStats()
        if stats then
            if stats:get(CharacterStat.UNHAPPINESS) > 0 or stats:get(CharacterStat.STRESS) > 0 then
                forEachEquippedLegendaryItem(player, function(item)
                    stats:add(CharacterStat.STRESS,      delta)
                    stats:add(CharacterStat.UNHAPPINESS, delta)
                end)
            end
        end
    end
end

if ZItemTiers.Legendary_Happiness then
    Events.EveryTenMinutes.Add(applyLegendaryHappiness)
end

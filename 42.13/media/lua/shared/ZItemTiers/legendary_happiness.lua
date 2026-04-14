local function forEachEquippedItem(player, fn)
    if not player or player:isDead() then return end

    local wornItems = player:getWornItems()
    for i = 0, wornItems:size() - 1 do
        local worn = wornItems:get(i)
        local item = worn:getItem()
        if item then
            fn(item)
        end
    end
end

local function applyLegendaryHappiness()
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        local stats = player.getStats and player:getStats()
        local unhappiness = stats and stats:get(CharacterStat.UNHAPPINESS) or 0
        if unhappiness > 0 then
            local changed = false
            forEachEquippedItem(player, function(item)
                local t0 = ZItemTiers.GetItemTierIndex0(item)
                if t0 == ZItemTiers.T0_LEGENDARY then
                    unhappiness = unhappiness - ZItemTiers.Legendary_Happiness
                    changed = true
                end
            end)
            if changed then
                stats:set(CharacterStat.UNHAPPINESS, math.max(unhappiness, 0))
            end
        end
    end
end

if ZItemTiers.Legendary_Happiness then
    Events.EveryTenMinutes.Add(applyLegendaryHappiness)
end

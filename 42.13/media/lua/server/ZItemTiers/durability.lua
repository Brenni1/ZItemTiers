-- Rarity scaling (durability, speed, capacity) based on rarity
-- Hooks into item creation to apply rarity-based scaling

require "ZItemTiers/core"

-- Hook into OnFillContainer event to apply rarity scaling when items are spawned
-- Event signature: (roomName, containerType, itemContainer)
local function onFillContainer(roomName, containerType, itemContainer)
    if not itemContainer then return end
    
    local items = itemContainer:getItems()
    if not items then return end
    
    -- Process all items in the container
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item.getModData then
            -- Safely get modData
            local success, modData = pcall(function() return item:getModData() end)
            if not success or not modData then
                break
            end
            
            -- Only apply if item doesn't already have a rarity assigned
            if not modData.itemRarity then
                -- Skip keys - they don't benefit from rarity (a key either works or it doesn't)
                -- KeyRings are fine though - they can have capacity bonuses
                local isKey = false
                local successKey, resultKey = pcall(function()
                    return instanceof(item, "Key")
                end)
                if successKey and resultKey then
                    isKey = true
                end
                
                if not isKey then
                    -- Check if item has any scalable properties using bonus definitions
                    local hasScalableProperties = false
                    if ZItemTiers and ZItemTiers.Bonuses then
                        for bonusType, bonusData in pairs(ZItemTiers.Bonuses) do
                            if bonusData.checkApplicable then
                                local success, isApplicable = pcall(bonusData.checkApplicable, item)
                                if success and isApplicable then
                                    hasScalableProperties = true
                                    break
                                end
                            end
                        end
                    end
                    
                    -- Apply rarity scaling if item has any scalable properties
                    if hasScalableProperties then
                        if ZItemTiers and ZItemTiers.RollRarity then
                            local rarity = ZItemTiers.RollRarity()
                            if rarity and ZItemTiers.ApplyRarityScaling then
                                local success13 = pcall(function() 
                                    ZItemTiers.ApplyRarityScaling(item, rarity)
                                end)
                                if not success13 then
                                    -- Silently fail if scaling fails
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Hook into OnFillContainer event
Events.OnFillContainer.Add(onFillContainer)

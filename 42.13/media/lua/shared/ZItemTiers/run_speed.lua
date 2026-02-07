-- Run speed modifier bonus module
-- Applies rarity-based run speed modifier bonuses to Clothing items

require "ZItemTiers/core"

-- Apply run speed modifier bonus to a Clothing item
-- bonusValue: The run speed modifier bonus (e.g., 0.1 for +0.1)
function ZItemTiers.ApplyRunSpeedModifier(item, bonusValue)
    if not item or not bonusValue then
        return
    end
    
    if not instanceof(item, "Clothing") then
        return
    end
    
    -- Get the base run speed modifier using shared helper
    local modData = item:getModData()
    local baseRunSpeedMod = ZItemTiers.GetBaseRunSpeedModifier(item, modData)
    
    -- Only apply if the item has a non-default run speed modifier (not 1.0)
    if math.abs(baseRunSpeedMod - 1.0) > 0.001 then
        -- Calculate new value: base + bonus (additive)
        local newRunSpeedMod = baseRunSpeedMod + bonusValue
        
        -- If the base value is negative (below 1.0), cap the result at neutral (1.0)
        -- Items with negative modifiers should never become positive
        if baseRunSpeedMod < 1.0 then
            newRunSpeedMod = math.min(newRunSpeedMod, 1.0)
        end
        
        local successSet = pcall(function()
            if item.setRunSpeedModifier then
                item:setRunSpeedModifier(newRunSpeedMod)
            end
        end)
    end
end

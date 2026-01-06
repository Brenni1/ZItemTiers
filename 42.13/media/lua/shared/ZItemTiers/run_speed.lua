-- Run speed modifier bonus module
-- Applies rarity-based run speed modifier bonuses to Clothing items

require "ZItemTiers/core"

-- Apply run speed modifier bonus to a Clothing item
-- bonusValue: The run speed modifier bonus (e.g., 0.1 for +0.1)
function ZItemTiers.ApplyRunSpeedModifier(item, bonusValue)
    if not item or not bonusValue then
        return
    end
    
    local isClothing = instanceof(item, "Clothing")
    
    if not isClothing then
        return
    end
    
    -- Get the base run speed modifier from the script item (vanilla value)
    local baseRunSpeedMod = 1.0
    local successGetBase, baseValue = pcall(function()
        if item.getScriptItem then
            local scriptItem = item:getScriptItem()
            if scriptItem and scriptItem.runSpeedModifier then
                return scriptItem.runSpeedModifier
            end
        end
        return 1.0
    end)
    if successGetBase and baseValue then
        baseRunSpeedMod = baseValue
    end
    
    -- Only apply if the item has a non-default run speed modifier (not 1.0)
    if math.abs(baseRunSpeedMod - 1.0) > 0.001 then
        -- Get current run speed modifier from the instance
        local successGet, currentRunSpeedMod = pcall(function()
            if item.getRunSpeedModifier then
                return item:getRunSpeedModifier()
            end
            return baseRunSpeedMod
        end)
        
        if successGet then
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
end

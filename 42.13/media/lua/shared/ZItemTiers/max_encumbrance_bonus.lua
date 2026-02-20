-- Max encumbrance bonus module
-- Applies tier-based max encumbrance bonuses to InventoryContainer items

require "ZItemTiers/core"

-- Apply max encumbrance bonus to an InventoryContainer item
-- bonusValue: The flat max encumbrance bonus (e.g., 0.1 for +0.1)
-- modData: The item's modData table (required for storing the bonus)
function ZItemTiers.ApplyMaxEncumbranceBonus(item, bonusValue, modData)
    if not item or not bonusValue or not modData then
        return
    end
    
    if not instanceof(item, "InventoryContainer") then
        return
    end
    
    -- Get base max item size from script item
    local baseMaxItemSize = 0
    local successGetBase, baseValue = pcall(function()
        if item.getScriptItem then
            local scriptItem = item:getScriptItem()
            if scriptItem and scriptItem.getMaxItemSize then
                return scriptItem:getMaxItemSize()
            end
        end
        return 0
    end)
    if successGetBase and baseValue then
        baseMaxItemSize = baseValue
    end
    
    -- Only apply if the container has a max item size (some containers don't have this restriction)
    if baseMaxItemSize > 0 then
        -- Get current max item size from the instance
        local successGet, currentMaxItemSize = pcall(function()
            if item.getMaxItemSize then
                return item:getMaxItemSize()
            end
            return baseMaxItemSize
        end)
        
        if successGet then
            -- Calculate new max item size: base + flat bonus (additive)
            local newMaxItemSize = baseMaxItemSize + bonusValue
            
            -- Store the bonus in modData - the Java patch will read it and apply it
            -- Also store the base value for the Java patch
            modData.itemMaxEncumbranceBonus = bonusValue
            modData.itemMaxEncumbranceBase = baseMaxItemSize
        end
    end
end

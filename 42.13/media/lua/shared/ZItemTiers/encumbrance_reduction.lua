-- Encumbrance reduction bonus module
-- Applies tier-based encumbrance reduction to InventoryContainer items

require "ZItemTiers/core"

-- Apply encumbrance reduction to an InventoryContainer item
-- bonusValue: The flat encumbrance reduction bonus (e.g., 2 for +2)
function ZItemTiers.ApplyEncumbranceReduction(item, bonusValue)
    if not item or not bonusValue then
        return
    end
    
    if not instanceof(item, "InventoryContainer") then
        return
    end
    
    -- Get base encumbrance reduction (weightReduction property) from script item
    local baseEncumbranceReduction = 0
    local successGetBase, baseValue = pcall(function()
        if item.getScriptItem then
            local scriptItem = item:getScriptItem()
            if scriptItem and scriptItem.weightReduction then
                return scriptItem.weightReduction
            end
        end
        return 0
    end)
    if successGetBase and baseValue then
        baseEncumbranceReduction = baseValue
    end
    
    -- Get current encumbrance reduction
    local success, currentEncumbranceReduction = pcall(function()
        if item.getWeightReduction then
            return item:getWeightReduction()
        end
        return baseEncumbranceReduction
    end)
    
    if success then
        -- Add flat encumbrance reduction bonus (additive)
        local newEncumbranceReduction = baseEncumbranceReduction + bonusValue
        -- Cap at 85% (never allow 100% encumbrance reduction)
        newEncumbranceReduction = math.min(newEncumbranceReduction, 85)
        
        local success2 = pcall(function()
            if item.setWeightReduction then
                item:setWeightReduction(newEncumbranceReduction)
            end
        end)
    end
end

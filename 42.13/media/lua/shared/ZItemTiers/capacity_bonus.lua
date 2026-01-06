-- Capacity bonus module
-- Applies rarity-based capacity bonuses to InventoryContainer items

require "ZItemTiers/core"

-- Apply capacity bonus to an InventoryContainer item
-- bonusPercent: The capacity bonus percentage (e.g., 10 for +10%)
function ZItemTiers.ApplyCapacityBonus(item, bonusPercent)
    if not item or not bonusPercent then
        return
    end
    
    local isContainer = false
    local successContainer, resultContainer = pcall(function()
        return instanceof(item, "InventoryContainer")
    end)
    if successContainer and resultContainer then
        isContainer = true
    end
    
    if not isContainer then
        return
    end
    
    -- Get base capacity from script item
    local baseCapacity = 0
    local successGetBase, baseValue = pcall(function()
        if item.getScriptItem then
            local scriptItem = item:getScriptItem()
            if scriptItem and scriptItem.capacity then
                return scriptItem.capacity
            end
        end
        return 0
    end)
    if successGetBase and baseValue then
        baseCapacity = baseValue
    end
    
    -- Get current capacity from the instance
    local successGet, currentCapacity = pcall(function()
        if item.getCapacity then
            return item:getCapacity()
        end
        return baseCapacity
    end)
    
    if successGet then
        -- Calculate new capacity: base * (1 + bonus percentage / 100)
        local capacityMultiplier = 1.0 + (bonusPercent / 100.0)
        local newCapacity = math.floor(baseCapacity * capacityMultiplier + 0.5)  -- Round to nearest integer
        -- Cap at 50 (max capacity for bags)
        newCapacity = math.min(newCapacity, 50)
        
        local successSet = pcall(function()
            if item.setCapacity then
                item:setCapacity(newCapacity)
            end
        end)
    end
end

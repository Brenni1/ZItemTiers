-- Capacity bonus module
-- Applies tier-based capacity bonuses to InventoryContainer items

require "ZItemTiers/core"

-- Get the base (unmodified) capacity for an InventoryContainer item
-- Tries multiple methods and caches the result in modData
local function getBaseCapacity(item, modData)
    -- Use stored base capacity if available and from current session
    if modData and modData.itemCapacityBase and modData.itemCapacityBase > 0 then
        if modData._bonusesApplied == ZItemTiers._bonusesAppliedSessionId then
            return modData.itemCapacityBase
        end
    end

    local baseCapacity = 0

    -- Try script item getter method first (most reliable for true base value)
    local successGetBase, baseValue = pcall(function()
        if item.getScriptItem then
            local scriptItem = item:getScriptItem()
            if scriptItem then
                -- Try method call (works in PZ's Java-to-Lua bridge)
                if scriptItem.getCapacity then
                    return scriptItem:getCapacity()
                end
                -- Fallback: try direct field access
                if scriptItem.capacity then
                    return scriptItem.capacity
                end
            end
        end
        return nil
    end)
    if successGetBase and baseValue and baseValue > 0 then
        baseCapacity = baseValue
    end

    -- Fallback: use item instance's current capacity (correct on first application before any modifications)
    if baseCapacity <= 0 then
        local successGet, currentValue = pcall(function()
            if item.getCapacity then
                return item:getCapacity()
            end
            return 0
        end)
        if successGet and currentValue and currentValue > 0 then
            baseCapacity = currentValue
        end
    end

    -- Store the base capacity in modData for future re-applications
    if modData and baseCapacity > 0 then
        modData.itemCapacityBase = baseCapacity
    end

    return baseCapacity
end

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
    
    local modData = item:getModData()
    local baseCapacity = getBaseCapacity(item, modData)

    -- Only apply if we have a valid base capacity
    if baseCapacity > 0 then
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

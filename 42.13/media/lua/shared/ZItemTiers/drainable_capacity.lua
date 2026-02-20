-- Drainable capacity bonus module
-- Applies tier-based capacity bonuses to Drainable items (liquid containers)

require "ZItemTiers/core"

-- Apply drainable capacity bonus to a Drainable item
-- bonusPercent: The capacity bonus percentage (e.g., 10 for +10%)
-- modData: The item's modData table (required for storing base capacity)
function ZItemTiers.ApplyDrainableCapacityBonus(item, bonusPercent, modData)
    if not item or not bonusPercent or not modData then
        return
    end
    
    local isDrainable = false
    local successDrainable, resultDrainable = pcall(function()
        if item.getFluidContainer then
            local fluidContainer = item:getFluidContainer()
            return fluidContainer ~= nil
        end
        return false
    end)
    if successDrainable and resultDrainable then
        isDrainable = true
    end
    
    if not isDrainable then
        return
    end
    
    -- Check if bonus has already been applied (prevent multiple applications)
    local currentCapacity = 0
    local successGetCurrent, currentValue = pcall(function()
        if item.getFluidContainer then
            local fluidContainer = item:getFluidContainer()
            if fluidContainer and fluidContainer.getCapacity then
                return fluidContainer:getCapacity()
            end
        end
        return 0
    end)
    if successGetCurrent and currentValue then
        currentCapacity = currentValue
    end
    
    -- Get base capacity - use stored value if available, otherwise get from script item
    local baseCapacity = 0
    -- Check if stored base capacity is valid (must match current session ID)
    local storedBaseIsValid = false
    if modData.itemDrainableCapacityBase and modData.itemDrainableCapacityBase > 0 then
        -- Only use stored base if it was set in the current session
        if modData._bonusesApplied == ZItemTiers._bonusesAppliedSessionId then
            storedBaseIsValid = true
            baseCapacity = modData.itemDrainableCapacityBase
        else
            -- Stored base is from a different session, invalidate it
            modData.itemDrainableCapacityBase = nil
        end
    end
    
    if not storedBaseIsValid then
        -- Try to get base capacity from script item template (before any modifications)
        local successGetScriptBase, scriptBaseValue = pcall(function()
            -- First, try to create a fresh instance to get base capacity
            -- This is the most reliable way to get the original capacity
            local successCreate, freshItem = pcall(function()
                local itemType = item:getFullType()
                if itemType then
                    return instanceItem(itemType)
                end
                return nil
            end)
            if successCreate and freshItem then
                local successGetFresh, freshCapacity = pcall(function()
                    if freshItem.getFluidContainer then
                        local freshFluidContainer = freshItem:getFluidContainer()
                        if freshFluidContainer and freshFluidContainer.getCapacity then
                            return freshFluidContainer:getCapacity()
                        end
                    end
                    return nil
                end)
                if successGetFresh and freshCapacity and freshCapacity > 0 then
                    return freshCapacity
                end
            end
            
            -- Fallback: try to get from script item
            if item.getScriptItem then
                local scriptItem = item:getScriptItem()
                if scriptItem then
                    -- For drainable items, try to get maxCapacity from script item
                    if scriptItem.getMaxCapacity then
                        local maxCap = scriptItem:getMaxCapacity()
                        if maxCap and maxCap > 0 then
                            return maxCap
                        end
                    end
                    -- Fallback: try maxCapacity property directly
                    if scriptItem.maxCapacity then
                        return scriptItem.maxCapacity
                    end
                end
            end
            return nil
        end)
        
        if successGetScriptBase and scriptBaseValue and scriptBaseValue > 0 then
            baseCapacity = scriptBaseValue
        elseif currentCapacity > 0 then
            -- No bonus stored yet, assume current is base (first time application)
            -- This should only happen on the very first application before any modifications
            baseCapacity = currentCapacity
        end
        
        -- Store the base capacity in modData for future use
        if baseCapacity > 0 then
            modData.itemDrainableCapacityBase = baseCapacity
        end
    end
    
    -- Only apply if we have a valid base capacity
    if baseCapacity > 0 then
        -- Calculate expected capacity: base * (1 + bonus percentage / 100)
        local capacityMultiplier = 1.0 + (bonusPercent / 100.0)
        local expectedCapacity = baseCapacity * capacityMultiplier
        
        -- Check if bonus has already been applied (within small tolerance for floating point)
        if math.abs(currentCapacity - expectedCapacity) >= 0.01 then
            local successSet = pcall(function()
                if item.getFluidContainer then
                    local fluidContainer = item:getFluidContainer()
                    if fluidContainer and fluidContainer.setCapacity then
                        fluidContainer:setCapacity(expectedCapacity)
                    end
                end
            end)
        end
    end
end

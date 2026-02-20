-- Weight reduction bonus module
-- Applies tier-based weight reduction to items (except HandWeapon)

require "ZItemTiers/core"

-- Apply weight reduction to an item
-- reductionPercent: The weight reduction percentage (e.g., 10 for 10%)
function ZItemTiers.ApplyWeightReduction(item, reductionPercent)
    if not item or not reductionPercent then
        return
    end
    
    -- Skip HandWeapon items (they use Java patches for weight)
    if instanceof(item, "HandWeapon") then
        return
    end
    
    -- Get the original weight from the script item (before setting customWeight)
    local success, originalWeight = pcall(function()
        -- Try to get the script item's base weight first
        if item.getScriptItem then
            local scriptItem = item:getScriptItem()
            if scriptItem and scriptItem.getActualWeight then
                return scriptItem:getActualWeight()
            end
        end
        -- Fallback: try to get current weight
        if item.getActualWeight then
            return item:getActualWeight()
        elseif item.getWeight then
            return item:getWeight()
        end
        return nil
    end)
    
    -- Skip items that weigh 0.01 or less
    if success and originalWeight and originalWeight <= 0.01 then
        return
    end
    
    if success and originalWeight and originalWeight > 0.01 then
        -- Calculate new weight: reduce by percentage
        local reductionMultiplier = 1.0 - (reductionPercent / 100.0)
        local newWeight = originalWeight * reductionMultiplier
        -- Ensure weight doesn't go below 0.01
        newWeight = math.max(newWeight, 0.01)
        
        local success2 = pcall(function()
            -- Set custom weight flag FIRST (before setting weight)
            if item.setCustomWeight then
                item:setCustomWeight(true)
            end
            -- Set the new actual weight
            if item.setActualWeight then
                item:setActualWeight(newWeight)
            end
            -- Also set weight (some items use this)
            if item.setWeight then
                item:setWeight(newWeight)
            end
            
            -- For Clothing items, also update weightWet to maintain the wet weight ratio
            if instanceof(item, "Clothing") then
                -- Update weightWet to maintain the 1.25x ratio for wet clothing
                local newWeightWet = newWeight * 1.25
                if item.setWeightWet then
                    item:setWeightWet(newWeightWet)
                end
            end
            
            -- Sync the item to ensure weight change is persisted
            if item.SynchSpawn then
                item:SynchSpawn()
            end
        end)
    end
end

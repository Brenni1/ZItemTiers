-- Defense bonuses module
-- Applies tier-based bite and scratch defense bonuses to Clothing items

require "ZItemTiers/core"

-- Apply bite defense bonus to a Clothing item
-- bonusValue: The bite defense bonus (e.g., 5 for +5)
function ZItemTiers.ApplyBiteDefenseBonus(item, bonusValue)
    if not item or not bonusValue then
        return
    end
    
    if not instanceof(item, "Clothing") then
        return
    end
    
    -- Get base bite defense from script item
    local baseBiteDefense = 0
    local successGetBase, baseValue = pcall(function()
        if item.getScriptItem then
            local scriptItem = item:getScriptItem()
            if scriptItem and scriptItem.biteDefense then
                return scriptItem.biteDefense
            end
        end
        return 0
    end)
    if successGetBase and baseValue then
        baseBiteDefense = baseValue
    end
    
    -- Only apply if item already has bite defense (base > 0)
    if baseBiteDefense > 0 then
        local successGet, currentBiteDefense = pcall(function()
            if item.getBiteDefense then
                return item:getBiteDefense()
            end
            return baseBiteDefense
        end)
        
        if successGet then
            -- Calculate new value: base + bonus (additive)
            local newBiteDefense = baseBiteDefense + bonusValue
            -- Cap at 100 (max defense)
            newBiteDefense = math.min(newBiteDefense, 100)
            
            local successSet = pcall(function()
                if item.setBiteDefense then
                    item:setBiteDefense(newBiteDefense)
                end
            end)
        end
    end
end

-- Apply scratch defense bonus to a Clothing item
-- bonusValue: The scratch defense bonus (e.g., 5 for +5)
function ZItemTiers.ApplyScratchDefenseBonus(item, bonusValue)
    if not item or not bonusValue then
        return
    end
    
    if not instanceof(item, "Clothing") then
        return
    end
    
    -- Get base scratch defense from script item
    local baseScratchDefense = 0
    local successGetBase, baseValue = pcall(function()
        if item.getScriptItem then
            local scriptItem = item:getScriptItem()
            if scriptItem and scriptItem.scratchDefense then
                return scriptItem.scratchDefense
            end
        end
        return 0
    end)
    if successGetBase and baseValue then
        baseScratchDefense = baseValue
    end
    
    -- Only apply if item already has scratch defense (base > 0)
    if baseScratchDefense > 0 then
        local successGet, currentScratchDefense = pcall(function()
            if item.getScratchDefense then
                return item:getScratchDefense()
            end
            return baseScratchDefense
        end)
        
        if successGet then
            -- Calculate new value: base + bonus (additive)
            local newScratchDefense = baseScratchDefense + bonusValue
            -- Cap at 100 (max defense)
            newScratchDefense = math.min(newScratchDefense, 100)
            
            local successSet = pcall(function()
                if item.setScratchDefense then
                    item:setScratchDefense(newScratchDefense)
                end
            end)
        end
    end
end

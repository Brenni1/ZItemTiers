-- Mood bonus module for Literature items
-- Applies rarity-based mood bonuses (boredom/unhappiness/stress reduction)

require "ZItemTiers/core"

-- Apply mood bonus to a Literature item
-- bonusValue: The mood bonus multiplier (e.g., 0.1 for +10%)
function ZItemTiers.ApplyMoodBonus(item, bonusValue)
    if not item or not bonusValue then
        return
    end
    
    -- Check if item is Literature
    if not instanceof(item, "Literature") then
        return
    end
    
    -- Get base mood values from script item
    local baseBoredomChange = 0.0
    local baseUnhappyChange = 0.0
    local baseStressChange = 0.0
    
    local successGetBase, scriptItem = pcall(function()
        if item.getScriptItem then
            return item:getScriptItem()
        end
        return nil
    end)
    
    if successGetBase and scriptItem then
        -- Try to get from script item properties
        if scriptItem.boredomChange then
            baseBoredomChange = scriptItem.boredomChange
        end
        if scriptItem.unhappyChange then
            baseUnhappyChange = scriptItem.unhappyChange
        end
        if scriptItem.stressChange then
            baseStressChange = scriptItem.stressChange
        end
    end
    
    -- Also try instance methods as fallback
    local successGetBoredom, currentBoredom = pcall(function()
        if item.getBoredomChange then
            return item:getBoredomChange()
        end
        return baseBoredomChange
    end)
    if successGetBoredom and currentBoredom ~= 0.0 then
        baseBoredomChange = currentBoredom
    end
    
    local successGetUnhappy, currentUnhappy = pcall(function()
        if item.getUnhappyChange then
            return item:getUnhappyChange()
        end
        return baseUnhappyChange
    end)
    if successGetUnhappy and currentUnhappy ~= 0.0 then
        baseUnhappyChange = currentUnhappy
    end
    
    local successGetStress, currentStress = pcall(function()
        if item.getStressChange then
            return item:getStressChange()
        end
        return baseStressChange
    end)
    if successGetStress and currentStress ~= 0.0 then
        baseStressChange = currentStress
    end
    
    -- Apply mood bonus multiplier (1 + bonus) to negative values (mood reduction)
    -- Negative values are good (reduce boredom/unhappiness/stress), so we make them more negative
    local moodMultiplier = 1.0 + bonusValue
    
    if baseBoredomChange < 0.0 then
        local newBoredomChange = baseBoredomChange * moodMultiplier
        local successSet = pcall(function()
            if item.setBoredomChange then
                item:setBoredomChange(newBoredomChange)
            end
        end)
        if successSet then
            print("ZItemTiers: Applied mood bonus to boredom: " .. tostring(item:getFullType()) .. " (base: " .. baseBoredomChange .. ", new: " .. newBoredomChange .. ")")
        end
    end
    
    if baseUnhappyChange < 0.0 then
        local newUnhappyChange = baseUnhappyChange * moodMultiplier
        local successSet = pcall(function()
            if item.setUnhappyChange then
                item:setUnhappyChange(newUnhappyChange)
            end
        end)
        if successSet then
            print("ZItemTiers: Applied mood bonus to unhappiness: " .. tostring(item:getFullType()) .. " (base: " .. baseUnhappyChange .. ", new: " .. newUnhappyChange .. ")")
        end
    end
    
    if baseStressChange < 0.0 then
        local newStressChange = baseStressChange * moodMultiplier
        local successSet = pcall(function()
            if item.setStressChange then
                item:setStressChange(newStressChange)
            end
        end)
        if successSet then
            print("ZItemTiers: Applied mood bonus to stress: " .. tostring(item:getFullType()) .. " (base: " .. baseStressChange .. ", new: " .. newStressChange .. ")")
        end
    end
end

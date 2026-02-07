-- Bonus display logic for tooltips
-- Extracted from core.lua to keep it DRY and maintainable

ZItemTiers = ZItemTiers or {}

-- Get bonuses for an item (for display in tooltips)
function ZItemTiers.GetItemBonuses(item)
    if not item then return {} end
    
    local rarity = ZItemTiers.GetItemRarity(item)
    local bonuses = ZItemTiers.RarityBonuses[rarity]
    if not bonuses then return {} end
    
    -- Convert to list format for display
    local bonusList = {}
    
    -- Add each bonus type to the list
    ZItemTiers.AddWeightBonuses(bonusList, item, bonuses)
    ZItemTiers.AddDamageBonus(bonusList, item, bonuses)
    ZItemTiers.AddRunSpeedBonus(bonusList, item, bonuses)
    ZItemTiers.AddDefenseBonuses(bonusList, item, bonuses)
    ZItemTiers.AddContainerBonuses(bonusList, item, bonuses)
    ZItemTiers.AddDrainableBonus(bonusList, item, bonuses)
    ZItemTiers.AddVisionImpairmentBonus(bonusList, item, bonuses)
    ZItemTiers.AddHearingImpairmentBonus(bonusList, item, bonuses)
    ZItemTiers.AddMoodBonus(bonusList, item, bonuses)
    ZItemTiers.AddReadingSpeedBonus(bonusList, item, bonuses)
    ZItemTiers.AddVhsSkillXpBonus(bonusList, item, bonuses)
    
    return bonusList
end

-- Add weight-related bonuses (weight reduction and encumbrance reduction)
function ZItemTiers.AddWeightBonuses(bonusList, item, bonuses)
    -- Check if this is a container to show encumbrance reduction
    local isContainer = false
    local successContainer, resultContainer = pcall(function()
        return instanceof(item, "InventoryContainer")
    end)
    if successContainer and resultContainer then
        isContainer = true
    end
    
    -- Containers show both encumbrance reduction and weight reduction
    if bonuses.encumbranceReduction and isContainer then
        table.insert(bonusList, {
            type = "EncumbranceReduction",
            value = bonuses.encumbranceReduction,
            displayName = "Encumbrance Reduction"
        })
    end
    -- All items (including containers) show weight reduction
    if bonuses.weightReduction then
        table.insert(bonusList, {
            type = "WeightReduction",
            value = bonuses.weightReduction,
            displayName = "Weight Reduction"
        })
    end
end

-- Add damage bonus for HandWeapon items
function ZItemTiers.AddDamageBonus(bonusList, item, bonuses)
    local isHandWeapon = false
    local successWeapon, resultWeapon = pcall(function()
        return instanceof(item, "HandWeapon")
    end)
    if successWeapon and resultWeapon then
        isHandWeapon = true
    end
    
    if bonuses.damageMultiplier and isHandWeapon then
        local damagePercent = math.floor((bonuses.damageMultiplier - 1.0) * 100)
        table.insert(bonusList, {
            type = "DamageMultiplier",
            value = damagePercent,
            displayName = "Damage"
        })
    end
end

-- Add run speed bonus for Clothing items
function ZItemTiers.AddRunSpeedBonus(bonusList, item, bonuses)
    local isClothingWithRunSpeed = false
    local successClothing, resultClothing = pcall(function()
        return instanceof(item, "Clothing")
    end)
    if successClothing and resultClothing then
        -- Check if item has a non-default run speed modifier
        local successGetBase, baseValue = pcall(function()
            if item.getScriptItem then
                local scriptItem = item:getScriptItem()
                if scriptItem and scriptItem.runSpeedModifier then
                    return scriptItem.runSpeedModifier
                end
            end
            return 1.0
        end)
        if successGetBase and baseValue and math.abs(baseValue - 1.0) > 0.001 then
            isClothingWithRunSpeed = true
        end
    end
    
    if bonuses.runSpeedModifier and isClothingWithRunSpeed then
        local runSpeedValue = string.format("%.1f", bonuses.runSpeedModifier)
        table.insert(bonusList, {
            type = "RunSpeedModifier",
            value = runSpeedValue,
            displayName = "Run Speed"
        })
    end
end

-- Add defense bonuses (bite and scratch) for Clothing items
function ZItemTiers.AddDefenseBonuses(bonusList, item, bonuses)
    local isClothingWithDefense = false
    local successClothing, resultClothing = pcall(function()
        return instanceof(item, "Clothing")
    end)
    if successClothing and resultClothing then
        -- Check if item has bite or scratch defense
        local successGetBite, baseBiteDefense = pcall(function()
            if item.getScriptItem then
                local scriptItem = item:getScriptItem()
                if scriptItem and scriptItem.biteDefense then
                    return scriptItem.biteDefense
                end
            end
            return 0
        end)
        local successGetScratch, baseScratchDefense = pcall(function()
            if item.getScriptItem then
                local scriptItem = item:getScriptItem()
                if scriptItem and scriptItem.scratchDefense then
                    return scriptItem.scratchDefense
                end
            end
            return 0
        end)
        if (successGetBite and baseBiteDefense and baseBiteDefense > 0) or
           (successGetScratch and baseScratchDefense and baseScratchDefense > 0) then
            isClothingWithDefense = true
        end
    end
    
    if bonuses.biteDefenseBonus and isClothingWithDefense then
        -- Only show if item has bite defense
        local successGetBite, baseBiteDefense = pcall(function()
            if item.getScriptItem then
                local scriptItem = item:getScriptItem()
                if scriptItem and scriptItem.biteDefense then
                    return scriptItem.biteDefense
                end
            end
            return 0
        end)
        if successGetBite and baseBiteDefense and baseBiteDefense > 0 then
            table.insert(bonusList, {
                type = "BiteDefenseBonus",
                value = bonuses.biteDefenseBonus,
                displayName = "Bite Defense"
            })
        end
    end
    
    if bonuses.scratchDefenseBonus and isClothingWithDefense then
        -- Only show if item has scratch defense
        local successGetScratch, baseScratchDefense = pcall(function()
            if item.getScriptItem then
                local scriptItem = item:getScriptItem()
                if scriptItem and scriptItem.scratchDefense then
                    return scriptItem.scratchDefense
                end
            end
            return 0
        end)
        if successGetScratch and baseScratchDefense and baseScratchDefense > 0 then
            table.insert(bonusList, {
                type = "ScratchDefenseBonus",
                value = bonuses.scratchDefenseBonus,
                displayName = "Scratch Defense"
            })
        end
    end
end

-- Add container bonuses (capacity and max encumbrance)
function ZItemTiers.AddContainerBonuses(bonusList, item, bonuses)
    local isContainer = false
    local successContainer, resultContainer = pcall(function()
        return instanceof(item, "InventoryContainer")
    end)
    if successContainer and resultContainer then
        isContainer = true
    end
    
    if bonuses.capacityBonus and isContainer then
        table.insert(bonusList, {
            type = "CapacityBonus",
            value = bonuses.capacityBonus,
            displayName = "Capacity"
        })
    end

    if bonuses.maxEncumbranceBonus and isContainer then
        -- Only show if container has a max item size
        local successGet, maxItemSize = pcall(function()
            if item.getMaxItemSize then
                return item:getMaxItemSize()
            end
            return 0
        end)
        if successGet and maxItemSize and maxItemSize > 0 then
            table.insert(bonusList, {
                type = "MaxEncumbranceBonus",
                value = bonuses.maxEncumbranceBonus,
                displayName = "Max Item Encumbrance"
            })
        end
    end
end

-- Add drainable capacity bonus
function ZItemTiers.AddDrainableBonus(bonusList, item, bonuses)
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
    
    if bonuses.drainableCapacityBonus and isDrainable then
        table.insert(bonusList, {
            type = "DrainableCapacityBonus",
            value = bonuses.drainableCapacityBonus,
            displayName = "Liquid Capacity"
        })
    end
end

-- Add vision impairment reduction bonus
function ZItemTiers.AddVisionImpairmentBonus(bonusList, item, bonuses)
    local isClothingWithVisionImpair = false
    local successClothing, resultClothing = pcall(function()
        return instanceof(item, "Clothing")
    end)
    if successClothing and resultClothing then
        -- Check if item has vision impairment (vision modifier < 1.0)
        local successGetBase, baseValue = pcall(function()
            if item.getScriptItem then
                local scriptItem = item:getScriptItem()
                if scriptItem then
                    if scriptItem.getVisionModifier then
                        return scriptItem:getVisionModifier()
                    end
                    if scriptItem.visionModifier then
                        return scriptItem.visionModifier
                    end
                end
            end
            -- Also try instance method
            if item.getVisionModifier then
                return item:getVisionModifier()
            end
            return 1.0
        end)
        if successGetBase and baseValue and baseValue < 1.0 then
            isClothingWithVisionImpair = true
        end
    end
    
    if bonuses.visionImpairmentReduction and isClothingWithVisionImpair then
        local visionImpairValue = string.format("%.2f", bonuses.visionImpairmentReduction)
        table.insert(bonusList, {
            type = "VisionImpairmentReduction",
            value = visionImpairValue,
            displayName = "Vision Impairment Reduction"
        })
    end
end

-- Add hearing impairment reduction bonus
function ZItemTiers.AddHearingImpairmentBonus(bonusList, item, bonuses)
    local isClothingWithHearingImpair = false
    local successClothing, resultClothing = pcall(function()
        return instanceof(item, "Clothing")
    end)
    if successClothing and resultClothing then
        -- Check if item has hearing impairment (hearing modifier < 1.0)
        local successGetBase, baseValue = pcall(function()
            if item.getScriptItem then
                local scriptItem = item:getScriptItem()
                if scriptItem then
                    if scriptItem.getHearingModifier then
                        return scriptItem:getHearingModifier()
                    end
                    if scriptItem.hearingModifier then
                        return scriptItem.hearingModifier
                    end
                end
            end
            -- Also try instance method
            if item.getHearingModifier then
                return item:getHearingModifier()
            end
            return 1.0
        end)
        if successGetBase and baseValue and baseValue < 1.0 then
            isClothingWithHearingImpair = true
        end
    end
    
    if bonuses.hearingImpairmentReduction and isClothingWithHearingImpair then
        local hearingImpairValue = string.format("%.2f", bonuses.hearingImpairmentReduction)
        table.insert(bonusList, {
            type = "HearingImpairmentReduction",
            value = hearingImpairValue,
            displayName = "Hearing Impairment Reduction"
        })
    end
end

-- Add mood bonus for Literature items
function ZItemTiers.AddMoodBonus(bonusList, item, bonuses)
    local isLiterature = false
    local successLiterature, resultLiterature = pcall(function()
        return instanceof(item, "Literature")
    end)
    if successLiterature and resultLiterature then
        isLiterature = true
    end
    
    if bonuses.moodBonus and isLiterature then
        -- Check if item has any mood effects (boredom/unhappiness/stress reduction)
        local hasMoodEffects = false
        local successGetBoredom, boredomChange = pcall(function()
            if item.getBoredomChange then
                return item:getBoredomChange()
            end
            return 0.0
        end)
        local successGetUnhappy, unhappyChange = pcall(function()
            if item.getUnhappyChange then
                return item:getUnhappyChange()
            end
            return 0.0
        end)
        local successGetStress, stressChange = pcall(function()
            if item.getStressChange then
                return item:getStressChange()
            end
            return 0.0
        end)
        
        if (successGetBoredom and boredomChange < 0.0) or
           (successGetUnhappy and unhappyChange < 0.0) or
           (successGetStress and stressChange < 0.0) then
            hasMoodEffects = true
        end
        
        if hasMoodEffects then
            local moodPercent = string.format("%.0f", bonuses.moodBonus * 100)
            table.insert(bonusList, {
                type = "MoodBonus",
                value = moodPercent,
                displayName = "Mood Benefits"
            })
        end
    end
end

-- Add reading speed bonus for Literature items (not VHS)
function ZItemTiers.AddReadingSpeedBonus(bonusList, item, bonuses)
    local isLiterature = false
    local successLiterature, resultLiterature = pcall(function()
        return instanceof(item, "Literature")
    end)
    if successLiterature and resultLiterature then
        isLiterature = true
    end
    
    if bonuses.readingSpeedBonus and isLiterature then
        -- Check if it's a VHS tape (exclude VHS from reading speed bonus)
        local isVHS = false
        local itemType = item:getType()
        if itemType then
            -- VHS tapes have "VHS" in their type
            if string.find(itemType, "VHS") then
                isVHS = true
            end
        end
        
        -- Only show reading speed bonus for books, not VHS tapes
        if not isVHS then
            local readingSpeedPercent = string.format("%.0f", bonuses.readingSpeedBonus * 100)
            table.insert(bonusList, {
                type = "ReadingSpeedBonus",
                value = readingSpeedPercent,
                displayName = "Reading Speed"
            })
        end
    end
end

-- Add VHS skill XP bonus
function ZItemTiers.AddVhsSkillXpBonus(bonusList, item, bonuses)
    if bonuses.vhsSkillXpBonus then
        -- Check if it's a VHS tape by type name (VHS items are ComboItem, not Literature)
        local isVHS = false
        local itemType = item:getType()
        if itemType then
            -- VHS tapes have "VHS" in their type
            if string.find(itemType, "VHS") then
                isVHS = true
            end
        end
        
        -- Only show VHS skill XP bonus for VHS tapes that teach skills
        if isVHS then
            -- Check if the VHS teaches any skills by examining its original MediaData
            -- (not the tiered one, since we need to check the base skill codes)
            local hasSkillCodes = false
            if ZItemTiers.GetOriginalVhsMediaData and ZItemTiers.MediaDataHasSkillCodes then
                local successGet, originalMediaData = pcall(function()
                    return ZItemTiers.GetOriginalVhsMediaData(item)
                end)
                if successGet and originalMediaData then
                    local successCheck, hasCodes = pcall(function()
                        return ZItemTiers.MediaDataHasSkillCodes(originalMediaData)
                    end)
                    if successCheck then
                        hasSkillCodes = hasCodes
                    end
                end
            end
            
            if hasSkillCodes then
                table.insert(bonusList, {
                    type = "VhsSkillXpBonus",
                    value = tostring(bonuses.vhsSkillXpBonus),
                    displayName = "Skill XP Bonus"
                })
            end
        end
    end
end

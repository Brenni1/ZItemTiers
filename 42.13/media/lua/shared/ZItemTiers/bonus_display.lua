ZItemTiers = ZItemTiers or {}

-- Get bonuses for an item - all bonuses
function ZItemTiers.GetItemBonuses(item)
    local zit = ZItemTiers.GetZIT(item)
    return zit and zit.bonuses or {}
end

-- Get bonuses for an item - skip hidden ones - for display in tooltips
function ZItemTiers.GetItemShownBonuses(item)
    local all_bonuses = ZItemTiers.GetItemBonuses(item) or {}
    local result = {}
    for k,v in pairs(all_bonuses) do
        if ZItemTiers.Bonuses[k] and not ZItemTiers.Bonuses[k].hide then
            result[k] = v
        end
    end
    return result
end

-- Add weight-related bonuses (weight reduction and encumbrance reduction)
function ZItemTiers.AddWeightBonuses(bonusList, item, bonuses)
    local isContainer = instanceof(item, "InventoryContainer")

    -- Containers: show total encumbrance reduction (base + tier bonus), not just the bonus
    if bonuses.encumbranceReduction and isContainer then
        local displayValue = bonuses.encumbranceReduction
        if item.getWeightReduction then
            local total = item:getWeightReduction()
            if total and total > 0 then
                displayValue = total
            end
        end
        table.insert(bonusList, {
            type = "EncumbranceReduction",
            value = displayValue,
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
    if bonuses.damageMultiplier and instanceof(item, "HandWeapon") then
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
    local isClothingWithRunSpeed = instanceof(item, "Clothing") and (function()
        local modData = item:getModData()
        local baseValue = ZItemTiers.GetBaseRunSpeedModifier(item, modData)
        return math.abs(baseValue - 1.0) > 0.001
    end)()
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
    local scriptItem = item.getScriptItem and item:getScriptItem() or nil
    local baseBiteDefense = (scriptItem and scriptItem.biteDefense) or 0
    local baseScratchDefense = (scriptItem and scriptItem.scratchDefense) or 0
    local isClothingWithDefense = instanceof(item, "Clothing") and (baseBiteDefense > 0 or baseScratchDefense > 0)

    if bonuses.biteDefenseBonus and isClothingWithDefense and baseBiteDefense > 0 then
        table.insert(bonusList, {
            type = "BiteDefenseBonus",
            value = bonuses.biteDefenseBonus,
            displayName = "Bite Defense"
        })
    end

    if bonuses.scratchDefenseBonus and isClothingWithDefense and baseScratchDefense > 0 then
        table.insert(bonusList, {
            type = "ScratchDefenseBonus",
            value = bonuses.scratchDefenseBonus,
            displayName = "Scratch Defense"
        })
    end
end

-- Add container bonuses (capacity and max encumbrance)
function ZItemTiers.AddContainerBonuses(bonusList, item, bonuses)
    local isContainer = instanceof(item, "InventoryContainer")
    if bonuses.capacityBonus and isContainer then
        table.insert(bonusList, {
            type = "CapacityBonus",
            value = bonuses.capacityBonus,
            displayName = "Capacity"
        })
    end

    if bonuses.maxEncumbranceBonus and isContainer then
        local maxItemSize = (item.getMaxItemSize and item:getMaxItemSize()) or 0
        if maxItemSize > 0 then
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
    local isDrainable = item.getFluidContainer and item:getFluidContainer() ~= nil
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
    local baseValue = 1.0
    if instanceof(item, "Clothing") then
        local scriptItem = item.getScriptItem and item:getScriptItem() or nil
        if scriptItem then
            if scriptItem.getVisionModifier then
                baseValue = scriptItem:getVisionModifier()
            elseif scriptItem.visionModifier then
                baseValue = scriptItem.visionModifier
            end
        end
        if baseValue >= 1.0 and item.getVisionModifier then
            baseValue = item:getVisionModifier()
        end
    end
    local isClothingWithVisionImpair = instanceof(item, "Clothing") and baseValue < 1.0
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
    local baseValue = 1.0
    if instanceof(item, "Clothing") then
        local scriptItem = item.getScriptItem and item:getScriptItem() or nil
        if scriptItem then
            if scriptItem.getHearingModifier then
                baseValue = scriptItem:getHearingModifier()
            elseif scriptItem.hearingModifier then
                baseValue = scriptItem.hearingModifier
            end
        end
        if baseValue >= 1.0 and item.getHearingModifier then
            baseValue = item:getHearingModifier()
        end
    end
    local isClothingWithHearingImpair = instanceof(item, "Clothing") and baseValue < 1.0
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
    if bonuses.moodBonus and instanceof(item, "Literature") then
        local boredomChange = (item.getBoredomChange and item:getBoredomChange()) or 0.0
        local unhappyChange = (item.getUnhappyChange and item:getUnhappyChange()) or 0.0
        local stressChange = (item.getStressChange and item:getStressChange()) or 0.0
        local hasMoodEffects = boredomChange < 0.0 or unhappyChange < 0.0 or stressChange < 0.0
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
    if bonuses.readingSpeedBonus and instanceof(item, "Literature") then
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
            local hasSkillCodes = false
            if ZItemTiers.GetOriginalVhsMediaData and ZItemTiers.MediaDataHasSkillCodes then
                local originalMediaData = ZItemTiers.GetOriginalVhsMediaData(item)
                if originalMediaData then
                    hasSkillCodes = ZItemTiers.MediaDataHasSkillCodes(originalMediaData)
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

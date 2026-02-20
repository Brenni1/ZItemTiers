-- Item Tier Mod
-- Adds tier-based bonus system to items
-- Each item can spawn with any tier based on probability, not hardcoded item-to-tier mapping

ZItemTiers = ZItemTiers or {}

-- Initialize global session ID for bonus tracking (initialized once per game session)
if not ZItemTiers._bonusesAppliedSessionId then
    ZItemTiers._bonusesAppliedSessionId = ZombRand(1000000)
end

-- Blacklist of items that should never have tier assigned
-- Items in this list will never receive tier bonuses
ZItemTiers.BlacklistedItems = {
    ["Base.IDcard"] = true,
    -- Keys (a key either works or it doesn't - no benefit from tier)
    ["Base.Key1"] = true,
    ["Base.Key_Blank"] = true,
    ["Base.CombinationPadlock"] = true,
    ["Base.KeyPadlock"] = true,
    ["Base.Padlock"] = true,
    ["Base.CarKey"] = true,
    ["Base.Brochure"] = true,
    ["Base.Flier"] = true,
    -- Maps (maps are informational items, no benefit from tier)
    ["Base.Map"] = true,
    ["Base.GolfTee"] = true,
    -- VHS tapes (blacklisted by pattern in IsItemBlacklisted; bonus commented out for now)
}

-- Tier probabilities: [Common, Uncommon, Rare, Epic, Legendary]
-- These determine the chance that an item will be assigned each tier when it spawns
-- Values should sum to 1.0 (100%)
-- Epic and Legendary are intentionally very rare
ZItemTiers.TierProbabilities = {0.80, 0.16, 0.032, 0.0064, 0.0016}

-- Global constants for convenience
ZItemTiers.CommonIdx = 1

-- Tier metadata: name, color, and index
ZItemTiers.Tiers = {
    Common = {
        index = ZItemTiers.CommonIdx,
        name = "Common",
        color = {r=1.0, g=1.0, b=1.0},  -- White
    },
    Uncommon = {
        index = ZItemTiers.CommonIdx + 1,
        name = "Uncommon",
        color = {r=0.2, g=1.0, b=0.2},  -- Green
    },
    Rare = {
        index = ZItemTiers.CommonIdx + 2,
        name = "Rare",
        color = {r=0.2, g=0.4, b=1.0},  -- Blue
    },
    Epic = {
        index = ZItemTiers.CommonIdx + 3,
        name = "Epic",
        color = {r=0.8, g=0.2, b=1.0},  -- Purple
    },
    Legendary = {
        index = ZItemTiers.CommonIdx + 4,
        name = "Legendary",
        color = {r=1.0, g=0.8, b=0.0},  -- Gold/Yellow
    },
}

-- Fixed tier-based bonuses
-- These bonuses are applied to ALL items of that tier, regardless of item type
-- For HandWeapon items: damage is applied directly from Lua, weight requires Java patches
-- For other items: weight reduction is applied directly
-- For shoes (Clothing with SHOES body location): run speed modifier is applied
ZItemTiers.TierBonuses = {
    Common = {
        -- No bonuses for Common items
    },
    Uncommon = {
        weightReduction = 10,  -- 10% weight reduction (for item's own weight)
        encumbranceReduction = 2,  -- +2 encumbrance reduction (for InventoryContainer, reduces weight of items inside)
        damageMultiplier = 1.1,  -- 10% more damage (for HandWeapon)
        runSpeedModifier = 0.1,  -- +0.1 run speed (for clothing with run speed modifier)
        biteDefenseBonus = 5,  -- +5 bite defense (for Clothing)
        scratchDefenseBonus = 5,  -- +5 scratch defense (for Clothing)
        capacityBonus = 10,  -- +10% capacity (for InventoryContainer)
        maxEncumbranceBonus = 0.1,  -- +0.1 maximum item encumbrance (for InventoryContainer)
        drainableCapacityBonus = 10,  -- +10% capacity (for Drainable items)
        visionImpairmentReduction = 0.05,  -- -0.05 vision impairment (for Clothing with vision impairment)
        hearingImpairmentReduction = 0.05,  -- -0.05 hearing impairment (for Clothing with hearing impairment)
        moodBonus = 0.1,  -- +10% mood benefits (boredom/unhappiness/stress reduction) for Literature items
        readingSpeedBonus = 0.1,  -- +10% reading speed (reduces reading time) for Literature items
        -- vhsSkillXpBonus = 50,  -- +50 skill XP (total per cassette) for VHS tapes (commented out; VHS blacklisted for now)
        batteryConsumptionReduction = 0.1,  -- 10% less battery consumption (for ElectricLight/Torch flashlights)
    },
    Rare = {
        weightReduction = 20,  -- 20% weight reduction (for item's own weight)
        encumbranceReduction = 4,  -- +4 encumbrance reduction (for InventoryContainer, reduces weight of items inside)
        damageMultiplier = 1.2,  -- 20% more damage (for HandWeapon)
        runSpeedModifier = 0.2,  -- +0.2 run speed (for clothing with run speed modifier)
        biteDefenseBonus = 10,  -- +10 bite defense (for Clothing)
        scratchDefenseBonus = 10,  -- +10 scratch defense (for Clothing)
        capacityBonus = 20,  -- +20% capacity (for InventoryContainer)
        maxEncumbranceBonus = 0.2,  -- +0.2 maximum item encumbrance (for InventoryContainer)
        drainableCapacityBonus = 20,  -- +20% capacity (for Drainable items)
        visionImpairmentReduction = 0.10,  -- -0.10 vision impairment (for Clothing with vision impairment)
        hearingImpairmentReduction = 0.10,  -- -0.10 hearing impairment (for Clothing with hearing impairment)
        moodBonus = 0.2,  -- +20% mood benefits (boredom/unhappiness/stress reduction) for Literature items
        readingSpeedBonus = 0.2,  -- +20% reading speed (reduces reading time) for Literature items
        -- vhsSkillXpBonus = 100,  -- +100 skill XP (total per cassette) for VHS tapes (commented out; VHS blacklisted for now)
        batteryConsumptionReduction = 0.2,  -- 20% less battery consumption (for ElectricLight/Torch flashlights)
    },
    Epic = {
        weightReduction = 30,  -- 30% weight reduction (for item's own weight)
        encumbranceReduction = 6,  -- +6 encumbrance reduction (for InventoryContainer, reduces weight of items inside)
        damageMultiplier = 1.4,  -- 40% more damage (for HandWeapon)
        runSpeedModifier = 0.3,  -- +0.3 run speed (for clothing with run speed modifier)
        biteDefenseBonus = 15,  -- +15 bite defense (for Clothing)
        scratchDefenseBonus = 15,  -- +15 scratch defense (for Clothing)
        capacityBonus = 30,  -- +30% capacity (for InventoryContainer)
        maxEncumbranceBonus = 0.3,  -- +0.3 maximum item encumbrance (for InventoryContainer)
        drainableCapacityBonus = 30,  -- +30% capacity (for Drainable items)
        visionImpairmentReduction = 0.15,  -- -0.15 vision impairment (for Clothing with vision impairment)
        hearingImpairmentReduction = 0.15,  -- -0.15 hearing impairment (for Clothing with hearing impairment)
        moodBonus = 0.3,  -- +30% mood benefits (boredom/unhappiness/stress reduction) for Literature items
        readingSpeedBonus = 0.3,  -- +30% reading speed (reduces reading time) for Literature items
        -- vhsSkillXpBonus = 150,  -- +150 skill XP (total per cassette) for VHS tapes (commented out; VHS blacklisted for now)
        batteryConsumptionReduction = 0.3,  -- 30% less battery consumption (for ElectricLight/Torch flashlights)
    },
    Legendary = {
        weightReduction = 50,  -- 50% weight reduction (for item's own weight)
        encumbranceReduction = 8,  -- +8 encumbrance reduction (for InventoryContainer, reduces weight of items inside)
        damageMultiplier = 1.6,  -- 60% more damage (for HandWeapon)
        runSpeedModifier = 0.4,  -- +0.4 run speed (for clothing with run speed modifier)
        biteDefenseBonus = 20,  -- +20 bite defense (for Clothing)
        scratchDefenseBonus = 20,  -- +20 scratch defense (for Clothing)
        capacityBonus = 50, -- +50% capacity (for InventoryContainer)
        maxEncumbranceBonus = 0.5, -- +0.5 maximum item encumbrance (for InventoryContainer)
        drainableCapacityBonus = 50,  -- +50% capacity (for Drainable items)
        visionImpairmentReduction = 0.25,  -- -0.25 vision impairment (for Clothing with vision impairment)
        hearingImpairmentReduction = 0.25,  -- -0.25 hearing impairment (for Clothing with hearing impairment)
        batteryConsumptionReduction = 0.5,  -- 50% less battery consumption (for ElectricLight/Torch flashlights)
        moodBonus = 0.5,  -- +50% mood benefits (boredom/unhappiness/stress reduction) for Literature items
        readingSpeedBonus = 0.5,  -- +50% reading speed (reduces reading time) for Literature items
        -- vhsSkillXpBonus = 250,  -- +250 skill XP (total per cassette) for VHS tapes (commented out; VHS blacklisted for now)
    },
}

-- Roll a random tier based on tier probabilities
function ZItemTiers.RollTier()
    local roll = ZombRand(10000) / 10000.0  -- Random 0.0 to 1.0
    local cumulative = 0
    
    for i = 1, #ZItemTiers.TierProbabilities do
        cumulative = cumulative + ZItemTiers.TierProbabilities[i]
        if roll <= cumulative then
            -- Find tier name by index
            for tierName, tierData in pairs(ZItemTiers.Tiers) do
                if tierData.index == i then
                    return tierName
                end
            end
        end
    end
    
    -- Fallback to Common if something goes wrong
    return "Common"
end

-- Check if an item is blacklisted and should never receive tier
-- Returns true if the item should be excluded from tier assignment
function ZItemTiers.IsItemBlacklisted(item)
    if not item then return true end
    
    -- Check if item is in the blacklist by full type name
    local successType, fullType = pcall(function()
        return item:getFullType()
    end)
    if successType and fullType and ZItemTiers.BlacklistedItems[fullType] then
        return true
    end
    -- VHS tapes: blacklist by pattern (any fullType containing "VHS")
    if successType and fullType and string.find(fullType, "VHS") then
        return true
    end

    -- Check if item is a Map type (all maps should be blacklisted)
    local itemType = item:getType()
    if itemType then
        -- Check if it's ItemType.MAP
        local successCheck, isMap = pcall(function()
            if ItemType and ItemType.MAP then
                return itemType == ItemType.MAP
            end
            -- Fallback: check by string name
            if itemType and itemType.toString then
                return itemType:toString() == "Map"
            end
            return false
        end)
        if successCheck and isMap then
            return true
        end
    end
    
    return false
end

-- Get the base (unmodified) run speed modifier for a Clothing item
-- Tries: script item getter -> script item field -> stored modData -> instance method
-- Returns 1.0 (neutral) if item has no run speed modifier
function ZItemTiers.GetBaseRunSpeedModifier(item, modData)
    -- Trust stored base only if from current session (prevents using stale 1.0 from old buggy code)
    if modData and modData.itemRunSpeedModifierBase
        and modData._bonusesApplied == ZItemTiers._bonusesAppliedSessionId then
        return modData.itemRunSpeedModifierBase
    end

    local base = 1.0

    -- Primary: script item getter (authoritative, always returns the vanilla base)
    local success, value = pcall(function()
        if item.getScriptItem then
            local scriptItem = item:getScriptItem()
            if scriptItem then
                if scriptItem.getRunSpeedModifier then
                    return scriptItem:getRunSpeedModifier()
                end
                if scriptItem.runSpeedModifier then
                    return scriptItem.runSpeedModifier
                end
            end
        end
        return nil
    end)
    if success and value then
        base = value
    end

    -- Fallback: instance method (correct on first application before any modifications)
    if math.abs(base - 1.0) <= 0.001 then
        local successGet, instValue = pcall(function()
            if item.getRunSpeedModifier then
                return item:getRunSpeedModifier()
            end
            return 1.0
        end)
        if successGet and instValue then
            base = instValue
        end
    end

    -- Cache in modData for future calls
    if modData then
        modData.itemRunSpeedModifierBase = base
    end

    return base
end

-- Apply fixed tier-based bonuses to an item
function ZItemTiers.ApplyTierBonuses(item, tier)
    if not item then return end
    
    local itemType = item:getFullType()
    
    -- Check if this is a VHS item for logging
    local isVHS = false
    if itemType and string.find(itemType, "VHS") then
        isVHS = true
    end
    
    local tierData = ZItemTiers.Tiers[tier]
    if not tierData then 
        if isVHS then
            print("ZItemTiers: [VHS] ERROR: No tier data for " .. itemType .. " tier " .. tostring(tier))
        end
        return 
    end
    
    local bonuses = ZItemTiers.TierBonuses[tier]
    if not bonuses then 
        if isVHS then
            print("ZItemTiers: [VHS] ERROR: No bonuses for " .. itemType .. " tier " .. tostring(tier))
        end
        return 
    end
    
    -- Get modData first to check if bonuses have already been applied
    local modData = item:getModData()
    if not modData then 
        if isVHS then
            print("ZItemTiers: [VHS] ERROR: No modData for " .. itemType)
        end
        return 
    end
    
    -- Check if this exact tier and bonuses have already been applied in this game session
    -- Compare with global session ID to ensure bonuses were applied in the current session
    if modData.itemTier == tier and modData._bonusesApplied == ZItemTiers._bonusesAppliedSessionId then
        -- Bonuses already applied for this tier in this session, skip
        if isVHS then
            print("ZItemTiers: [VHS] Bonuses already applied for " .. itemType .. " (tier: " .. tostring(tier) .. ", session: " .. tostring(modData._bonusesApplied) .. ")")
        end
        return
    end
    
    -- If session ID doesn't match, reset base capacity values to force recalculation
    -- This prevents using incorrect base values from previous sessions
    -- Only reset for drainable items to avoid unnecessary messages
    if modData._bonusesApplied and modData._bonusesApplied ~= ZItemTiers._bonusesAppliedSessionId then
        -- Check if this is a drainable item before resetting
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
            modData.itemDrainableCapacityBase = nil
            print("ZItemTiers: Session ID changed, resetting base capacity for drainable item: " .. tostring(item:getFullType()))
        end
    end
    
    -- Store tier in modData
    modData.itemTier = tier
    
    -- Store the target weight reduction percentage so we can re-apply it if weight gets reset
    if bonuses.weightReduction then
        modData.itemWeightReduction = bonuses.weightReduction
    end
    -- Store encumbrance reduction bonus so we can re-apply it if it gets reset
    if bonuses.encumbranceReduction then
        modData.itemEncumbranceReduction = bonuses.encumbranceReduction
    end
    -- Store the run speed modifier bonus and base value so we can re-apply it if it gets reset
    if bonuses.runSpeedModifier then
        modData.itemRunSpeedModifierBonus = bonuses.runSpeedModifier
        -- Store base value using the shared helper (tries getter, field, instance)
        ZItemTiers.GetBaseRunSpeedModifier(item, modData)
    end
    -- Store capacity bonus so we can re-apply it if it gets reset
    if bonuses.capacityBonus then
        modData.itemCapacityBonus = bonuses.capacityBonus
    end
    -- Store max encumbrance bonus so we can re-apply it if it gets reset
    if bonuses.maxEncumbranceBonus then
        modData.itemMaxEncumbranceBonus = bonuses.maxEncumbranceBonus
    end
    -- Store defense bonuses so we can re-apply them if they get reset
    if bonuses.biteDefenseBonus then
        modData.itemBiteDefenseBonus = bonuses.biteDefenseBonus
    end
    if bonuses.scratchDefenseBonus then
        modData.itemScratchDefenseBonus = bonuses.scratchDefenseBonus
    end
    -- Store drainable capacity bonus so we can re-apply it if it gets reset
    if bonuses.drainableCapacityBonus then
        modData.itemDrainableCapacityBonus = bonuses.drainableCapacityBonus
    end
    
    -- Store vision impairment reduction so we can re-apply it if it gets reset
    if bonuses.visionImpairmentReduction then
        modData.itemVisionImpairmentReduction = bonuses.visionImpairmentReduction
    end
    -- Store hearing impairment reduction so we can re-apply it if it gets reset
    if bonuses.hearingImpairmentReduction then
        modData.itemHearingImpairmentReduction = bonuses.hearingImpairmentReduction
    end
    
    -- Special handling for HandWeapon items
    local isHandWeapon = false
    local successWeapon, resultWeapon = pcall(function()
        return instanceof(item, "HandWeapon")
    end)
    if successWeapon and resultWeapon then
        isHandWeapon = true
        
        -- Apply damage directly from Lua using setMinDamage/setMaxDamage
        -- Weight is handled by Java patch if available, otherwise skipped
        if bonuses.damageMultiplier then
            local successMin, originalMinDamage = pcall(function()
                if item.getMinDamage then
                    return item:getMinDamage()
                end
                return nil
            end)
            local successMax, originalMaxDamage = pcall(function()
                if item.getMaxDamage then
                    return item:getMaxDamage()
                end
                return nil
            end)
            
            if successMin and successMax and originalMinDamage and originalMaxDamage then
                local newMinDamage = originalMinDamage * bonuses.damageMultiplier
                local newMaxDamage = originalMaxDamage * bonuses.damageMultiplier
                
                local successSet = pcall(function()
                    if item.setMinDamage then
                        item:setMinDamage(newMinDamage)
                    end
                    if item.setMaxDamage then
                        item:setMaxDamage(newMaxDamage)
                    end
                end)
                
                if successSet then
                    print("ZItemTiers: Applied damage multiplier " .. bonuses.damageMultiplier .. "x to HandWeapon: " .. tostring(item:getFullType()))
                end
            end
        end
        
        -- Weight is handled by Java patch if available, otherwise HandWeapon weight reduction is skipped
        -- (getActualWeight() reads from script item and ignores customWeight)
        return
    end
    
    -- Apply encumbrance reduction (for InventoryContainer items - reduces weight of items inside)
    if bonuses.encumbranceReduction then
        if ZItemTiers.ApplyEncumbranceReduction then
            ZItemTiers.ApplyEncumbranceReduction(item, bonuses.encumbranceReduction)
        end
    end
    
    -- Apply weight reduction (applies to item's own weight, for ALL items except HandWeapon)
    -- Containers get both weight reduction (own weight) and encumbrance reduction (items inside)
    if bonuses.weightReduction then
        if ZItemTiers.ApplyWeightReduction then
            ZItemTiers.ApplyWeightReduction(item, bonuses.weightReduction)
        end
    end
    
    -- Check if item is HandWeapon (needed for damage multiplier check later)
    local isHandWeapon = instanceof(item, "HandWeapon")
    
    -- Apply run speed modifier to ALL Clothing items that have a run speed modifier (not just shoes)
    if bonuses.runSpeedModifier then
        if ZItemTiers.ApplyRunSpeedModifier then
            ZItemTiers.ApplyRunSpeedModifier(item, bonuses.runSpeedModifier)
        end
    end
    
    -- Apply bite and scratch defense bonuses (for Clothing items that already have defense)
    if bonuses.biteDefenseBonus then
        if ZItemTiers.ApplyBiteDefenseBonus then
            ZItemTiers.ApplyBiteDefenseBonus(item, bonuses.biteDefenseBonus)
        end
    end
    
    if bonuses.scratchDefenseBonus then
        if ZItemTiers.ApplyScratchDefenseBonus then
            ZItemTiers.ApplyScratchDefenseBonus(item, bonuses.scratchDefenseBonus)
        end
    end
    
    -- Apply capacity bonus (for InventoryContainer items)
    if bonuses.capacityBonus then
        if ZItemTiers.ApplyCapacityBonus then
            ZItemTiers.ApplyCapacityBonus(item, bonuses.capacityBonus)
        end
    end
    
    -- Apply max encumbrance bonus (for InventoryContainer items)
    if bonuses.maxEncumbranceBonus then
        if ZItemTiers.ApplyMaxEncumbranceBonus then
            ZItemTiers.ApplyMaxEncumbranceBonus(item, bonuses.maxEncumbranceBonus, modData)
        end
    end
    
    -- Apply drainable capacity bonus (for Drainable items - liquid containers)
    if bonuses.drainableCapacityBonus then
        if ZItemTiers.ApplyDrainableCapacityBonus then
            ZItemTiers.ApplyDrainableCapacityBonus(item, bonuses.drainableCapacityBonus, modData)
        end
    end
    
    -- Apply vision impairment reduction (for Clothing items with vision impairment)
    if bonuses.visionImpairmentReduction then
        if ZItemTiers.ApplyVisionImpairmentReduction then
            ZItemTiers.ApplyVisionImpairmentReduction(item, bonuses.visionImpairmentReduction, modData)
        end
    end
    
    -- Apply hearing impairment reduction (for Clothing items with hearing impairment)
    if bonuses.hearingImpairmentReduction then
        if ZItemTiers.ApplyHearingImpairmentReduction then
            ZItemTiers.ApplyHearingImpairmentReduction(item, bonuses.hearingImpairmentReduction, modData)
        end
    end
    
    -- Apply damage multiplier (for HandWeapon items - stored in modData, applied via Java patch)
    if bonuses.damageMultiplier and isHandWeapon then
        if ZItemTiers.ApplyDamageMultiplier then
            ZItemTiers.ApplyDamageMultiplier(item, bonuses.damageMultiplier, modData)
        end
    end
    
    -- Apply mood bonus (for Literature items - increases boredom/unhappiness/stress reduction)
    if bonuses.moodBonus then
        if ZItemTiers.ApplyMoodBonus then
            ZItemTiers.ApplyMoodBonus(item, bonuses.moodBonus)
        end
    end
    
    -- Store reading speed bonus in modData for ISReadABook hook (only for books, not VHS tapes)
    if bonuses.readingSpeedBonus then
        local isLiterature = false
        local successLiterature, resultLiterature = pcall(function()
            return instanceof(item, "Literature")
        end)
        if successLiterature and resultLiterature then
            isLiterature = true
        end
        
        if isLiterature then
            -- Check if it's a VHS tape (exclude VHS from reading speed bonus)
            local isVHS = false
            local itemType = item:getType()
            if itemType then
                -- VHS tapes have "VHS" in their type
                if string.find(itemType, "VHS") then
                    isVHS = true
                end
            end
            
            -- Only apply reading speed bonus to books, not VHS tapes
            if not isVHS and modData then
                modData.itemReadingSpeedBonus = bonuses.readingSpeedBonus
            end
        end
    end
    
    -- Store VHS skill XP bonus in modData (only for VHS tapes) -- commented out; VHS blacklisted for now
    --[[
    if bonuses.vhsSkillXpBonus then
        local isVHS = false
        local itemType = item:getType()
        if itemType and string.find(itemType, "VHS") then
            isVHS = true
        end
        if isVHS and modData then
            print("ZItemTiers: [VHS] Applying skill XP bonus to: " .. itemType .. ", tier: " .. tier .. ", bonus: " .. tostring(bonuses.vhsSkillXpBonus))
            modData.itemVhsSkillXpBonus = bonuses.vhsSkillXpBonus
        end
    end
    ]]

    -- Apply battery consumption reduction (for ElectricLight/Torch flashlights)
    if bonuses.batteryConsumptionReduction then
        if ZItemTiers.ApplyBatteryConsumptionReduction then
            ZItemTiers.ApplyBatteryConsumptionReduction(item, bonuses.batteryConsumptionReduction, modData)
        end
    end
    
    -- Apply hunger reduction bonus (for Food items that reduce hunger)
    local isFood = false
    local successFood, resultFood = pcall(function()
        return instanceof(item, "Food")
    end)
    if successFood and resultFood then
        isFood = true
    end
    
    if isFood then
        -- Get current hunger values for debugging
        local successGetBase, baseHunger = pcall(function()
            if item.getBaseHunger then
                return item:getBaseHunger()
            end
            return nil
        end)
        local successGetHungChange, currentHungChange = pcall(function()
            if item.getHungChange then
                return item:getHungChange()
            end
            return nil
        end)
        
        -- Get the original hunger change value from script item (this is the true base value)
        local originalHungChange = nil
        local successGetScript, scriptItem = pcall(function()
            if item.getScriptItem then
                return item:getScriptItem()
            end
            return nil
        end)
        
        if successGetScript and scriptItem then
            -- Script item stores hungerChange as integer (e.g., -10 for -0.1)
            if scriptItem.HungerChange then
                originalHungChange = scriptItem.HungerChange / 100.0
            elseif scriptItem.hungerChange then
                originalHungChange = scriptItem.hungerChange / 100.0
            end
        end
        
        -- If we couldn't get from script item, try getBaseHunger (but it might be modified)
        if not originalHungChange then
            if successGetBase and baseHunger and baseHunger ~= 0.0 then
                originalHungChange = baseHunger
            elseif successGetHungChange and currentHungChange then
                originalHungChange = currentHungChange
            end
        end
        
        -- Only apply bonus if hunger change is negative (reduces hunger) and we got the original from script item
        if originalHungChange and originalHungChange < 0.0 and successGetScript and scriptItem then
            local tierIndex = tierData.index
            local multiplier = 1.0 + (tierIndex - 1) * 0.2
            
            -- Always use script item value as the true base (update stored value if different)
            if modData then
                modData.itemHungerChangeOriginal = originalHungChange
            end
            
            -- Calculate expected modified value
            local expectedModified = originalHungChange * multiplier
            
            -- Check if bonus was already applied correctly
            local needsUpdate = true
            if modData and modData.itemHungerReductionMultiplier then
                if successGetHungChange and currentHungChange and math.abs(currentHungChange - expectedModified) < 0.001 then
                    -- Already applied correctly, skip
                    needsUpdate = false
                end
            end
            
            if needsUpdate then
                -- Apply the modified hunger change to both hungChange and baseHunger
                local successSet = pcall(function()
                    if item.setHungChange then
                        item:setHungChange(expectedModified)
                    end
                    if item.setBaseHunger then
                        item:setBaseHunger(expectedModified)
                    end
                end)
                
                if successSet then
                    -- Store the multiplier in modData to mark bonus as applied
                    if modData then
                        modData.itemHungerReductionMultiplier = multiplier
                    end
                    
                    -- Verify the value was set
                    local verifyHungChange = nil
                    local verifyBaseHunger = nil
                    local successVerify = pcall(function()
                        if item.getHungChange then
                            verifyHungChange = item:getHungChange()
                        end
                        if item.getBaseHunger then
                            verifyBaseHunger = item:getBaseHunger()
                        end
                    end)
                    
                    print("ZItemTiers: Applied hunger reduction multiplier " .. multiplier .. "x to Food: " .. tostring(item:getFullType()) .. " (base: " .. tostring(originalHungChange) .. ", current: " .. tostring(successGetHungChange and currentHungChange or "nil") .. ", new: " .. tostring(expectedModified) .. ", verify: " .. tostring(verifyHungChange) .. ", verifyBase: " .. tostring(verifyBaseHunger) .. ")")
                end
            end
        end
    end
    
    -- Mark bonuses as applied to prevent multiple applications
    -- Always update to current session ID (not just when nil) so session-based caching works after save/load
    if modData then
        modData._bonusesApplied = ZItemTiers._bonusesAppliedSessionId
    end
    
    -- Future bonuses can be added here following the same pattern
end

-- Get the 1-based index of the tier for an item, 1 = Common, 2 = Uncommon, ...
---@param item InventoryItem
---@return number
function ZItemTiers.GetItemTierIndex(item)
    if not item then return ZItemTiers.CommonIdx end
    
    local modData = item:getModData()
    if not modData or not modData.itemTier then
        return ZItemTiers.CommonIdx
    end

    return ZItemTiers.Tiers[modData.itemTier].index
end

-- Get tier key for an item (returns "Common" if no tier assigned or item is nil)
---@param item InventoryItem
---@return string
function ZItemTiers.GetItemTierKey(item)
    if not item then return "Common" end
    
    local modData = item:getModData()
    if not modData or not modData.itemTier then
        return "Common"
    end
    
    return modData.itemTier or "Common"
end

-- Get bonuses for an item (for display purposes)
-- GetItemBonuses is now in bonus_display.lua module

-- Get bonus display name
function ZItemTiers.GetBonusDisplayName(bonusType)
    local displayNames = {
        WeightReduction = "Weight Reduction",
        EncumbranceReduction = "Encumbrance Reduction",
        MaxEncumbranceBonus = "Max Item Encumbrance",
        DamageMultiplier = "Damage",
        RunSpeedModifier = "Run Speed",
        BiteDefenseBonus = "Bite Defense",
        ScratchDefenseBonus = "Scratch Defense",
        CapacityBonus = "Capacity",
        DrainableCapacityBonus = "Liquid Capacity",
        VisionImpairmentReduction = "Vision Impairment Reduction",
        HearingImpairmentReduction = "Hearing Impairment Reduction",
        MoodBonus = "Mood Benefits",
        ReadingSpeedBonus = "Reading Speed",
        VhsSkillXpBonus = "Skill XP Bonus",
    }
    return displayNames[bonusType] or bonusType
end

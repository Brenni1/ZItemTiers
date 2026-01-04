-- Item Rarity Mod
-- Adds rarity-based bonus system to items
-- Each item can spawn with any rarity based on probability, not hardcoded item-to-rarity mapping

ZItemTiers = ZItemTiers or {}

-- Initialize global session ID for bonus tracking (initialized once per game session)
if not ZItemTiers._bonusesAppliedSessionId then
    ZItemTiers._bonusesAppliedSessionId = ZombRand(1000000)
end

-- Blacklist of items that should never have rarity assigned
-- Items in this list will never receive rarity bonuses
ZItemTiers.BlacklistedItems = {
    ["Base.IDcard"] = true,
    -- Keys (a key either works or it doesn't - no benefit from rarity)
    ["Base.Key1"] = true,
    ["Base.Key_Blank"] = true,
    ["Base.CombinationPadlock"] = true,
    ["Base.KeyPadlock"] = true,
    ["Base.Padlock"] = true,
    ["Base.CarKey"] = true,
    ["Base.Brochure"] = true,
    ["Base.Flier"] = true,
    -- Maps (maps are informational items, no benefit from rarity)
    ["Base.Map"] = true,
}

-- Rarity probabilities: [Common, Uncommon, Rare, Epic, Legendary]
-- These determine the chance that an item will be assigned each rarity when it spawns
-- Values should sum to 1.0 (100%)
-- Epic and Legendary are intentionally very rare
ZItemTiers.RarityProbabilities = {0.80, 0.16, 0.032, 0.0064, 0.0016}

-- Global constants for convenience
ZItemTier = ZItemTier or {}
ZItemTier.Common = 1
ZItemTier.Uncommon = 2
ZItemTier.Rare = 3
ZItemTier.Epic = 4
ZItemTier.Legendary = 5

-- Rarity metadata: name, color, and index
ZItemTiers.Rarities = {
    Common = {
        index = ZItemTier.Common,
        name = "Common",
        color = {r=1.0, g=1.0, b=1.0},  -- White
    },
    Uncommon = {
        index = ZItemTier.Uncommon,
        name = "Uncommon",
        color = {r=0.2, g=1.0, b=0.2},  -- Green
    },
    Rare = {
        index = ZItemTier.Rare,
        name = "Rare",
        color = {r=0.2, g=0.4, b=1.0},  -- Blue
    },
    Epic = {
        index = ZItemTier.Epic,
        name = "Epic",
        color = {r=0.8, g=0.2, b=1.0},  -- Purple
    },
    Legendary = {
        index = ZItemTier.Legendary,
        name = "Legendary",
        color = {r=1.0, g=0.8, b=0.0},  -- Gold/Yellow
    },
}

-- Fixed rarity-based bonuses
-- These bonuses are applied to ALL items of that rarity, regardless of item type
-- For HandWeapon items: damage is applied directly from Lua, weight requires Java patches
-- For other items: weight reduction is applied directly
-- For shoes (Clothing with SHOES body location): run speed modifier is applied
ZItemTiers.RarityBonuses = {
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
        moodBonus = 0.1,  -- +10% mood benefits (boredom/unhappiness/stress reduction) for Literature items
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
        moodBonus = 0.2,  -- +20% mood benefits (boredom/unhappiness/stress reduction) for Literature items
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
        moodBonus = 0.3,  -- +30% mood benefits (boredom/unhappiness/stress reduction) for Literature items
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
        moodBonus = 0.5,  -- +50% mood benefits (boredom/unhappiness/stress reduction) for Literature items
    },
}

-- Roll a random rarity based on rarity probabilities
function ZItemTiers.RollRarity()
    local roll = ZombRand(10000) / 10000.0  -- Random 0.0 to 1.0
    local cumulative = 0
    
    for i = 1, #ZItemTiers.RarityProbabilities do
        cumulative = cumulative + ZItemTiers.RarityProbabilities[i]
        if roll <= cumulative then
            -- Find rarity name by index
            for rarityName, rarityData in pairs(ZItemTiers.Rarities) do
                if rarityData.index == i then
                    return rarityName
                end
            end
        end
    end
    
    -- Fallback to Common if something goes wrong
    return "Common"
end

-- Check if an item is blacklisted and should never receive rarity
-- Returns true if the item should be excluded from rarity assignment
function ZItemTiers.IsItemBlacklisted(item)
    if not item then return true end
    
    -- Check if item is in the blacklist by full type name
    local successType, fullType = pcall(function()
        return item:getFullType()
    end)
    if successType and fullType and ZItemTiers.BlacklistedItems[fullType] then
        return true
    end
    
    -- Check if item is a Map type (all maps should be blacklisted)
    local successItemType, itemType = pcall(function()
        if item.getType then
            return item:getType()
        end
        return nil
    end)
    if successItemType and itemType then
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

-- Apply fixed rarity-based bonuses to an item
function ZItemTiers.ApplyRarityBonuses(item, rarity)
    if not item then return end
    
    local itemType = item:getFullType()
    
    -- Debug logging for gas cans
    if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan")) then
        print("ZItemTiers: [DEBUG] ApplyRarityBonuses called for " .. itemType .. " with rarity " .. tostring(rarity))
    end
    
    local rarityData = ZItemTiers.Rarities[rarity]
    if not rarityData then 
        if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan")) then
            print("ZItemTiers: [DEBUG] No rarity data for " .. itemType .. " rarity " .. tostring(rarity))
        end
        return 
    end
    
    local bonuses = ZItemTiers.RarityBonuses[rarity]
    if not bonuses then 
        if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan")) then
            print("ZItemTiers: [DEBUG] No bonuses for " .. itemType .. " rarity " .. tostring(rarity))
        end
        return 
    end
    
    -- Get modData first to check if bonuses have already been applied
    local modData = item:getModData()
    if not modData then 
        if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan")) then
            print("ZItemTiers: [DEBUG] No modData for " .. itemType)
        end
        return 
    end
    
    -- Check if this exact rarity and bonuses have already been applied in this game session
    -- Compare with global session ID to ensure bonuses were applied in the current session
    if modData.itemRarity == rarity and modData._bonusesApplied == ZItemTiers._bonusesAppliedSessionId then
        -- Bonuses already applied for this rarity in this session, skip
        if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan")) then
            print("ZItemTiers: [DEBUG] Bonuses already applied for " .. itemType .. " (rarity: " .. tostring(rarity) .. ", session: " .. tostring(modData._bonusesApplied) .. ")")
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
    
    -- Store rarity in modData
    modData.itemRarity = rarity
    
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
        -- Also store the base value for verification
        local successGetBase, baseValue = pcall(function()
            if item.getScriptItem then
                local scriptItem = item:getScriptItem()
                if scriptItem and scriptItem.runSpeedModifier then
                    return scriptItem.runSpeedModifier
                end
            end
            return 1.0
        end)
        if successGetBase and baseValue then
            modData.itemRunSpeedModifierBase = baseValue
        else
            modData.itemRunSpeedModifierBase = 1.0
        end
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
        local isContainer = false
        local successContainer, resultContainer = pcall(function()
            return instanceof(item, "InventoryContainer")
        end)
        if successContainer and resultContainer then
            isContainer = true
        end
        
        if isContainer then
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
                local newEncumbranceReduction = baseEncumbranceReduction + bonuses.encumbranceReduction
                -- Cap at 85% (never allow 100% encumbrance reduction)
                newEncumbranceReduction = math.min(newEncumbranceReduction, 85)
                
                local success2 = pcall(function()
                    if item.setWeightReduction then
                        item:setWeightReduction(newEncumbranceReduction)
                        print("ZItemTiers: Applied encumbrance reduction +" .. bonuses.encumbranceReduction .. " to container: " .. tostring(item:getFullType()) .. " (base: " .. baseEncumbranceReduction .. ", new: " .. newEncumbranceReduction .. ")")
                    end
                end)
            end
        end
    end
    
    -- Apply weight reduction (applies to item's own weight, for ALL items except HandWeapon)
    -- Containers get both weight reduction (own weight) and encumbrance reduction (items inside)
    if bonuses.weightReduction and not isHandWeapon then
            -- For regular items, reduce the actual weight
            -- First, get the original weight from the script item (before setting customWeight)
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
            
            print("ZItemTiers: Applying weight reduction to item: " .. tostring(item) .. ", rarity: " .. tostring(rarity) .. ", originalWeight: " .. tostring(originalWeight) .. ", reduction: " .. tostring(bonuses.weightReduction) .. "%")
            
            -- Skip items that weigh 0.01 or less
            if success and originalWeight and originalWeight <= 0.01 then
                print("ZItemTiers: Skipping weight reduction for item with weight <= 0.01")
                return
            end
            
            if success and originalWeight and originalWeight > 0.01 then
                -- Calculate new weight: reduce by percentage
                local reductionMultiplier = 1.0 - (bonuses.weightReduction / 100.0)
                local newWeight = originalWeight * reductionMultiplier
                -- Ensure weight doesn't go below 0.01
                newWeight = math.max(newWeight, 0.01)
                
                print("ZItemTiers: Calculated new weight: " .. tostring(newWeight) .. " (from " .. tostring(originalWeight) .. ")")
                
                local success2 = pcall(function()
                    -- Set custom weight flag FIRST (before setting weight)
                    if item.setCustomWeight then
                        item:setCustomWeight(true)
                        print("ZItemTiers: Set customWeight = true")
                    end
                    -- Set the new actual weight
                    if item.setActualWeight then
                        item:setActualWeight(newWeight)
                        print("ZItemTiers: Set actualWeight = " .. tostring(newWeight))
                    end
                    -- Also set weight (some items use this)
                    if item.setWeight then
                        item:setWeight(newWeight)
                        print("ZItemTiers: Set weight = " .. tostring(newWeight))
                    end
                    
                    -- For Clothing items, also update weightWet to maintain the wet weight ratio
                    local isClothing = false
                    local successClothing, resultClothing = pcall(function()
                        return instanceof(item, "Clothing")
                    end)
                    if successClothing and resultClothing then
                        isClothing = true
                    end
                    
                    if isClothing then
                        -- Update weightWet to maintain the 1.25x ratio for wet clothing
                        local newWeightWet = newWeight * 1.25
                        if item.setWeightWet then
                            item:setWeightWet(newWeightWet)
                            print("ZItemTiers: Set weightWet = " .. tostring(newWeightWet) .. " (Clothing item)")
                        end
                    end
                    
                    -- Sync the item to ensure weight change is persisted
                    if item.SynchSpawn then
                        item:SynchSpawn()
                        print("ZItemTiers: Called SynchSpawn() to sync weight change")
                    end
                    
                    -- Verify the weight was set correctly
                    local verifySuccess, verifyWeight = pcall(function()
                        if item.getActualWeight then
                            return item:getActualWeight()
                        end
                        return nil
                    end)
                    if verifySuccess then
                        print("ZItemTiers: Verified actualWeight after setting: " .. tostring(verifyWeight))
                    end
                end)
                
                if not success2 then
                    print("ZItemTiers: ERROR: Failed to set weight reduction")
                end
            else
                print("ZItemTiers: ERROR: Could not get original weight. success=" .. tostring(success) .. ", originalWeight=" .. tostring(originalWeight))
            end
    end
    
    -- Apply run speed modifier to ALL Clothing items that have a run speed modifier (not just shoes)
    if bonuses.runSpeedModifier then
        local isClothing = false
        local successClothing, resultClothing = pcall(function()
            return instanceof(item, "Clothing")
        end)
        if successClothing and resultClothing then
            isClothing = true
        end
        
        if isClothing then
            -- Get the base run speed modifier from the script item (vanilla value)
            local baseRunSpeedMod = 1.0
            local successGetBase, baseValue = pcall(function()
                if item.getScriptItem then
                    local scriptItem = item:getScriptItem()
                    if scriptItem and scriptItem.runSpeedModifier then
                        return scriptItem.runSpeedModifier
                    end
                end
                return 1.0
            end)
            if successGetBase and baseValue then
                baseRunSpeedMod = baseValue
            end
            
            -- Only apply if the item has a non-default run speed modifier (not 1.0)
            if math.abs(baseRunSpeedMod - 1.0) > 0.001 then
                -- Get current run speed modifier from the instance
                local successGet, currentRunSpeedMod = pcall(function()
                    if item.getRunSpeedModifier then
                        return item:getRunSpeedModifier()
                    end
                    return baseRunSpeedMod
                end)
                
                if successGet then
                    -- Calculate new value: base + bonus (additive)
                    local newRunSpeedMod = baseRunSpeedMod + bonuses.runSpeedModifier
                    
                    -- If the base value is negative (below 1.0), cap the result at neutral (1.0)
                    -- Items with negative modifiers should never become positive
                    if baseRunSpeedMod < 1.0 then
                        newRunSpeedMod = math.min(newRunSpeedMod, 1.0)
                    end
                    
                    print("ZItemTiers: Applying run speed modifier to clothing: " .. tostring(item:getFullType()))
                    print("ZItemTiers:   Base (script): " .. tostring(baseRunSpeedMod))
                    print("ZItemTiers:   Current (instance): " .. tostring(currentRunSpeedMod or baseRunSpeedMod))
                    print("ZItemTiers:   Bonus: +" .. tostring(bonuses.runSpeedModifier))
                    print("ZItemTiers:   New value (capped): " .. tostring(newRunSpeedMod))
                    
                    local successSet = pcall(function()
                        if item.setRunSpeedModifier then
                            item:setRunSpeedModifier(newRunSpeedMod)
                            
                            -- Verify it was set
                            local successVerify, verifyValue = pcall(function()
                                if item.getRunSpeedModifier then
                                    return item:getRunSpeedModifier()
                                end
                                return nil
                            end)
                            
                            if successVerify then
                                print("ZItemTiers:   Verified value after setting: " .. tostring(verifyValue))
                            else
                                print("ZItemTiers:   WARNING: Could not verify run speed modifier")
                            end
                        else
                            print("ZItemTiers:   ERROR: setRunSpeedModifier method not found")
                        end
                    end)
                    
                    if not successSet then
                        print("ZItemTiers:   ERROR: Failed to set run speed modifier")
                    end
                else
                    print("ZItemTiers:   ERROR: Could not get current run speed modifier")
                end
            end
        end
    end
    
    -- Apply bite and scratch defense bonuses (for Clothing items that already have defense)
    if bonuses.biteDefenseBonus or bonuses.scratchDefenseBonus then
        local isClothing = false
        local successClothing, resultClothing = pcall(function()
            return instanceof(item, "Clothing")
        end)
        if successClothing and resultClothing then
            isClothing = true
        end
        
        if isClothing then
            -- Apply bite defense bonus (only if item already has bite defense)
            if bonuses.biteDefenseBonus then
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
                        local newBiteDefense = baseBiteDefense + bonuses.biteDefenseBonus
                        -- Cap at 100 (max defense)
                        newBiteDefense = math.min(newBiteDefense, 100)
                        
                        local successSet = pcall(function()
                            if item.setBiteDefense then
                                item:setBiteDefense(newBiteDefense)
                                print("ZItemTiers: Applied bite defense bonus +" .. bonuses.biteDefenseBonus .. " to clothing: " .. tostring(item:getFullType()) .. " (base: " .. baseBiteDefense .. ", new: " .. newBiteDefense .. ")")
                            end
                        end)
                    end
                end
            end
            
            -- Apply scratch defense bonus (only if item already has scratch defense)
            if bonuses.scratchDefenseBonus then
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
                        local newScratchDefense = baseScratchDefense + bonuses.scratchDefenseBonus
                        -- Cap at 100 (max defense)
                        newScratchDefense = math.min(newScratchDefense, 100)
                        
                        local successSet = pcall(function()
                            if item.setScratchDefense then
                                item:setScratchDefense(newScratchDefense)
                                print("ZItemTiers: Applied scratch defense bonus +" .. bonuses.scratchDefenseBonus .. " to clothing: " .. tostring(item:getFullType()) .. " (base: " .. baseScratchDefense .. ", new: " .. newScratchDefense .. ")")
                            end
                        end)
                    end
                end
            end
        end
    end
    
    -- Apply capacity bonus (for InventoryContainer items)
    if bonuses.capacityBonus then
        local isContainer = false
        local successContainer, resultContainer = pcall(function()
            return instanceof(item, "InventoryContainer")
        end)
        if successContainer and resultContainer then
            isContainer = true
        end
        
        if isContainer then
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
                local capacityMultiplier = 1.0 + (bonuses.capacityBonus / 100.0)
                local newCapacity = math.floor(baseCapacity * capacityMultiplier + 0.5)  -- Round to nearest integer
                -- Cap at 50 (max capacity for bags)
                newCapacity = math.min(newCapacity, 50)
                
                local successSet = pcall(function()
                    if item.setCapacity then
                        item:setCapacity(newCapacity)
                        print("ZItemTiers: Applied capacity bonus +" .. bonuses.capacityBonus .. "% to container: " .. tostring(item:getFullType()) .. " (base: " .. baseCapacity .. ", new: " .. newCapacity .. ")")
                    end
                end)
            end
        end
    end
    
    -- Apply max encumbrance bonus (for InventoryContainer items)
    if bonuses.maxEncumbranceBonus then
        local isContainer = false
        local successContainer, resultContainer = pcall(function()
            return instanceof(item, "InventoryContainer")
        end)
        if successContainer and resultContainer then
            isContainer = true
        end
        
        if isContainer then
            -- Get base max item size from script item
            local baseMaxItemSize = 0
            local successGetBase, baseValue = pcall(function()
                if item.getScriptItem then
                    local scriptItem = item:getScriptItem()
                    if scriptItem and scriptItem.getMaxItemSize then
                        return scriptItem:getMaxItemSize()
                    end
                end
                return 0
            end)
            if successGetBase and baseValue then
                baseMaxItemSize = baseValue
            end
            
            -- Only apply if the container has a max item size (some containers don't have this restriction)
            if baseMaxItemSize > 0 then
                -- Get current max item size from the instance
                local successGet, currentMaxItemSize = pcall(function()
                    if item.getMaxItemSize then
                        return item:getMaxItemSize()
                    end
                    return baseMaxItemSize
                end)
                
                if successGet then
                    -- Calculate new max item size: base + flat bonus (additive)
                    local newMaxItemSize = baseMaxItemSize + bonuses.maxEncumbranceBonus
                    
                    -- Store the bonus in modData - the Java patch will read it and apply it
                    -- Also store the base value for the Java patch
                    if modData then
                        modData.itemMaxEncumbranceBonus = bonuses.maxEncumbranceBonus
                        modData.itemMaxEncumbranceBase = baseMaxItemSize
                        print("ZItemTiers: Stored max encumbrance bonus +" .. bonuses.maxEncumbranceBonus .. " for container: " .. tostring(item:getFullType()) .. " (base: " .. baseMaxItemSize .. ", will be: " .. newMaxItemSize .. " via Java patch)")
                    else
                        print("ZItemTiers: ERROR: Could not store max encumbrance bonus - modData is nil")
                    end
                end
            end
        end
    end
    
    -- Apply drainable capacity bonus (for Drainable items - liquid containers)
    if bonuses.drainableCapacityBonus then
        local itemType = item:getFullType()
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
        
        -- Debug logging for drainable items (especially gas cans)
        if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan") or string.find(itemType, "WaterBottle") or string.find(itemType, "Bottle")) then
            print("ZItemTiers: [DEBUG] Checking drainable item: " .. itemType .. ", isDrainable=" .. tostring(isDrainable) .. ", rarity=" .. tostring(rarity) .. ", bonus=" .. tostring(bonuses.drainableCapacityBonus))
        end
        
        if isDrainable then
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
            if modData and modData.itemDrainableCapacityBase and modData.itemDrainableCapacityBase > 0 then
                -- Only use stored base if it was set in the current session
                if modData._bonusesApplied == ZItemTiers._bonusesAppliedSessionId then
                    storedBaseIsValid = true
                    baseCapacity = modData.itemDrainableCapacityBase
                    print("ZItemTiers: Using stored base capacity " .. baseCapacity .. " for " .. tostring(item:getFullType()) .. " (session matches)")
                else
                    -- Stored base is from a different session, invalidate it
                    modData.itemDrainableCapacityBase = nil
                    print("ZItemTiers: Invalidated stored base capacity for " .. tostring(item:getFullType()) .. " (session mismatch)")
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
                    print("ZItemTiers: Got base capacity " .. baseCapacity .. " from fresh instance/script item for " .. tostring(item:getFullType()) .. " (current: " .. currentCapacity .. ")")
                elseif currentCapacity > 0 then
                    -- No bonus stored yet, assume current is base (first time application)
                    -- This should only happen on the very first application before any modifications
                    -- WARNING: This might be wrong if the item was already modified
                    baseCapacity = currentCapacity
                    print("ZItemTiers: WARNING: Using current capacity " .. currentCapacity .. " as base (first application) for " .. tostring(item:getFullType()) .. " - this might be incorrect if item was already modified!")
                else
                    print("ZItemTiers: ERROR: Could not determine base capacity for " .. tostring(item:getFullType()) .. " (current: " .. currentCapacity .. ")")
                end
                
                -- Store the base capacity in modData for future use
                if modData and baseCapacity > 0 then
                    modData.itemDrainableCapacityBase = baseCapacity
                end
            end
            
            -- Only apply if we have a valid base capacity
            if baseCapacity > 0 then
                -- Calculate expected capacity: base * (1 + bonus percentage / 100)
                local capacityMultiplier = 1.0 + (bonuses.drainableCapacityBonus / 100.0)
                local expectedCapacity = baseCapacity * capacityMultiplier
                
                -- Check if bonus has already been applied (within small tolerance for floating point)
                if math.abs(currentCapacity - expectedCapacity) < 0.01 then
                    -- Already applied, skip this bonus (but continue with other bonuses)
                    print("ZItemTiers: [DEBUG] Drainable capacity bonus already applied for " .. tostring(item:getFullType()) .. " (current: " .. currentCapacity .. ", expected: " .. expectedCapacity .. ")")
                else
                    -- Debug logging before applying
                    print("ZItemTiers: [DEBUG] Applying drainable capacity bonus to " .. tostring(item:getFullType()) .. " (current: " .. currentCapacity .. ", base: " .. baseCapacity .. ", expected: " .. expectedCapacity .. ")")
                    
                    local successSet = pcall(function()
                        if item.getFluidContainer then
                            local fluidContainer = item:getFluidContainer()
                            if fluidContainer and fluidContainer.setCapacity then
                                fluidContainer:setCapacity(expectedCapacity)
                                print("ZItemTiers: Applied drainable capacity bonus +" .. bonuses.drainableCapacityBonus .. "% to drainable: " .. tostring(item:getFullType()) .. " (base: " .. baseCapacity .. ", new: " .. expectedCapacity .. ")")
                            end
                        end
                    end)
                end
            else
                -- Debug logging when base capacity is 0
                if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan")) then
                    print("ZItemTiers: [DEBUG] ERROR: baseCapacity is 0 for " .. itemType .. " (current: " .. currentCapacity .. ")")
                end
            end
        end
    end
    
    -- Apply vision impairment reduction (for Clothing items with vision impairment)
    if bonuses.visionImpairmentReduction then
        local isClothing = false
        local successClothing, resultClothing = pcall(function()
            return instanceof(item, "Clothing")
        end)
        if successClothing and resultClothing then
            isClothing = true
        end
        
        if isClothing then
            -- Get base vision modifier from script item
            -- Vision modifier: 1.0 = no impairment, < 1.0 = impairment (lower = worse)
            -- We want to increase the modifier (make it closer to 1.0) by adding the reduction
            local baseVisionMod = 1.0
            local successGetBase, baseValue = pcall(function()
                if item.getScriptItem then
                    local scriptItem = item:getScriptItem()
                    if scriptItem then
                        -- Try getVisionModifier method first
                        if scriptItem.getVisionModifier then
                            return scriptItem:getVisionModifier()
                        end
                        -- Fallback: try visionModifier property
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
            if successGetBase and baseValue then
                baseVisionMod = baseValue
            end
            
            -- Only apply if the item has vision impairment (modifier < 1.0)
            if baseVisionMod < 1.0 then
                -- Get current vision modifier from the instance
                local successGet, currentVisionMod = pcall(function()
                    if item.getVisionModifier then
                        return item:getVisionModifier()
                    end
                    -- Fallback: try to get from script item
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
                    return baseVisionMod
                end)
                
                if successGet then
                    -- Calculate expected new value: base + reduction (additive, but don't go above 1.0)
                    -- The modifier represents impairment when < 1.0, so increasing it means less impairment
                    local newVisionMod = math.min(1.0, baseVisionMod + bonuses.visionImpairmentReduction)
                    
                    -- Store base value and reduction in modData for Java patch
                    -- The Java patch will read itemVisionImpairmentReduction from modData and apply it to getVisionModifier()
                    if modData then
                        modData.itemVisionImpairmentBase = baseVisionMod
                        modData.itemVisionImpairmentReduction = bonuses.visionImpairmentReduction
                        print("ZItemTiers: Stored vision impairment reduction +" .. bonuses.visionImpairmentReduction .. " for clothing: " .. tostring(item:getFullType()) .. " (base: " .. baseVisionMod .. ", will be: " .. newVisionMod .. " via Java patch)")
                    end
                else
                    print("ZItemTiers: ERROR: Could not get current vision modifier for " .. tostring(item:getFullType()))
                end
            else
                -- Debug: log when item doesn't have vision impairment
                if item:getFullType() and string.find(item:getFullType(), "SafetyGoggles") then
                    print("ZItemTiers: [DEBUG] SafetyGoggles vision modifier: " .. tostring(baseVisionMod) .. " (no reduction applied, modifier >= 1.0)")
                end
            end
        end
    end
    
    -- Apply mood bonus (for Literature items - increases boredom/unhappiness/stress reduction)
    if bonuses.moodBonus then
        local isLiterature = false
        local successLiterature, resultLiterature = pcall(function()
            return instanceof(item, "Literature")
        end)
        if successLiterature and resultLiterature then
            isLiterature = true
        end
        
        if isLiterature then
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
            local moodMultiplier = 1.0 + bonuses.moodBonus
            
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
    end
    
    -- Mark bonuses as applied to prevent multiple applications
    -- Use the global session ID initialized once per game session
    if modData then
        if not modData._bonusesApplied then
            modData._bonusesApplied = ZItemTiers._bonusesAppliedSessionId
        end
    end
    
    -- Future bonuses can be added here following the same pattern
end

-- Get rarity for an item
function ZItemTiers.GetItemRarity(item)
    if not item then return "Common" end
    
    local modData = item:getModData()
    if not modData or not modData.itemRarity then
        return "Common"
    end
    
    return modData.itemRarity
end

-- Get bonuses for an item (for display purposes)
function ZItemTiers.GetItemBonuses(item)
    if not item then return {} end
    
    local rarity = ZItemTiers.GetItemRarity(item)
    local bonuses = ZItemTiers.RarityBonuses[rarity]
    if not bonuses then return {} end
    
    -- Convert to list format for display
    local bonusList = {}
    
    -- Check if this is a container to show encumbrance reduction instead of weight reduction
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
    
    -- Check if this is a HandWeapon to show damage multiplier
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
    
    -- Check if this is a Clothing item with a run speed modifier to show it
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
    
    -- Check if this is a Clothing item with defense to show defense bonuses
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
    
    -- Check if this is an InventoryContainer to show capacity bonus
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
        
        -- Check if this is a Drainable item to show drainable capacity bonus
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
    
    -- Check if this is a Clothing item with vision impairment to show vision impairment reduction
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
    
    -- Check if this is a Literature item to show mood bonus
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
    
    return bonusList
end

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
    MoodBonus = "Mood Benefits",
}
    return displayNames[bonusType] or bonusType
end

-- Apply rarity to a single item entry
-- Since any item can have any rarity, we don't modify spawn chances
-- Items spawn at their base rate, but get assigned a rarity based on probabilities
function ZItemTiers.ApplyRarityToItem(itemName, baseChance)
    -- Don't modify spawn chance - items spawn at base rate regardless of rarity
    return baseChance
end

-- Backward compatibility alias
ZItemTiers.ApplyRarityScaling = ZItemTiers.ApplyRarityBonuses
ZItemTiers.ApplyRarityDurability = ZItemTiers.ApplyRarityBonuses

-- Apply rarities to a distribution table's items array
function ZItemTiers.ApplyRaritiesToItems(items)
    if not items or type(items) ~= "table" then return 0, 0 end
    
    local applied = 0
    local nonApplied = 0
    
    for i = 1, #items, 2 do
        local itemName = items[i]
        local chanceIndex = i + 1
        
        if type(itemName) == "string" and items[chanceIndex] and type(items[chanceIndex]) == "number" then
            items[chanceIndex] = ZItemTiers.ApplyRarityToItem(itemName, items[chanceIndex])
            applied = applied + 1
        else
            nonApplied = nonApplied + 1
        end
    end
    
    return applied, nonApplied
end

-- Recursively apply rarities to a distribution container
function ZItemTiers.ApplyRaritiesToDistribution(distTable)
    if not distTable or type(distTable) ~= "table" then return 0, 0 end
    
    local totalApplied = 0
    local totalNonApplied = 0
    
    -- Apply to main items array
    if distTable.items then
        local applied, nonApplied = ZItemTiers.ApplyRaritiesToItems(distTable.items)
        totalApplied = totalApplied + applied
        totalNonApplied = totalNonApplied + nonApplied
    end
    
    -- Apply to junk items
    if distTable.junk and distTable.junk.items then
        local applied, nonApplied = ZItemTiers.ApplyRaritiesToItems(distTable.junk.items)
        totalApplied = totalApplied + applied
        totalNonApplied = totalNonApplied + nonApplied
    end
    
    -- Recursively process nested containers
    for key, value in pairs(distTable) do
        if type(value) == "table" and key ~= "items" and key ~= "junk" and key ~= "procList" then
            local applied, nonApplied = ZItemTiers.ApplyRaritiesToDistribution(value)
            totalApplied = totalApplied + applied
            totalNonApplied = totalNonApplied + nonApplied
        end
    end
    
    return totalApplied, totalNonApplied
end

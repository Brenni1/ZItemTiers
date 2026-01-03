-- Item Rarity Mod
-- Adds rarity-based bonus system to items
-- Each item can spawn with any rarity based on probability, not hardcoded item-to-rarity mapping

ZItemTiers = ZItemTiers or {}

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
}

-- Rarity probabilities: [Common, Uncommon, Rare, Epic, Legendary]
-- These determine the chance that an item will be assigned each rarity when it spawns
-- Values should sum to 1.0 (100%)
ZItemTiers.RarityProbabilities = {0.855, 0.08, 0.04, 0.02, 0.005}

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
ZItemTiers.RarityBonuses = {
    Common = {
        -- No bonuses for Common items
    },
    Uncommon = {
        weightReduction = 10,  -- 10% weight reduction
        damageMultiplier = 1.1,  -- 10% more damage (for HandWeapon)
    },
    Rare = {
        weightReduction = 20,  -- 20% weight reduction
        damageMultiplier = 1.2,  -- 20% more damage (for HandWeapon)
    },
    Epic = {
        weightReduction = 30,  -- 30% weight reduction
        damageMultiplier = 1.4,  -- 40% more damage (for HandWeapon)
    },
    Legendary = {
        weightReduction = 50,  -- 50% weight reduction
        damageMultiplier = 1.6,  -- 60% more damage (for HandWeapon)
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
    
    return false
end

-- Apply fixed rarity-based bonuses to an item
function ZItemTiers.ApplyRarityBonuses(item, rarity)
    if not item then return end
    
    local rarityData = ZItemTiers.Rarities[rarity]
    if not rarityData then return end
    
    local bonuses = ZItemTiers.RarityBonuses[rarity]
    if not bonuses then return end
    
    -- Store rarity in modData
    local modData = item:getModData()
    if modData then
        modData.itemRarity = rarity
        -- Store the target weight reduction percentage so we can re-apply it if weight gets reset
        if bonuses.weightReduction then
            modData.itemWeightReduction = bonuses.weightReduction
        end
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
    
    -- Apply weight reduction (applies to ALL items except HandWeapon)
    if bonuses.weightReduction and not isHandWeapon then
        -- For containers (bags/backpacks), use setWeightReduction
        local isContainer = false
        local successContainer, resultContainer = pcall(function()
            return instanceof(item, "InventoryContainer")
        end)
        if successContainer and resultContainer then
            isContainer = true
        end
        
        if isContainer then
            -- For containers, use weight reduction percentage
            local success, currentWeightReduction = pcall(function()
                if item.getWeightReduction then
                    return item:getWeightReduction()
                end
                return 0
            end)
            
            if success then
                -- Add rarity weight reduction to existing weight reduction (if any)
                local newWeightReduction = (currentWeightReduction or 0) + bonuses.weightReduction
                -- Cap at 100%
                newWeightReduction = math.min(newWeightReduction, 100)
                
                local success2 = pcall(function()
                    if item.setWeightReduction then
                        item:setWeightReduction(newWeightReduction)
                    end
                end)
            end
        else
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
    
    return bonusList
end

-- Get bonus display name
function ZItemTiers.GetBonusDisplayName(bonusType)
    local displayNames = {
        WeightReduction = "Weight Reduction",
        DamageMultiplier = "Damage",
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

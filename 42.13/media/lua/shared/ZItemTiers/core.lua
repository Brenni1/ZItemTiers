-- Item Rarity Mod
-- Adds rarity-based bonus system to items
-- Each item can spawn with any rarity based on probability, not hardcoded item-to-rarity mapping

ZItemTiers = ZItemTiers or {}

-- Rarity probabilities: [Common, Uncommon, Rare, Epic, Legendary]
-- These determine the chance that an item will be assigned each rarity when it spawns
-- Values should sum to 1.0 (100%)
ZItemTiers.RarityProbabilities = {0.65, 0.20, 0.10, 0.04, 0.01}

-- Global constants for convenience
ZItemTier = ZItemTier or {}
ZItemTier.Common = 1
ZItemTier.Uncommon = 2
ZItemTier.Rare = 3
ZItemTier.Epic = 4
ZItemTier.Legendary = 5

-- Load bonus definitions (single source of truth)
require "ZItemTiers/bonuses"

-- Bonus level multipliers: [Level 1, Level 2, Level 3, Level 4, Level 5]
ZItemTiers.BonusLevelMultipliers = {
    [1] = 1.10,  -- +10%
    [2] = 1.25,  -- +25%
    [3] = 1.50,  -- +50%
    [4] = 1.75,  -- +75%
    [5] = 2.00,  -- +100%
}

-- Rarity bonus configurations
-- Each entry defines possible bonus combinations: {count, minLevel, maxLevel}
-- The system will randomly choose one configuration and roll bonuses
ZItemTiers.RarityBonusConfigs = {
    Common = {},  -- No bonuses
    Uncommon = {
        {count = 1, minLevel = 1, maxLevel = 1},  -- 1 bonus of level 1
    },
    Rare = {
        {count = 2, minLevel = 1, maxLevel = 2},  -- 2 bonuses of levels 1-2 each
        {count = 1, minLevel = 2, maxLevel = 2},  -- OR 1 bonus of level 2
    },
    Epic = {
        {count = 3, minLevel = 1, maxLevel = 3},  -- 3 bonuses of levels 1-3 each
        {count = 2, minLevel = 2, maxLevel = 3},  -- OR 2 bonuses of levels 2-3 each
        {count = 1, minLevel = 3, maxLevel = 3},  -- OR 1 bonus of level 3
    },
    Legendary = {
        {count = 3, minLevel = 2, maxLevel = 4},
        {count = 2, minLevel = 3, maxLevel = 4},
        {count = 1, minLevel = 4, maxLevel = 5},
    },
}

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

-- Get all available bonus types for an item
function ZItemTiers.GetAvailableBonusTypes(item)
    local available = {}
    
    -- Check each bonus type using its checkApplicable function
    for bonusType, bonusData in pairs(ZItemTiers.Bonuses) do
        if bonusData.checkApplicable then
            local success, isApplicable = pcall(bonusData.checkApplicable, item)
            if success and isApplicable then
                table.insert(available, bonusType)
            end
        end
    end
    
    return available
end

-- Roll bonuses for a given rarity
function ZItemTiers.RollBonuses(rarity, availableBonusTypes)
    if not availableBonusTypes or #availableBonusTypes == 0 then
        return {}
    end
    
    local configs = ZItemTiers.RarityBonusConfigs[rarity]
    if not configs or #configs == 0 then
        return {}
    end
    
    -- Randomly choose one configuration
    local config = configs[ZombRand(#configs) + 1]
    
    -- Roll bonuses
    local bonuses = {}
    local usedTypes = {}
    
    for i = 1, config.count do
        -- Filter out already used bonus types
        local available = {}
        for _, bonusType in ipairs(availableBonusTypes) do
            if not usedTypes[bonusType] then
                table.insert(available, bonusType)
            end
        end
        
        if #available == 0 then
            break  -- No more available bonus types
        end
        
        -- Randomly select a bonus type
        local selectedType = available[ZombRand(#available) + 1]
        usedTypes[selectedType] = true
        
        -- Roll a level based on config (minLevel to maxLevel)
        local level
        if config.minLevel and config.maxLevel then
            -- Level range specified
            local range = config.maxLevel - config.minLevel + 1
            level = config.minLevel + ZombRand(range)
        else
            -- Fallback: use maxLevel if specified, otherwise level 1
            level = config.maxLevel or 1
        end
        
        table.insert(bonuses, {
            type = selectedType,
            level = level,
            multiplier = ZItemTiers.BonusLevelMultipliers[level] or 1.0
        })
    end
    
    return bonuses
end

-- Get multiplier for a specific bonus type and level
function ZItemTiers.GetBonusMultiplier(bonusType, level)
    return ZItemTiers.BonusLevelMultipliers[level] or 1.0
end

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

-- Apply rarity to a single item entry
-- Since any item can have any rarity, we don't modify spawn chances
-- Items spawn at their base rate, but get assigned a rarity based on probabilities
function ZItemTiers.ApplyRarityToItem(itemName, baseChance)
    -- Don't modify spawn chance - items spawn at base rate regardless of rarity
    return baseChance
end

-- Apply bonus-based scaling to an item
function ZItemTiers.ApplyRarityScaling(item, rarity)
    if not item then return end
    
    local rarityData = ZItemTiers.Rarities[rarity]
    if not rarityData then return end
    
    -- Get available bonus types for this item
    local availableBonusTypes = ZItemTiers.GetAvailableBonusTypes(item)
    if #availableBonusTypes == 0 then
        return  -- Item has no scalable properties
    end
    
    -- Roll bonuses for this rarity
    local bonuses = ZItemTiers.RollBonuses(rarity, availableBonusTypes)
    
    -- Store bonuses in modData
    local modData = item:getModData()
    if modData then
        modData.itemRarity = rarity
        modData.itemBonuses = bonuses
    end
    
    -- Apply each bonus using its applyBonus function
    for _, bonus in ipairs(bonuses) do
        local bonusData = ZItemTiers.Bonuses[bonus.type]
        if bonusData and bonusData.applyBonus then
            local success = pcall(bonusData.applyBonus, item, bonus.multiplier)
            if not success then
                -- Silently fail if bonus application fails
            end
        end
    end
end

-- Backward compatibility: Get multiplier by rarity name (now returns 1.0 since we use bonuses)
function ZItemTiers.GetMultiplier(rarityName, multiplierType)
    -- This function is kept for backward compatibility but always returns 1.0
    -- since we now use a bonus-based system
    return 1.0
end

-- Get bonuses for an item
function ZItemTiers.GetItemBonuses(item)
    if not item then return {} end
    
    local modData = item:getModData()
    if not modData or not modData.itemBonuses then
        return {}
    end
    
    return modData.itemBonuses
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

-- Backward compatibility alias
ZItemTiers.ApplyRarityDurability = ZItemTiers.ApplyRarityScaling

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

ZItemTiers = ZItemTiers or {}
ZItemTiers.logger = ZItemTiers.logger or zdk.Logger.new("ZItemTiers", zdk.Logger.DEBUG)
local logger = ZItemTiers.logger

-- Blacklist of items that should never have tier assigned
-- Items in this list will never receive tier bonuses
ZItemTiers.NoTierItems = {
    getDisplayCategory = {
        ["Ammo"] = true,
    },
    getFullType = {
        ["Base.Brochure"]           = true,
        ["Base.CarKey"]             = true,
        ["Base.CombinationPadlock"] = true,
        ["Base.Flier"]              = true,
        ["Base.GolfTee"]            = true,
        ["Base.IDcard"]             = true,
        ["Base.IDcard_Female"]      = true,
        ["Base.IDcard_Male"]        = true,
        ["Base.Key_Blank"]          = true,
        ["Base.Key1"]               = true,
        ["Base.KeyPadlock"]         = true,
        ["Base.Map"]                = true,
        ["Base.Money"]              = true,
        ["Base.Padlock"]            = true,
        ["Base.Splinters"]          = true,
        ["Base.UnusableWood"]       = true,
    }
}

-- Initialize global session ID for bonus tracking (initialized once per game session)
if not ZItemTiers.sid then
    ZItemTiers.sid = ZombRand(1000000)
end

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

local TIER_NAMES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

function ZItemTiers.GetTierNameFromT0(t0)
    return TIER_NAMES[t0 + 1]
end

function ZItemTiers.GetT0FromTierName(tierName)
    return ZItemTiers.Tiers[tierName].index - 1
end

function ZItemTiers.GetOrCreateZIT(item)
    if not item or not item.getModData then return nil end
    
    local modData = item:getModData()
    if not modData then return nil end

    if type(modData.ZIT) ~= "table" then
        modData.ZIT = {}
    end

    local zit = modData.ZIT

    -- migrate old itemTier
    if modData.itemTier and not zit.itemTier then
        zit.itemTier = modData.itemTier
        if modData.craftedFromTier then
            zit.craftedFromTier = modData.craftedFromTier
        end
    end

    return zit
end

function ZItemTiers.GetZIT(item)
    if not item or not item.getModData then return nil end
    
    local modData = item:getModData()
    if not modData then return nil end

    if type(modData.ZIT) ~= "table" then return nil end

    return modData.ZIT
end

-- Roll a random tier based on tier probabilities
function ZItemTiers.RollTier()
    local roll = ZombRandFloat(0.0, 1.0)
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
    
    for getterName, values in pairs(ZItemTiers.NoTierItems) do
        local getter = item[getterName]
        if getter then
            local value = getter(item)
            if value and values[value] then return true end
        end
    end

    -- VHS tapes: blacklist by pattern (any fullType containing "VHS")
    if fullType and string.find(fullType, "VHS") then
        return true
    end

    -- Check if item is a Map type (all maps should be blacklisted)
    local itemType = item:getType()
    if itemType then
        local isMap = (ItemType and ItemType.MAP and itemType == ItemType.MAP) or
            (itemType.toString and itemType:toString() == "Map")
        if isMap then
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
    if modData and modData.itemRunSpeedModifierBase and modData._bonusesApplied == ZItemTiers.sid then
        return modData.itemRunSpeedModifierBase
    end

    local base = 1.0

    -- Primary: script item getter (authoritative, always returns the vanilla base)
    if item.getScriptItem then
        local scriptItem = item:getScriptItem()
        if scriptItem then
            if scriptItem.getRunSpeedModifier then
                base = scriptItem:getRunSpeedModifier()
            elseif scriptItem.runSpeedModifier then
                base = scriptItem.runSpeedModifier
            end
        end
    end

    -- Fallback: instance method (correct on first application before any modifications)
    if math.abs(base - 1.0) <= 0.001 and item.getRunSpeedModifier then
        base = item:getRunSpeedModifier()
    end

    -- Cache in modData for future calls
    if modData then
        modData.itemRunSpeedModifierBase = base
    end

    return base
end

-- returns smth like:
-- {
--    "carbohydrates" => 72,
--           "lipids" => 45,
--         "proteins" => 4.5,
--    "unhappychange" => -5,
--           "weight" => 0.2,
--         "calories" => 720,
--     "hungerchange" => -15
--}
function ZItemTiers.ParseItemScript(scriptItem)
    local all_fields = zdk.parse_item_script(scriptItem)
    local numeric_only = {}
    for k, v in pairs(all_fields) do
        v = tonumber(v)
        if v then
            numeric_only[k] = v
        end
    end
    return numeric_only
end

local _negativeCategoryCache = {}

ZItemTiers.negativeCategoryCache = _negativeCategoryCache -- for debug

function ZItemTiers.ApplyBonuses(item, forceTier)
    if ZItemTiers.IsItemBlacklisted(item) then
        local zit = ZItemTiers.GetZIT(item)
        if zit and zit.itemTier then
            -- logger:debug("Removing tier from blacklisted item %s", item)
            zit.itemTier = nil
            zit.bonuses = nil
        end
        return
    end

    if forceTier then
        ZItemTiers.SetItemTier(item, forceTier)
    end
    local t0 = ZItemTiers.GetItemTierIndex0(item)
    if t0 == 0 then return end -- No bonuses for Common tier

    -- logger:debug("Applying tier %d (%s) to %s", t0, ZItemTiers.GetTierNameFromT0(t0), item)
    if t0 <= 0 then
        logger:error("Invalid tier index %d for item %s, skipping bonuses", t0, item)
        return
    end

    local zit = ZItemTiers.GetOrCreateZIT(item)
    local curTime = getGameTime():getCalender():getTimeInMillis()
    if zit.sid == ZItemTiers.sid and zit.ts and curTime - zit.ts < 600000 then
        -- logger:debug("Bonuses already applied recently for %s, skipping", item)
        return
    end

    zit.ts      = curTime
    zit.sid     = ZItemTiers.sid
    zit.bonuses = zit.bonuses or {}

    local scriptItem    = item:getScriptItem()
    local itemScriptTbl = ZItemTiers.ParseItemScript(scriptItem)
    local itemCategory  = item:getCategory() or "?"

    _negativeCategoryCache[itemCategory] = _negativeCategoryCache[itemCategory] or {}
    local nCatCache = _negativeCategoryCache[itemCategory]

    local function apply_bonuses(item, bonuses)
        if not bonuses then return end

        for key, bonus in pairs(bonuses) do
            if not nCatCache[key] then
                local target  = item
                local base    = itemScriptTbl[key:lower()] or (scriptItem[bonus.getter] and scriptItem[bonus.getter](scriptItem))
                local applied = false

                if bonus.component then -- e.g. FluidContainer
                    base = nil
                    target = item:getComponent(bonus.component)
                    if target then
                        local compScript = scriptItem:getComponentScriptFor(bonus.component)
                        base = compScript[bonus.getter] and compScript[bonus.getter](compScript)
                    end
                end

                if bonus.applyIfNull or (base and (base ~= 0 or bonus.applyIfZero)) then
                    if target and target[bonus.setter] then
                        base = base or 0 -- when applyIfNull is true, treat nil as 0 for bonus calculation
                        local modified = bonus:func(base, t0, item)
                        if modified and modified ~= base then
                            target[bonus.setter](target, modified)
                            if bonus.afterSet then
                                bonus:afterSet(item, base, modified)
                            end
                            zit.bonuses[key] = {
                                base     = base,
                                modified = modified,
                            }
                            applied = true
                        end
                    else
                        logger:debug("%s: no %s(), itemCategory=%s", item, bonus.setter, itemCategory)
                        nCatCache[key] = true -- cache that this category doesn't have this bonus to avoid future warnings
                    end
                end

                if not applied and zit.bonuses[key] then
                    zit.bonuses[key] = nil
                end
            end
        end
    end

    apply_bonuses(item, ZItemTiers.CatBonuses[itemCategory])
    apply_bonuses(item, ZItemTiers.CatBonuses.All)

    return true
end

-- Get the 1-based index of the tier for an item, 1 = Common, 2 = Uncommon, ...
-- guaranteed to return a number between 1 and 5
-- (used by ZGlassCutter and ZSpaceship))
---@param item InventoryItem
---@return number
function ZItemTiers.GetItemTierIndex(item)
    if not item then return ZItemTiers.CommonIdx end
    

    local zit = ZItemTiers.GetOrCreateZIT(item)
    if not zit.itemTier then
        return ZItemTiers.CommonIdx
    end

    local tier = ZItemTiers.Tiers[zit.itemTier]
    if not tier then return ZItemTiers.CommonIdx end

    return tier.index
end

-- Get the 0-based index of the tier for an item, 0 = Common, 1 = Uncommon, ...
function ZItemTiers.GetItemTierIndex0(item)
    local idx1 = ZItemTiers.GetItemTierIndex(item)
    return idx1 - 1
end

function ZItemTiers.SetItemTier(item, tierName)
    local zit = ZItemTiers.GetOrCreateZIT(item)
    zit.itemTier = tierName
end

-- Get tier key for an item (returns "Common" if no tier assigned or item is nil)
---@param item InventoryItem
---@return string
function ZItemTiers.GetItemTierKey(item)
    if not item then return nil end
    
    local zit = ZItemTiers.GetZIT(item)
    return (zit and zit.itemTier) or "Common"
end


-- Calculate output tier based on ingredient tiers (Factorio-style)
-- Returns the calculated tier name
-- Parameters:
--   src:               ArrayList/table of ingredient items
--   perk:   [optional] relevant Perk for skill level calculation (overrides recipe's)
--   player: [optional] IsoGameCharacter performing the craft
--   recipe: [optional] CraftRecipe being performed
--   tools:  [optional] table of tools used (e.g. for sewing machine)
-- Rules:
-- 1. If all ingredients are Epic, output is at least Epic
-- 2. If ingredients have different tiers, output tier is based on their ratio/probability
-- 3. Output is always at least the minimum (highest tier) tier among ingredients
-- 4. Skill level affects the result:
--    - Level 0: 50% chance to be 1 tier lower
--    - Level 1: Keep calculated tier (no change)
--    - Level > 1: Small chance (5% per level above 1) to be 1 tier higher
function ZItemTiers.CalculateCraftingTier(tbl)
    local logger = logger:withPrefix("CalculateCraftingTier() ")

    local src    = tbl.src
    local perk   = tbl.perk
    local player = tbl.player
    local recipe = tbl.recipe
    local tools  = tbl.tools  -- TODO: use

    if type(src) ~= "table" and src.toArray then
        src = src:toArray()
    end
    if type(src) ~= "table" then
        logger:error("Invalid src parameter: expected ArrayList or table, got %s", type(src))
        return ZItemTiers.RollTier()
    end

    if table.isempty(src) then
        -- No ingredients, use normal spawn probability
        return ZItemTiers.RollTier()
    end

    -- Get crafting skill level
    local skillLevel = nil
    if player then
        skillLevel = (perk and player:getPerkLevel(perk)) or (recipe and recipe:getHighestRelevantSkillLevel(player))
    end
    logger:debug("detected skill level: %s", skillLevel)

    -- Fallback: if recipe method failed, try to manually check common crafting skills
    if not skillLevel or skillLevel == 0 then
        -- No skill level, use normal spawn probability
        return ZItemTiers.RollTier()
    end
    
    -- Collect tiers from all ingredients
    local tierCounts = {}
    local totalIngredients = 0
    
    for _, ingredient in ipairs(src) do
        if ingredient then
            local tier = ZItemTiers.GetItemTierKey(ingredient)
            if tier then
                tierCounts[tier] = (tierCounts[tier] or 0) + 1
                totalIngredients = totalIngredients + 1
            end
        end
    end
    
    if totalIngredients == 0 then
        -- No ingredients with tier, use normal spawn probability
        return ZItemTiers.RollTier()
    end
    
    -- Find the minimum tier index (highest tier) among all ingredients
    -- This is the "floor" - output will be at least this tier
    local minTierIndex = nil
    for tierName, count in pairs(tierCounts) do
        local tierData = ZItemTiers.Tiers[tierName]
        if tierData then
            if minTierIndex == nil or tierData.index > minTierIndex then
                minTierIndex = tierData.index
            end
        end
    end
    
    if not minTierIndex then
        return "Common"
    end
    
    -- Calculate weighted average of ingredient tiers based on count
    local weightedSum = 0
    for tierName, count in pairs(tierCounts) do
        local tierData = ZItemTiers.Tiers[tierName]
        if tierData then
            weightedSum = weightedSum + (tierData.index * count)
        end
    end
    local averageIndex = weightedSum / totalIngredients
    
    -- Round to nearest integer
    local targetIndex = math.floor(averageIndex + 0.5)
    
    -- Ensure output is at least the minimum tier tier (Factorio rule: all Epic -> at least Epic)
    targetIndex = math.max(minTierIndex, targetIndex)
    
    -- Debug: log calculation before skill modifiers
    logger:debug("targetIndex=%d (skillLevel=%d)", targetIndex, skillLevel)
    
    -- Apply skill level modifiers
    if skillLevel == 0 then
        -- Skill level 0: 50% chance to be 1 tier lower
        local roll = ZombRandFloat(0.0, 1.0)
        if roll < 0.5 then
            -- Reduce by 1 tier (but not below Common/1)
            local oldIndex = targetIndex
            targetIndex = math.max(1, targetIndex - 1)
            logger:debug("skill level 0 reduced tier from %d to %d (roll=%.2f)", oldIndex, targetIndex, roll)
        else
            logger:debug("skill level 0 kept tier at %d (roll=%.2f)", targetIndex, roll)
        end
    elseif skillLevel > 1 then
        -- Skill level > 1: Small chance to be 1 tier higher
        -- Chance = 5% per level above 1 (so level 2 = 5%, level 3 = 10%, etc.)
        local upgradeChance = (skillLevel - 1) * 0.05
        local roll = ZombRandFloat(0.0, 1.0)
        
        if roll < upgradeChance then
            -- Upgrade by 1 tier (up to Legendary/5)
            local oldIndex = targetIndex
            targetIndex = math.min(5, targetIndex + 1)
            logger:debug("skill level %d upgraded tier from %d to %d (roll=%.2f, chance=%.3f)", skillLevel, oldIndex, targetIndex, roll, upgradeChance)
        end
    else
        -- Skill level 1: No change (keep calculated tier)
        logger:debug("skill level 1 kept tier at %d (no change)", targetIndex)
    end
    
    -- Clamp to valid tier range (1-5)
    targetIndex = math.max(1, math.min(5, targetIndex))
    
    -- Find tier name by index
    for tierName, tierData in pairs(ZItemTiers.Tiers) do
        if tierData.index == targetIndex then
            return tierName
        end
    end
    
    -- Fallback: return the minimum tier
    for tierName, tierData in pairs(ZItemTiers.Tiers) do
        if tierData.index == minTierIndex then
            return tierName
        end
    end
    
    return "Common"
end

-- capture instanceItem() calls while calling origFun() and apply crafting tier bonuses to crafted items based on src ingredients
-- see CalculateCraftingTier() for tbl parameters description
function ZItemTiers.AutoTierCraftedItems(tbl, origFun, ...)
    return zdk.scoped_hook({
        _G = {
            instanceItem = function(orig, ...)
                local item = orig(...)
                local tier = ZItemTiers.CalculateCraftingTier(tbl)
                if tier then
                    ZItemTiers.ApplyBonuses(item, tier)
                end
                return item
            end
        }
    }, origFun, ...)
end

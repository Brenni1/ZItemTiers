ZItemTiers = ZItemTiers or {}
ZItemTiers.logger = ZItemTiers.logger or ZBLogger.new("ZItemTiers", ZBLogger.DEBUG)
local logger = ZItemTiers.logger

-- Blacklist of items that should never have tier assigned
-- Items in this list will never receive tier bonuses
ZItemTiers.BlacklistedItems = {
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
    ["Base.Padlock"]            = true,
    ["Base.Splinters"]          = true,
    ["Base.UnusableWood"]       = true,
    -- VHS tapes (blacklisted by pattern in IsItemBlacklisted; bonus commented out for now)
}

-- TODO: remove?
-- Initialize global session ID for bonus tracking (initialized once per game session)
if not ZItemTiers._bonusesAppliedSessionId then
    ZItemTiers._bonusesAppliedSessionId = ZombRand(1000000)
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

-- common  uncomm  rare    epic    legendary
-- 0.010   0.015   0.020   0.026   0.031
-- 0.230   0.241   0.252   0.262   0.273
-- 0.500   0.518   0.535   0.552   0.570
-- 0.800   0.825   0.850   0.875   0.900
-- 0.900   0.928   0.955   0.982   1.010
local function affine_scale(base, t0, maxValue)
    if base <= 0 or (maxValue and base >= maxValue) then return base end

    local value = base * (1 + 0.025 * t0) + 0.005*t0
    if maxValue and value > maxValue then
        value = maxValue
    end
    return value
end

local function neg_affine_scale(base, t0, minValue)
    if base <= 0 or (minValue and base <= minValue) then return base end

    local value = base * (1 - 0.025 * t0) - 0.005*t0
    if minValue then
        if value < minValue then value = minValue end
    else
        if value < 0 then value = base end -- XXX maybe cap to last positive value?
    end
    return value
end

local function clamp(_value, _min, _max)
    if not _min then _min = _value end
    if not _max then _max = _value end
    return math.min(math.max(_value, _min), _max)
end

local max = math.max

-- "_ in Lua is like a napkin at dinner: completely ordinary, but everyone silently agrees what it’s for." (c) ChatGPT
local _ = nil

--                                                                                                        rg -iIo '\sBiteDefense\s*=.+' -g "*.txt" | sort | uniq -c | sort -n +3
ZItemTiers.Bonuses = {
    CombatSpeedModifier       = function(base, t0) return clamp(base + 0.01 * t0, _, base < 1 and 1) end,        -- 0.90 .. 0.99
    -- needs java patch, see IsoGameCharacter.updateDiscomfortModifiers() as well
    DiscomfortModifier        = function(base, t0) return clamp(base - 0.05 * t0, 0, _) end,                     -- 0.02 .. 0.75 JAVA
    NeckProtectionModifier    = function(base, t0) return clamp(base + 0.05 * t0, _, 1) end,                     -- 0.30 .. 0.50
    RunSpeedModifier          = function(base, t0) return clamp(base + 0.05 * t0, _, base < 1 and 1) end,        -- 0.70 .. 1.10 JAVA for containers, LUA for Clothing
    HearingModifier           = function(base, t0) return clamp(base + 0.05 * t0, _, 1) end,                     -- 0.50 .. 0.85 JAVA
    VisionModifier            = function(base, t0) return clamp(base + 0.05 * t0, _, 1) end,                     -- 0.25 .. 0.75 JAVA
                                                                                                                 
    Insulation                = function(base, t0) return clamp(base + 0.05 * t0, _, 1) end,                     -- 0.05 .. 1.00
    WaterResistance           = function(base, t0) return clamp(base + 0.05 * t0, _, 1) end,                     -- 0.20 .. 1.00
    Windresistance            = function(base, t0) return clamp(base + 0.05 * t0, _, 1) end,                     -- 0.10 .. 1.00
                                                                                                                 
    BiteDefense               = function(base, t0) return clamp(base + 5 * t0, _, 100) end,                      --    7 .. 100
    BulletDefense             = function(base, t0) return clamp(base + 5 * t0, _, 100) end,                      --    5 .. 100
    CorpseSicknessDefense     = function(base, t0) return clamp(base + 5 * t0, _, 100) end,                      --   25
    ScratchDefense            = function(base, t0) return clamp(base + 5 * t0, _, 100) end,                      --    5 .. 100
                                                                                                                 
    FluidContainer_Capacity   = function(base, t0) return base * (1 + 0.250 * t0) end,                           -- 0.10 .. 600
    Capacity                  = function(base, t0) return base * (1 + 0.125 * t0) end,                           --    1 .. 35
    MaxItemSize               = function(base, t0) return base * (1 + 0.250 * t0) end,                           -- 0.20 .. 2.00
    Weight                    = function(base, t0) return clamp(base * (1 - 0.05 * t0), 0, _) end,               -- 0.001 . 50
    WeightReduction           = function(base, t0) return clamp(base + 5 * t0, 0, max(base, 90)) end,            --   30 .. 90

    UseDelta                  = function(base, t0) return base < 1 and clamp(base * (1 - 0.125 * t0), 0, _) end, -- 0.00001 .. 1.0

    RecoilDelay               = function(base, t0) return clamp(base - t0, 0, _) end,                            -- 11 .. 33
    ReloadTime                = function(base, t0) return clamp(base - 2 * t0, 0, _) end,                        -- 25 .. 30
                                                                                                                
    ConditionLowerChanceOneIn = function(base, t0) return base + t0 end,                                         --  6 .. 8     also partially JAVA?
    ConditionMax              = function(base, t0) return base + t0 end,                                         -- 10 .. 12
                                                                                                                
    ChanceToFall              = function(base, t0) return clamp(base - 5 * t0, 0, _) end,                        --  0 .. 80
                                                                                                                
    JamGunChance              = function(base, t0) return clamp(base - 0.25 * t0, 0, _) end,                     --  0 .. 2
    CriticalChance            = function(base, t0) return base > 0 and clamp(base + 5 * t0, 0, 90) end,          -- 0,  5 .. 70
    HitChance                 = function(base, t0) return base > 0 and clamp(base + 5 * t0, 0, 95) end,          -- 0, 45 .. 70
                                                                                                                
    AimingTimeModifier        = function(base, t0) return base ~= 0 and base - 0.5 * t0 end,                     -- -10  .. 20
    MaxRangeModifier          = function(base, t0) return base ~= 0 and base + 0.2 * t0 end,                     -- -0.8 ..  7
    RecoilDelayModifier       = function(base, t0) return base * (1 + 0.25 * t0) end,                            -- -2
    WeightModifier            = function(base, t0) return base * (1 - 0.05 * t0) end,                            --  0  .. 0.8
                                                                                                                
    TreeDamage                = function(base, t0) return base > 0 and base * (1 + 0.05 * t0) end,               --  1    .. 55
    BaseSpeed                 = function(base, t0) return base - 0.05 * t0 end,                                  --  0.7  ..  1.4
    CritDmgMultiplier         = function(base, t0) return base + 0.5 * t0 end,                                   --  1    .. 12
    MaxDamage                 = function(base, t0) return affine_scale(base, t0, _) end,                         --  0.1  ..  8
    MaxRange                  = function(base, t0) return affine_scale(base, t0, _) end,                         --  0.6  .. 40
    PushBackMod               = function(base, t0) return base > 0 and affine_scale(base, t0, 1.0) end,          --  0    ..  1
    SwingTime                 = function(base, t0) return neg_affine_scale(base, t0, _) end,                     --  0.5  ..  4
    MinimumSwingTime          = function(base, t0) return neg_affine_scale(base, t0, _) end,                     --  0.5  ..  4
    WeaponLength              = function(base, t0) return affine_scale(base, t0, _) end,                         --  0.15 ..  0.7
    StompPower                = function(base, t0) return base * (1 + 0.05 * t0) end,                            --  0.8  .. 2.5
                                                                                                                
    -- AlcoholedCottonBalls/AlcoholWipes                                                                        
    AlcoholPower              = function(base, t0) return base * (1 + 0.125 * t0) end,                           -- 4
    BandagePower              = function(base, t0) return base * (1 + 0.125 * t0) end,                           -- 0.5 .. 4

    FatigueChange             = function(base, t0) return base ~= 0 and base - math.abs(base) * 0.25 * t0 end,   --  -50 ..  -10
    StressChange              = function(base, t0) return base ~= 0 and base - math.abs(base) * 0.25 * t0 end,   --  -20 ..    1
    BoredomChange             = function(base, t0) return base ~= 0 and base - math.abs(base) * 0.25 * t0 end,   --  -50 ..   20
    -- HungChange
    HungerChange              = function(base, t0) return base ~= 0 and base - math.abs(base) * 0.25 * t0 end,   --   -1 .. -160
    ThirstChange              = function(base, t0) return base ~= 0 and base - math.abs(base) * 0.25 * t0 end,   -- -140 ..   60
    UnhappyChange             = function(base, t0) return base ~= 0 and base - math.abs(base) * 0.25 * t0 end,   --  -50 ..  500
                                                                                                                 
    fluReduction              = function(base, t0) return base * (1 + 0.25 * t0) end,                            -- 5
    painReduction             = function(base, t0) return base * (1 + 0.25 * t0) end,                            -- 7
                                                                                                                 
    DaysFresh                 = function(base, t0) return base > 0 and base * (1 + 0.25 * t0) end,               -- 0 .. 365
    DaysTotallyRotten         = function(base, t0) return base > 0 and base * (1 + 0.25 * t0) end,               -- 0 .. 730
}

local SETTER_ALIASES = {
    AimingTimeModifier        = "AimingTime",
    ConditionLowerChanceOneIn = "ConditionLowerChance",
    CritDmgMultiplier         = "CriticalDamageMultiplier",
    HungerChange              = "HungChange",
    MaxRangeModifier          = "MaxRange",
    RecoilDelayModifier       = "RecoilDelay",
}

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
    
    -- Check if item is in the blacklist by full type name
    local fullType = item:getFullType()
    if fullType and ZItemTiers.BlacklistedItems[fullType] then
        return true
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
    if modData and modData.itemRunSpeedModifierBase
        and modData._bonusesApplied == ZItemTiers._bonusesAppliedSessionId then
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
function ZItemTiers.ParseItemScript(item)
    local result = {}
    local scriptItem = item:getScriptItem()
    local lines = scriptItem:getScriptLines()
    for i=0,lines:size()-1 do
        local line = lines:get(i):gsub("[\t ,]", ""):lower()
        local a = line:split("=")
        if a and #a == 2 then
            local num = tonumber(a[2])
            if num then
                result[a[1]] = num
            end
        end
    end
    return result
end

function ZItemTiers.ApplyBonuses(item, forceTier)
    if forceTier then
        ZItemTiers.SetItemTier(item, forceTier)
    end
    local t0 = ZItemTiers.GetItemTierIndex0(item)
    if t0 == 0 then return end -- No bonuses for Common tier

--    logger:debug("Applying tier %d (%s) to %s", t0, ZItemTiers.GetTierNameFromT0(t0), item)
    if t0 <= 0 then
        logger:error("Invalid tier index %d for item %s, skipping bonuses", t0, item)
        return
    end

    local zit = ZItemTiers.GetOrCreateZIT(item)
    zit.bonuses = zit.bonuses or {}

    local itemScriptTbl = ZItemTiers.ParseItemScript(item)
    for key, bonusFunc in pairs(ZItemTiers.Bonuses) do
        local baseValue = itemScriptTbl[key:lower()]
        if baseValue then
            local setter = "set" .. key
            if not item[setter] then
                local alias = SETTER_ALIASES[key]
                if alias then
                    setter = "set" .. alias
                end
            end

            local target = item
            if not target[setter] and key == "FluidContainer_Capacity" and item.getFluidContainer then
                key = "Capacity"
                target = item:getFluidContainer()
            end

            if target and target[setter] then
                local modifiedValue = bonusFunc(baseValue, t0)
                if modifiedValue and modifiedValue ~= baseValue then
                    target[setter](target, modifiedValue)
                    zit.bonuses[key] = {
                        base     = baseValue,
                        modified = modifiedValue,
                    }
                end
            else
                logger:warn("%s: no %s()", item, setter)
            end
        end
    end
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
    if not item then return "Common" end
    
    local zit = ZItemTiers.GetZIT(item)
    return (zit and zit.itemTier) or "Common"
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
        HearingImpairmentReduction = "Hearing Impairment Reduction",
        MoodBonus = "Mood Benefits",
        ReadingSpeedBonus = "Reading Speed",
        VhsSkillXpBonus = "Skill XP Bonus",
    }
    return displayNames[bonusType] or bonusType
end

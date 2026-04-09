ZItemTiers = ZItemTiers or {}

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

-- for the sake of compactness
local _     = nil        -- "_ in Lua is like a napkin at dinner: completely ordinary, but everyone silently agrees what it’s for." (c) ChatGPT
local clamp = zdk.clamp
local max   = math.max

local bonuses = {
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
                                                                                                                 
    FluidCapacity             = {                                                                                -- 0.10 .. 600
        component = ComponentType.FluidContainer,
        getter    = "getCapacity",
        setter    = "setCapacity",
        func      = function(base, t0) return base * (1 + 0.125 * t0) end,
    },

    -- Item also sets ItemCapacity
    Capacity                  = function(base, t0) return base * (1 + 0.125 * t0) end,                           --    1 .. 35
    MaxItemSize               = function(base, t0) return base * (1 + 0.250 * t0) end,                           -- 0.20 .. 2.00
    ActualWeight              = {                                                                                -- 0.001 . 50
        func = function(base, t0) return base * (1 - 0.125 * t0) end,
        hide = true,
    },
    Weight                    = function(base, t0) return base * (1 - 0.125 * t0) end,                           -- 0.001 . 50
    WeightReduction           = function(base, t0) return clamp(base + 5 * t0, 0, max(base, 90)) end,            --   30 .. 90

    UseDelta                  = {                                                                                -- 0.00001 .. 1.0
        func = function(base, t0) return base < 1 and clamp(base * (1 - 0.125 * t0), 0, _) end,
        hide = true,
    },

    RecoilDelay               = function(base, t0) return clamp(base - t0, 0, _) end,                            -- 11 .. 33
    ReloadTime                = function(base, t0) return clamp(base - 2 * t0, 0, _) end,                        -- 25 .. 30
                                                                                                                
    ConditionLowerChanceOneIn = {                                                                                --  6 .. 8     also partially JAVA?
        getter = "getConditionLowerChance",
        setter = "setConditionLowerChance",
        func   = function(base, t0) return base + t0 end,
    },
    -- TODO: setCondition when setting ConditionMax
    ConditionMax              = function(base, t0) return base + t0 end,                                         -- 10 .. 12
                                                                                                                
    ChanceToFall              = function(base, t0) return clamp(base - 5 * t0, 0, _) end,                        --  0 .. 80
                                                                                                                
    JamGunChance              = function(base, t0) return clamp(base - 0.25 * t0, 0, _) end,                     --  0 .. 2
    CriticalChance            = function(base, t0) return base > 0 and clamp(base + 5 * t0, 0, 90) end,          -- 0,  5 .. 70
    HitChance                 = function(base, t0) return base > 0 and clamp(base + 5 * t0, 0, 95) end,          -- 0, 45 .. 70
                                                                                                                
    AimingTimeModifier        = {                                                                                -- -10  .. 20
        getter = "getAimingTime",
        setter = "setAimingTime",
        func   = function(base, t0) return base ~= 0 and base - 0.5 * t0 end,
    },
    MaxRangeModifier          = function(base, t0) return base ~= 0 and base + 0.2 * t0 end,                     -- -0.8 ..  7
    RecoilDelayModifier       = function(base, t0) return base * (1 + 0.25 * t0) end,                            -- -2
    WeightModifier            = function(base, t0) return base * (1 - 0.05 * t0) end,                            --  0  .. 0.8
                                                                                                                
    TreeDamage                = function(base, t0) return base > 0 and base * (1 + 0.05 * t0) end,               --  1    .. 55
    BaseSpeed                 = function(base, t0) return base - 0.05 * t0 end,                                  --  0.7  ..  1.4
    CritDmgMultiplier         = {                                                                                --  1    .. 12
        getter = "getCriticalDamageMultiplier",
        setter = "setCriticalDamageMultiplier",
        func   = function(base, t0) return base + 0.5 * t0 end,
    },
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

    BoredomChange             = function(base, t0) return base ~= 0 and base - math.abs(base) * 0.25 * t0 end,   --  -50 ..   20
    -- Item.java:
    --   item.setFatigueChange(this.fatigueChange / 100.0f);
    --   item.setStressChange(this.stressChange / 100.0f);
    --   food.setThirstChange(this.thirstChange / 100.0f);
    --   food.setHungChange(this.hungerChange / 100.0f);
    --   food.setBaseHunger(this.hungerChange / 100.0f);
    --   food.setEndChange(this.enduranceChange / 100.0f);
    FatigueChange             = function(base, t0) return base ~= 0 and (base - math.abs(base) * 0.25 * t0) / 100 end,   --  -50 ..  -10
    StressChange              = function(base, t0) return base ~= 0 and (base - math.abs(base) * 0.25 * t0) / 100 end,   --  -20 ..    1
    HungerChange              = {                                                                                        --   -1 .. -160
        getter = "getBaseHunger",
        setter = "setBaseHunger",
        func   = function(base, t0) return base ~= 0 and (base - math.abs(base) * 0.25 * t0) / 100 end,
    },
    ThirstChange              = function(base, t0) return base ~= 0 and (base - math.abs(base) * 0.25 * t0) / 100 end,   -- -140 ..   60

    UnhappyChange             = function(base, t0) return base ~= 0 and base - math.abs(base) * 0.25 * t0 end,   --  -50 ..  500
                                                                                                                 
    fluReduction              = function(base, t0) return base * (1 + 0.25 * t0) end,                            -- 5
    painReduction             = function(base, t0) return base * (1 + 0.25 * t0) end,                            -- 7
                                                                                                                 
    DaysFresh                 = function(base, t0) return base > 0 and base * (1 + 0.25 * t0) end,               -- 0 .. 365
    DaysTotallyRotten         = function(base, t0) return base > 0 and base * (1 + 0.25 * t0) end,               -- 0 .. 730
}

local function expand(key)
    local decl = bonuses[key]
    if type(decl) == "function" then
        decl = { func = decl }
    end
    decl.categories = {}
    decl.getter = decl.getter or ("get" .. key)
    decl.setter = decl.setter or ("set" .. key)
    return decl
end

ZItemTiers.Bonuses = ZItemTiers.Bonuses or {}
for key, _ in pairs(bonuses) do
    ZItemTiers.Bonuses[key] = expand(key)
end

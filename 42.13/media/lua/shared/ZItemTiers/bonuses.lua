ZItemTiers = ZItemTiers or {}
local logger = zdk.Logger.new("ZItemTiers")

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

local function ConditionMax_afterSet(self, item, base, modified)
    if item.getCondition and item:getCondition() == base then
        item:setCondition(modified)
    end
end

local function FluidCapacity_afterSet(self, item, base, modified)
    local fluidCont = item:getFluidContainer()
    if fluidCont and fluidCont:getAmount() == base then
        fluidCont:addFluid(fluidCont:getPrimaryFluid(), modified - base)
    end
end

local function HungerChange_afterSet(self, item, base, modified)
    if item.getHungChange and item:getHungChange() == base then
        item:setHungChange(modified)
    end
end

local bonuses = {
    All = {
        ConditionLowerChanceOneIn = { step = 1, altName = "ConditionLowerChance" },
        ConditionMax              = { step = 1, hide = true, afterSet = ConditionMax_afterSet },

        ActualWeight              = { scale = 0.5, hide = true },
        Weight                    = { scale = 0.5 },

        UseDelta                  = { scale = 0.5, hide = true, cond = function(base) return base < 1.0 end },

        FluidCapacity             = { scale = 2.0, component = (ComponentType and ComponentType.FluidContainer), altName = "Capacity", afterSet = FluidCapacity_afterSet },

        AlcoholPower              = { scale = 1.5 },
        BandagePower              = { scale = 1.5 },
        BoredomChange             = { step = -5,                                    tipKey = "literature_Boredom_Reduction" },
        FatigueChange             = { step = -5, div = 100 },
        fluReduction              = { scale = 2.0 },
        HungerChange              = { step = -5, div = 100, altName = "BaseHunger", tipKey = "food_Hunger", afterSet = HungerChange_afterSet },
        painReduction             = { scale = 2.0 },
        StressChange              = { step = -5, div = 100,                         tipKey = "literature_Stress_Reduction" },
        ThirstChange              = { step = -5, div = 100,                         tipKey = "food_Thirst" },
        UnhappyChange             = { step = -5,                                    tipKey = "food_Unhappiness" },
    },

    Clothing = {
        ChanceToFall              = { step = -5, min = 0 },

        CombatSpeedModifier       = { step =  0.01, clamp1 = true },
        DiscomfortModifier        = { step = -0.05 },
        HearingModifier           = { step =  0.05, max = 1 },
        NeckProtectionModifier    = { step =  0.05, max = 1, hide = true },
        RunSpeedModifier          = { step =  0.05, clamp1 = true },
        VisionModifier            = { step =  0.05, max = 1 },

        Insulation                = { step =  0.05, max = 1 },
        WaterResistance           = { step =  0.05, max = 1,                        tipKey = "item_Waterresist" },
        Windresistance            = { step =  0.05, max = 1,                        tipKey = "item_Windresist" },

        BiteDefense               = { step =  5, max = 100 },
        BulletDefense             = { step =  5, max = 100 },
        CorpseSicknessDefense     = { step =  5, max = 100 },
        ScratchDefense            = { step =  5, max = 100 },

        StompPower                = { scale = 1.5 },

        Thermoregulation          = { step = 5, applyIfNull = true, cond = function(_, t0, item) return t0 > 1 and item.getInsulation and item:getInsulation() > 0 end },
    },

    Container = {
        Capacity                  = { scale = 1.5 },
        ItemCapacity              = { scale = 1.5, hide = true },
        MaxItemSize               = { scale = 2.0 },
        WeightReduction           = { step = 5, max = 95 },
    },

    HandWeapon = {
        BaseSpeed                 = { step = 0.05 },
        CritDmgMultiplier         = { step = 0.5, altName = "CriticalDamageMultiplier", hide = true },
        CriticalChance            = { step =  5, max = 90 },
        HitChance                 = { step =  5, max = 99 },
        JamGunChance              = { step = -0.25, min = 0 },
        MaxDamage                 = { affine = true },
        MaxRange                  = { affine = true },
        MinimumSwingTime          = { neg_affine = true, hide = true },
        PushBackMod               = { affine = 1.0, hide = true },
        RecoilDelay               = { step = -1, min = 0, hide = true },
        ReloadTime                = { step = -2, min = 1, hide = true },
        SwingTime                 = { neg_affine = true, hide = true },
        TreeDamage                = { scale = 1.5 },
        WeaponLength              = { affine = true },
    },

    WeaponPart = {
        AimingTimeModifier        = { step = -0.5, min = 0,  altName = "AimingTime" },
        HitChanceModifier         = { step =  5,   max = 99, altName = "HitChance" },
        MaxRangeModifier          = { step =  0.2,           altName = "MaxRange" },
        RecoilDelayModifier       = { step = -0.5, min = 0,  altName = "RecoilDelay" },
        ReloadTimeModifier        = { step = -2,   min = 1,  altName = "ReloadTime" },
        WeightModifier            = { scale = 0.5 },
    },
                                                                                                                 
    Food = {
        DaysFresh                 = { scale = 1.5 },
        DaysTotallyRotten         = { scale = 1.5 },
    },
}

local function bonus_func(self, base, t0, item)
    if self.cond and not self.cond(base, t0, item) then return end
    if self.min and base < self.min then return end
    if self.max and base > self.max then return end

    local result = nil
    if self.step then
        result = base + self.step * t0
    elseif self.scale then
        -- t0 is 0..4 where 0=Common and 4=Legendary.
        -- Interpolate smoothly from base (t0=0) to base*scale (t0=4).
        result = base * (1 + (self.scale - 1) * t0 / 4)
    elseif self.affine then
        local maxValue = (self.affine == true) and nil or self.affine
        result = affine_scale(base, t0, maxValue)
    elseif self.neg_affine then
        local minValue = (self.neg_affine == true) and nil or self.neg_affine
        result = neg_affine_scale(base, t0, minValue)
    else
        logger:error("Invalid bonus declaration: %s", self)
    end

    if self.div then
        result = result / self.div
    end

    if self.clamp1 and base < 1 then
        result = zdk.clamp(result, nil, 1)
    end

    if self.min or self.max then
        result = zdk.clamp(result, self.min, self.max)
    end

    return result
end

local function expand(decl, key)
    decl.getter = decl.altName and ("get" .. decl.altName) or ("get" .. key)
    decl.setter = decl.altName and ("set" .. decl.altName) or ("set" .. key)
    decl.func = bonus_func
    return decl
end

ZItemTiers.Bonuses    = ZItemTiers.Bonuses or {}
ZItemTiers.CatBonuses = ZItemTiers.CatBonuses or {}

for cat, cbonuses in pairs(bonuses) do
    ZItemTiers.CatBonuses[cat] = ZItemTiers.CatBonuses[cat] or {}
    for key, bonus in pairs(cbonuses) do
        local expanded = expand(bonus, key)
        ZItemTiers.Bonuses[key] = expanded
        ZItemTiers.CatBonuses[cat][key] = expanded
    end
end

-- Tests for run speed modifier bonus (ZItemTiers/run_speed.lua)
-- Verifies that Clothing items with run speed modifiers receive correct bonuses per rarity

-- Run speed bonus values per rarity (from core.lua RarityBonuses)
local RUN_SPEED_BONUSES = {
    Uncommon  = 0.1,
    Rare      = 0.2,
    Epic      = 0.3,
    Legendary = 0.4,
}

ZBSpec.describe("ZItemTiers.ApplyRunSpeedModifier - Sneakers", function()
    it("detects base run speed modifier greater than 1.0", function()
        local item = create_clothing("Base.Shoes_Sneakers")
        local base = get_base_run_speed(item)
        assert.greater_than(1.0, base,
            "Sneakers base run speed should be > 1.0, got " .. tostring(base))
    end)

    it("keeps run speed unchanged for Common", function()
        local item = create_clothing("Base.Shoes_Sneakers")
        local base = item:getRunSpeedModifier()
        apply_rarity(item, "Common")
        assert.is_equal(base, item:getRunSpeedModifier())
    end)

    for rarity, bonus in pairs(RUN_SPEED_BONUSES) do
        it("increases run speed by +" .. bonus .. " for " .. rarity, function()
            local item = create_clothing("Base.Shoes_Sneakers")
            local base = get_base_run_speed(item)
            apply_rarity(item, rarity)
            local expected = base + bonus
            local actual = item:getRunSpeedModifier()
            assert.is_true(math.abs(actual - expected) < 0.001,
                rarity .. ": expected " .. expected .. ", got " .. actual)
        end)
    end

    it("stores base run speed in modData", function()
        local item = create_clothing("Base.Shoes_Sneakers")
        local base = get_base_run_speed(item)
        apply_rarity(item, "Epic")
        local modData = item:getModData()
        assert.is_not_nil(modData.itemRunSpeedModifierBase)
        assert.is_true(math.abs(modData.itemRunSpeedModifierBase - base) < 0.001,
            "Stored base should be " .. base .. ", got " .. tostring(modData.itemRunSpeedModifierBase))
    end)

    it("does not compound bonus on re-application", function()
        local item = create_clothing("Base.Shoes_Sneakers")
        apply_rarity(item, "Epic")
        local afterFirst = item:getRunSpeedModifier()
        apply_rarity(item, "Epic")
        local afterSecond = item:getRunSpeedModifier()
        assert.is_true(math.abs(afterFirst - afterSecond) < 0.001,
            "Should not compound: first=" .. afterFirst .. " second=" .. afterSecond)
    end)
end)

ZBSpec.describe("run speed edge cases", function()
    it("does not apply to non-Clothing items", function()
        local item = instanceItem("Base.Axe")
        assert.is_not_nil(item)
        ZItemTiers.ApplyRunSpeedModifier(item, 0.3)
    end)

    it("does not apply to Clothing without run speed modifier", function()
        local item = create_clothing("Base.Vest_DefaultDECAL_PATCH")
        local base = item:getRunSpeedModifier()
        -- base should be 1.0 (neutral) — no bonus should be applied
        apply_rarity(item, "Legendary")
        local after = item:getRunSpeedModifier()
        assert.is_true(math.abs(base - after) < 0.001,
            "Clothing without run speed mod should stay at " .. base .. ", got " .. after)
    end)
end)

return ZBSpec.run()

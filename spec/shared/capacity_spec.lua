-- Tests for capacity bonus (ZItemTiers/capacity_bonus.lua)
-- Verifies that InventoryContainer items receive correct capacity bonuses per tier

-- Container items to test: {fullType, expectedBaseCapacity}
-- Base capacities are verified at runtime from script items
local TEST_CONTAINERS = {
    "Base.Bag_Sling",
    "Base.Bag_NormalHikingBag",
    "Base.Bag_BigHikingBag",
    "Base.Bag_DuffelBag",
}

ZBSpec.describe("ZItemTiers.ApplyCapacityBonus", function()
    for _, fullType in ipairs(TEST_CONTAINERS) do
        describe(fullType, function()
            it("has base capacity greater than 1", function()
                local item = create_container(fullType)
                local base = get_script_capacity(item)
                assert.greater_than(1, base, fullType .. " base capacity should be > 1, got " .. tostring(base))
            end)

            it("keeps capacity unchanged for Common", function()
                local item = create_container(fullType)
                local base = item:getCapacity()
                apply_tier(item, "Common")
                assert.is_equal(base, item:getCapacity())
            end)

            it("increases capacity by 10% for Uncommon", function()
                local item = create_container(fullType)
                local base = get_script_capacity(item)
                apply_tier(item, "Uncommon")
                local expected = math.min(math.floor(base * 1.1 + 0.5), 50)
                assert.is_equal(expected, item:getCapacity(),
                    fullType .. " Uncommon: expected " .. expected .. ", got " .. item:getCapacity())
            end)

            it("increases capacity by 20% for Rare", function()
                local item = create_container(fullType)
                local base = get_script_capacity(item)
                apply_tier(item, "Rare")
                local expected = math.min(math.floor(base * 1.2 + 0.5), 50)
                assert.is_equal(expected, item:getCapacity())
            end)

            it("increases capacity by 30% for Epic", function()
                local item = create_container(fullType)
                local base = get_script_capacity(item)
                apply_tier(item, "Epic")
                local expected = math.min(math.floor(base * 1.3 + 0.5), 50)
                assert.is_equal(expected, item:getCapacity())
            end)

            it("increases capacity by 50% for Legendary", function()
                local item = create_container(fullType)
                local base = get_script_capacity(item)
                apply_tier(item, "Legendary")
                local expected = math.min(math.floor(base * 1.5 + 0.5), 50)
                assert.is_equal(expected, item:getCapacity())
            end)
        end)
    end
end)

ZBSpec.describe("capacity bonus edge cases", function()
    it("does not apply to non-container items", function()
        local item = instanceItem("Base.Axe")
        assert.is_not_nil(item)
        -- Should not error even when called on a non-container
        ZItemTiers.ApplyCapacityBonus(item, 10)
    end)

    it("caps capacity at 50", function()
        local item = create_container("Base.Bag_BigHikingBag")
        local base = get_script_capacity(item)
        -- Apply a huge bonus that would exceed 50
        ZItemTiers.ApplyCapacityBonus(item, 500)
        assert.less_than_or_equal(50, item:getCapacity(),
            "Capacity should be capped at 50, got " .. item:getCapacity())
    end)

    it("stores base capacity in modData for re-application", function()
        local item = create_container("Base.Bag_Sling")
        local base = get_script_capacity(item)
        apply_tier(item, "Uncommon")
        local modData = item:getModData()
        assert.is_not_nil(modData.itemCapacityBase, "itemCapacityBase should be stored in modData")
        assert.is_equal(base, modData.itemCapacityBase)
    end)

    it("does not compound bonus on re-application", function()
        local item = create_container("Base.Bag_Sling")
        local base = get_script_capacity(item)
        apply_tier(item, "Uncommon")
        local afterFirst = item:getCapacity()
        -- Re-apply same tier (simulating save/load)
        apply_tier(item, "Uncommon")
        assert.is_equal(afterFirst, item:getCapacity(),
            "Capacity should not compound: first=" .. afterFirst .. " second=" .. item:getCapacity())
    end)
end)

return ZBSpec.run()

-- Spec helper functions for ItemLootTiers tests

require "ZBSpec"

function get_player()
    if isServer() then
        return getOnlinePlayers():get(0)
    else
        return getPlayer()
    end
end

-- Create an item by full type, with an optional instanceof check
function create_item(fullType, expectedClass)
    local item = instanceItem(fullType)
    assert(item, "Failed to create item: " .. fullType)
    if expectedClass then
        assert(instanceof(item, expectedClass), fullType .. " is not an " .. expectedClass)
    end
    return item
end

-- Convenience wrappers
function create_container(fullType)
    return create_item(fullType, "InventoryContainer")
end

function create_clothing(fullType)
    return create_item(fullType, "Clothing")
end

-- Get the base capacity from script item for a container
function get_script_capacity(item)
    local scriptItem = item:getScriptItem()
    if scriptItem and scriptItem.getCapacity then
        return scriptItem:getCapacity()
    end
    return item:getCapacity()
end

-- Get the base run speed modifier for a clothing item
function get_base_run_speed(item)
    return ZItemTiers.GetBaseRunSpeedModifier(item, item:getModData())
end

-- Apply a tier to an item and return it
function apply_tier(item, tier)
    ZItemTiers.ApplyBonuses(item, tier)
    return item
end

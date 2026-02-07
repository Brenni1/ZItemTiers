-- Spec helper functions for ItemLootTiers tests

require "ZBSpec"

function get_player()
    if isServer() then
        return getOnlinePlayers():get(0)
    else
        return getPlayer()
    end
end

-- Create a container item (InventoryContainer) by full type
function create_container(fullType)
    local item = instanceItem(fullType)
    assert(item, "Failed to create item: " .. fullType)
    assert(instanceof(item, "InventoryContainer"), fullType .. " is not an InventoryContainer")
    return item
end

-- Get the base capacity from script item for a container
function get_script_capacity(item)
    local scriptItem = item:getScriptItem()
    if scriptItem and scriptItem.getCapacity then
        return scriptItem:getCapacity()
    end
    return item:getCapacity()
end

-- Apply a rarity to an item and return it
function apply_rarity(item, rarity)
    ZItemTiers.ApplyRarityBonuses(item, rarity)
    return item
end

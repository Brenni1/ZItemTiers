-- @param invPage ISInventoryPage
local function onRefreshInventoryWindowContainers(invPage, reason)
    if reason ~= "end" then return end

    local items = invPage.inventory:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            ZItemTiers.ApplyBonuses(item)
        end
    end
end

Events.OnRefreshInventoryWindowContainers.Add(onRefreshInventoryWindowContainers)

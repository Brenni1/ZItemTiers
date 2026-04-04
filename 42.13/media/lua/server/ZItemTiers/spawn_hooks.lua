require "ZItemTiers/core"
local logger = ZItemTiers.logger

-- Helper function to apply tier to an item if it doesn't already have one
-- If the item already has tier, re-apply bonuses (useful for migration/fixes)
local function applyTierToItem(item, forceReapply)
    local zit = ZItemTiers.GetOrCreateZIT(item)
    if not zit then return end
    
    local itemType = item:getFullType()
    
    -- Skip items that were crafted with tier (they already have their tier set)
    if zit.craftedFromTier then return end
    
    -- Skip items that might be in the crafting process (check if crafting state exists)
    -- This prevents spawn_hooks from applying Common tier to items that are about to get crafting tier
    if ZItemTiers._craftingState then
        -- Check if any character is currently crafting (items might be created soon)
        local hasActiveCrafting = false
        for characterId, state in pairs(ZItemTiers._craftingState) do
            if state then
                hasActiveCrafting = true
                break
            end
        end
        -- If there's active crafting, skip applying tier to new items (let crafting hook handle it)
        -- Only skip if the item was created very recently (has no tier yet)
        if hasActiveCrafting and not zit.itemTier then
            -- Skip this item temporarily - crafting hook will apply tier within a few ticks
            -- This prevents spawn_hooks from applying Common tier before crafting hook applies Epic/Legendary/etc
            logger:info("[spawn_hooks] Skipping %s - crafting in progress (will be handled by crafting hook)", itemType)
            return
        end
    end
    
    local tier = nil
    
    -- Check if item already has tier
    if zit.itemTier then
        if forceReapply then
            -- Re-apply bonuses for existing items (for migration/fixes)
            tier = zit.itemTier
        else
            -- Item already has tier and we're not forcing re-apply, skip
            return
        end
    else
        -- Item doesn't have tier, roll for it
        tier = ZItemTiers.RollTier()
    end
    if not tier then return end
    
    -- Skip blacklisted items (keys, ID cards, etc.)
    if ZItemTiers.IsItemBlacklisted(item) then return end
    
    ZItemTiers.ApplyBonuses(item, tier)
end

-- Hook into OnFillContainer event to apply tier bonuses when items are spawned
-- Event signature: (roomName, containerType, itemContainer)
-- This fires during world generation when containers are filled
--
-- OnFillContainer( "producestorage", "crate",            ItemContainer:[type:crate, parent:null:carpentry_01_16:carpentry_01_16:zombie.iso.IsoObject@31c97c77] )
-- OnFillContainer( "Container",      "ProduceBox_Large", zombie.inventory.ItemPickerJava$ItemPickerContainer@7e8c9851 )
local function onFillContainer(roomName, containerType, itemContainer)
    if not itemContainer then return end
    if not instanceof(itemContainer, "ItemContainer") then return end
    
    local items = itemContainer.getItems and itemContainer:getItems()
    if not items then return end
    
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            applyTierToItem(item)
        end
    end
end

local function hookFillContainer()
    Events.OnFillContainer.Add(onFillContainer)
end

-- try to apply tiers AFTER all other mods finished their OnFillContainer hooks
Events.OnGameStart.Add(hookFillContainer)
Events.OnServerStarted.Add(hookFillContainer)

-- Helper function to re-apply weight reduction and run speed modifier to items that have tier but lost their bonuses
-- This happens when items are loaded from save (load() resets customWeight to false, run speed modifier might get reset)
-- For HandWeapon items, damage is applied from Lua, weight is handled by Java patch if available
local function reapplyBonusesIfNeeded(item)
    local zit = ZItemTiers.GetOrCreateZIT(item)
    if not zit then return end
end

-- Process world items on a square (items laying on the ground)
local function processSquareWorldItems(square)
    logger:debug("processSquareWorldItems(%s)", square)
    
    local worldObjects = square:getWorldObjects()
    if not worldObjects then return end
    
    for i = 0, worldObjects:size() - 1 do
        local worldObj = worldObjects:get(i)
        if worldObj and worldObj.getItem then
            local item = worldObj:getItem()
            if item then
                local itemTypeStr = item:getFullType() or "unknown"
                applyTierToItem(item, true) -- Force re-apply bonuses (for items loaded from save)
                reapplyBonusesIfNeeded(item)
            end
        end
    end
end

-- Process all items in a container (used when container is accessed)
local function processContainerItems(container)
    if not container then return end
    
    -- Check if container has getItems method
    if not container.getItems then return end
    
    local items = container:getItems()
    if not items then return end
    
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            local itemTypeStr = item:getFullType() or "unknown"
            applyTierToItem(item, true) -- Force re-apply bonuses (for items loaded from save)
            reapplyBonusesIfNeeded(item)
        end
    end
end

-- Hook into OnContainerUpdate to apply tier to items when containers are accessed/updated
-- This catches items when:
-- - Player opens a container (loot window)
-- - Items are added/removed from containers
-- - Items are picked up from ground (added to inventory)
-- - Floor container is accessed (world items on the ground)
-- XXX: gets called only with nil?
local function onContainerUpdate(container)
    if container then
        logger:debug("onContainerUpdate(%s)", container)
    end
--    if not ZItemTiers then return end
--    if not container then return end
--    
--    -- Check if container has getType method
--    if not container.getType then
--        -- If no getType method, try to process items directly (might be a special container)
--        processContainerItems(container)
--        return
--    end
--    
--    -- Check if this is the floor container (world items on the ground)
--    local successGetType, containerType = pcall(function()
--        return container:getType()
--    end)
--    if successGetType and containerType == "floor" then
--        -- For floor container, process world items on all nearby squares
--        -- Get the player to find their current square
--        local player = getPlayer()
--        if player then
--            local square = player:getCurrentSquare()
--            if square then
--                -- Process world items on the player's current square
--                processSquareWorldItems(square)
--                -- Also process adjacent squares (in case items are on nearby squares)
--                for dx = -1, 1 do
--                    for dy = -1, 1 do
--                        if not (dx == 0 and dy == 0) then
--                            local adjSquare = getCell():getGridSquare(square:getX() + dx, square:getY() + dy, square:getZ())
--                            if adjSquare then
--                                processSquareWorldItems(adjSquare)
--                            end
--                        end
--                    end
--                end
--            end
--        end
--    else
--        -- Process all items in the container when it's updated
--        processContainerItems(container)
--    end
end

-- Hook into OnContainerUpdate event
Events.OnContainerUpdate.Add(onContainerUpdate)

-- Hook into ISInventoryPane:refreshContainer to ensure bonuses are applied when inventory is viewed
-- This catches cases where items exist but bonuses weren't applied
-- Also processes world items when loot window is opened
--local originalRefreshContainer = ISInventoryPane.refreshContainer
--if originalRefreshContainer then
--    function ISInventoryPane:refreshContainer(...)
--        local result = originalRefreshContainer(self, ...)
--        
--        -- After refresh, check all items in the container and ensure bonuses are applied
--        if self.inventory then
--            local success, items = pcall(function()
--                if self.inventory.getItems then
--                    return self.inventory:getItems()
--                end
--                return nil
--            end)
--            
--            if success and items then
--                for i = 0, items:size() - 1 do
--                    local item = items:get(i)
--                    if item then
--                        -- Check if item has tier but bonuses might not be applied
--                        local zit = ZItemTiers.GetOrCreateZIT(item)
--                        if zit and zit.itemTier then
--                            -- Force re-apply bonuses to ensure they're all applied
--                            reapplyBonusesIfNeeded(item)
--                        end
--                    end
--                end
--            end
--        end
--        
--        return result
--    end
--end

local function onGameStart()
    -- Process items in player inventory on game start
    local player = getPlayer() -- TODO: MP
    if player then
        local inv = player:getInventory()
        if inv then
            processContainerItems(inv)
        end
    end
end
Events.OnGameStart.Add(onGameStart)

-- most of the item's bonuses are inherited from corresponding ScriptItem, and not saved into savefile,
-- so we need to re-apply them when square is loaded.
-- can happen multiple times per game session even with the same square, if player moves far away and back
-- Events.LoadGridsquare.Add(processSquareWorldItems)

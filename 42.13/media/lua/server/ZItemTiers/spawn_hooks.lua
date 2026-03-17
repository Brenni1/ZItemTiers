-- Item spawning and tier application hooks
-- Hooks into item creation events (OnFillContainer, OnContainerUpdate, OnGameStart)
-- to apply tier-based bonuses when items are spawned or loaded from save

require "ZItemTiers/core"

local function getOrCreateZIT(item)
    if not item or not item.getModData then return nil end
    
    local modData = item:getModData()
    if not modData then return nil end

    if type(modData.ZIT) ~= "table" then
        modData.ZIT = {}
    end

    return modData.ZIT
end

-- Helper function to apply tier to an item if it doesn't already have one
-- If the item already has tier, re-apply bonuses (useful for migration/fixes)
local function applyTierToItem(item, forceReapply)
    local zit = getOrCreateZIT(item)
    if not zit then return end
    
    local itemType = item:getFullType()
    
    -- Skip items that were crafted with tier (they already have their tier set)
    if zit.craftedFromTier then
        if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan")) then
            print("ZItemTiers: [DEBUG] Skipping " .. itemType .. " - craftedFromTier=" .. tostring(zit.craftedFromTier))
        end
        return
    end
    
    -- Skip items that might be in the crafting process (check if crafting state exists)
    -- This prevents spawn_hooks from applying Common tier to items that are about to get crafting tier
    if ZItemTiers and ZItemTiers._craftingState then
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
            print("ZItemTiers: [spawn_hooks] Skipping " .. tostring(itemType) .. " - crafting in progress (will be handled by crafting hook)")
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
    
    ZItemTiers.ApplyTierBonuses(item, tier)
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
    local zit = getOrCreateZIT(item)
    if not zit then return end
    
    if zit.itemTier then
        if instanceof(item, "HandWeapon") then
            -- For HandWeapon items:
            -- - Damage is applied directly from Lua (setMinDamage/setMaxDamage)
            -- - Weight is handled by Java patch if available, otherwise skipped
            -- No need to re-apply anything - damage persists, weight is handled by Java patch
            return
        else
            -- For non-HandWeapon items, check if bonuses need to be re-applied
            local needsReapply = false
            
            -- Check encumbrance reduction (for containers)
            if zit.itemEncumbranceReduction and instanceof(item, "InventoryContainer") then
                local baseValues = zit.baseValues
                local baseEncumbranceReduction = (baseValues and baseValues.encumbranceReductionBase) or (item.getWeightReduction and item:getWeightReduction()) or 0
                local currentEncumbranceReduction = item.getWeightReduction and item:getWeightReduction() or baseEncumbranceReduction
                local expectedValue = math.min(baseEncumbranceReduction + zit.itemEncumbranceReduction, 85)
                if math.abs((currentEncumbranceReduction or baseEncumbranceReduction) - expectedValue) > 0.01 then
                    needsReapply = true
                end
            end
            
            -- Check weight reduction (for non-container items)
            if zit.itemWeightReduction and not instanceof(item, "InventoryContainer") then
                local isCustom = item.isCustomWeight and item:isCustomWeight()
                if not isCustom then
                    needsReapply = true
                end
            end

            -- Check run speed modifier (for all clothing items with run speed modifiers)
            if instanceof(item, "Clothing") then
                -- Get base run speed modifier using shared helper
                local baseRunSpeedMod = ZItemTiers.GetBaseRunSpeedModifier(item, zit)
                
                -- Check if item has a non-default run speed modifier
                if math.abs(baseRunSpeedMod - 1.0) > 0.001 then
                    -- If item has tier but no run speed modifier bonus stored, it needs initial application
                    local tier = zit.itemTier
                    if tier and tier ~= "Common" then
                        local bonuses = ZItemTiers and ZItemTiers.TierBonuses and ZItemTiers.TierBonuses[tier]
                        if bonuses and bonuses.runSpeedModifier and not zit.itemRunSpeedModifierBonus then
                            -- Item has tier but run speed modifier wasn't applied yet
                            needsReapply = true
                        elseif zit.itemRunSpeedModifierBonus then
                            -- Check if run speed modifier needs re-application
                            local currentRunSpeedMod = item.getRunSpeedModifier and item:getRunSpeedModifier() or baseRunSpeedMod
                            local expectedValue = baseRunSpeedMod + zit.itemRunSpeedModifierBonus
                                -- Cap at 1.0 if base was negative
                                if baseRunSpeedMod < 1.0 then
                                    expectedValue = math.min(expectedValue, 1.0)
                                end
                            if math.abs((currentRunSpeedMod or baseRunSpeedMod) - expectedValue) > 0.01 then
                                needsReapply = true
                            end
                        end
                    end
                end
            end

            -- Check bite and scratch defense bonuses
            if instanceof(item, "Clothing") then
                local scriptItem = item.getScriptItem and item:getScriptItem() or nil
                local baseBiteDefense = (scriptItem and scriptItem.biteDefense) or 0
                local baseScratchDefense = (scriptItem and scriptItem.scratchDefense) or 0
                
                local tier = zit.itemTier
                if tier and tier ~= "Common" then
                    local bonuses = ZItemTiers and ZItemTiers.TierBonuses and ZItemTiers.TierBonuses[tier]
                    if bonuses then
                        -- Check if item needs initial defense bonus application (only if item has defense)
                        if (bonuses.biteDefenseBonus and baseBiteDefense > 0 and not zit.itemBiteDefenseBonus) or
                           (bonuses.scratchDefenseBonus and baseScratchDefense > 0 and not zit.itemScratchDefenseBonus) then
                            needsReapply = true
                        end
                    end
                end
                
                -- Check if stored bonuses need re-application (only if item has defense)
                if zit.itemBiteDefenseBonus and baseBiteDefense > 0 then
                    local currentBiteDefense = item.getBiteDefense and item:getBiteDefense() or baseBiteDefense
                    local expectedValue = math.min(baseBiteDefense + zit.itemBiteDefenseBonus, 100)
                    if math.abs((currentBiteDefense or baseBiteDefense) - expectedValue) > 0.01 then
                        needsReapply = true
                    end
                end
                if zit.itemScratchDefenseBonus and baseScratchDefense > 0 then
                    local currentScratchDefense = item.getScratchDefense and item:getScratchDefense() or baseScratchDefense
                    local expectedValue = math.min(baseScratchDefense + zit.itemScratchDefenseBonus, 100)
                    if math.abs((currentScratchDefense or baseScratchDefense) - expectedValue) > 0.01 then
                        needsReapply = true
                    end
                end
            end

            -- Check capacity bonus (for InventoryContainer items)
            if zit.itemCapacityBonus and instanceof(item, "InventoryContainer") then
                    -- Get base capacity: prefer stored base, then script item getter, then instance
                    local baseCapacity = 0
                    if zit.itemCapacityBase and zit.itemCapacityBase > 0 then
                        baseCapacity = zit.itemCapacityBase
                    else
                        local scriptItem = item.getScriptItem and item:getScriptItem() or nil
                        if scriptItem then
                            if scriptItem.getCapacity then
                                baseCapacity = scriptItem:getCapacity()
                            elseif scriptItem.capacity then
                                baseCapacity = scriptItem.capacity
                            end
                        end
                    end

                    local currentCapacity = (item.getCapacity and item:getCapacity()) or baseCapacity
                    if baseCapacity and baseCapacity > 0 then
                        -- Calculate expected capacity using percentage multiplier
                        local capacityMultiplier = 1.0 + (zit.itemCapacityBonus / 100.0)
                        local expectedValue = math.min(math.floor(baseCapacity * capacityMultiplier + 0.5), 50)
                        if math.abs((currentCapacity or baseCapacity) - expectedValue) > 0.01 then
                            needsReapply = true
                        end
                    end
            end

            -- Check max encumbrance bonus (for InventoryContainer items)
            -- Note: This is handled by Java patch at runtime, but we should ensure zit has the bonus stored
            if zit.itemTier and zit.itemTier ~= "Common" and instanceof(item, "InventoryContainer") then
                local maxItemSize = (item.getMaxItemSize and item:getMaxItemSize()) or 0
                if maxItemSize > 0 then
                        -- Check if bonus should be stored but isn't
                        local tier = zit.itemTier
                        local bonuses = ZItemTiers and ZItemTiers.TierBonuses and ZItemTiers.TierBonuses[tier]
                        if bonuses and bonuses.maxEncumbranceBonus and not zit.itemMaxEncumbranceBonus then
                            -- Bonus is missing, needs reapplication
                            needsReapply = true
                            print("ZItemTiers: Max encumbrance bonus missing for " .. tier .. " container, will reapply")
                        end
                end
            end

            -- Check drainable capacity bonus (for Drainable items)
                if zit.itemDrainableCapacityBonus then
                    local fluidContainer = item.getFluidContainer and item:getFluidContainer() or nil
                    if fluidContainer then
                        local baseCapacity = zit.itemDrainableCapacityBase or 0
                        if not zit.itemDrainableCapacityBase and fluidContainer.getCapacity then
                            baseCapacity = fluidContainer:getCapacity() or 0
                        end
                        local currentCapacity = (fluidContainer.getCapacity and fluidContainer:getCapacity()) or baseCapacity
                        if baseCapacity > 0 then
                            -- Calculate expected capacity: base * (1 + bonus percentage / 100)
                            local expectedCapacity = baseCapacity * (1 + zit.itemDrainableCapacityBonus / 100.0)
                            if math.abs((currentCapacity or baseCapacity) - expectedCapacity) > 0.01 then
                                needsReapply = true
                            end
                        end
                    end
                else
                    -- Check if bonus should be stored but isn't (for drainable items with tier)
                    local tier = zit.itemTier
                    if tier and tier ~= "Common" then
                        local bonuses = ZItemTiers and ZItemTiers.TierBonuses and ZItemTiers.TierBonuses[tier]
                        if bonuses and bonuses.drainableCapacityBonus and item.getFluidContainer and item:getFluidContainer() then
                            needsReapply = true
                        end
                    end
                end
            
            if needsReapply then
                local tier = zit.itemTier
                if ZItemTiers and ZItemTiers.ApplyTierBonuses then
                    ZItemTiers.ApplyTierBonuses(item, tier)
                end
            end
        end
    end
end

-- Process world items on a square (items laying on the ground)
local function processSquareWorldItems(square)
    if not square then return end
    
    local worldObjects = square:getWorldObjects()
    if not worldObjects then return end
    
    for i = 0, worldObjects:size() - 1 do
        local worldObj = worldObjects:get(i)
        if worldObj and worldObj.getItem then
            local item = worldObj:getItem()
            if item then
            local itemTypeStr = item:getFullType() or "unknown"
            print("ZItemTiers: [DEBUG] Checking world item: " .. itemTypeStr)
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
            print("ZItemTiers: [DEBUG] Checking item: " .. itemTypeStr)
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
-- Event signature: (container)
--local function onContainerUpdate(container)
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
--end

-- Hook into OnContainerUpdate event
--Events.OnContainerUpdate.Add(onContainerUpdate)

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
--                        local zit = getOrCreateZIT(item)
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
    -- Ensure ZItemTiers is initialized
    if not ZItemTiers then return end
    
    -- Only run once per game session
    if ZItemTiers._migrationRun then return end
    ZItemTiers._migrationRun = true
    
    -- Process items in player inventory on game start
    local player = getPlayer()
    if player then
        local inv = player:getInventory()
        if inv then
            processContainerItems(inv)
        end
        
        -- Also process world items on the player's current square and adjacent squares
        local square = player:getCurrentSquare()
        if square then
            -- Process world items on the player's current square
            processSquareWorldItems(square)
            -- Also process adjacent squares (items might be on nearby squares)
            for dx = -1, 1 do
                for dy = -1, 1 do
                    if not (dx == 0 and dy == 0) then
                        local adjSquare = getCell():getGridSquare(square:getX() + dx, square:getY() + dy, square:getZ())
                        if adjSquare then
                            processSquareWorldItems(adjSquare)
                        end
                    end
                end
            end
        end
    end
end

-- Hook into OnGameStart event for migration
--Events.OnGameStart.Add(onGameStart)

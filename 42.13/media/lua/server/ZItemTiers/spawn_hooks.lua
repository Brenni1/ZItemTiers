-- Item spawning and rarity application hooks
-- Hooks into item creation events (OnFillContainer, OnContainerUpdate, OnGameStart)
-- to apply rarity-based bonuses when items are spawned or loaded from save

require "ZItemTiers/core"

-- Helper function to apply rarity to an item if it doesn't already have one
-- If the item already has rarity, re-apply bonuses (useful for migration/fixes)
local function applyRarityToItem(item, forceReapply)
    if not item or not item.getModData then return end
    
    -- Safely get modData
    local success, modData = pcall(function() return item:getModData() end)
    if not success or not modData then return end
    
    local rarity = nil
    
    -- Check if item already has rarity
    if modData.itemRarity then
        if forceReapply then
            -- Re-apply bonuses for existing items (for migration/fixes)
            rarity = modData.itemRarity
        else
            -- Item already has rarity and we're not forcing re-apply, skip
            return
        end
    else
        -- Item doesn't have rarity, roll for it
        if ZItemTiers and ZItemTiers.RollRarity then
            rarity = ZItemTiers.RollRarity()
        end
    end
    
    -- Skip blacklisted items (keys, ID cards, etc.)
    if ZItemTiers.IsItemBlacklisted(item) then
        return
    end
    
    if rarity then
        -- Apply rarity bonuses to all items (not just items with specific properties)
        if ZItemTiers and ZItemTiers.ApplyRarityBonuses then
            local success13 = pcall(function() 
                ZItemTiers.ApplyRarityBonuses(item, rarity)
            end)
            if not success13 then
                -- Silently fail if bonus application fails
            end
        end
    end
end

-- Hook into OnFillContainer event to apply rarity bonuses when items are spawned
-- Event signature: (roomName, containerType, itemContainer)
-- This fires during world generation when containers are filled
local function onFillContainer(roomName, containerType, itemContainer)
    if not itemContainer then return end
    
    local items = itemContainer:getItems()
    if not items then return end
    
    -- Process all items in the container
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        applyRarityToItem(item)
    end
end

-- Hook into OnFillContainer event
Events.OnFillContainer.Add(onFillContainer)

-- Helper function to re-apply weight reduction to items that have rarity but lost their custom weight
-- This happens when items are loaded from save (load() resets customWeight to false)
-- For HandWeapon items, damage is applied from Lua, weight is handled by Java patch if available
local function reapplyWeightIfNeeded(item)
    if not item or not item.getModData then return end
    
    local success, modData = pcall(function() return item:getModData() end)
    if not success or not modData then return end
    
    if modData.itemRarity then
        -- Check if this is a HandWeapon
        local isHandWeapon = false
        local successWeapon, resultWeapon = pcall(function()
            return instanceof(item, "HandWeapon")
        end)
        if successWeapon and resultWeapon then
            isHandWeapon = true
        end
        
        if isHandWeapon then
            -- For HandWeapon items:
            -- - Damage is applied directly from Lua (setMinDamage/setMaxDamage)
            -- - Weight is handled by Java patch if available, otherwise skipped
            -- No need to re-apply anything - damage persists, weight is handled by Java patch
            return
        elseif modData.itemWeightReduction then
            -- For non-HandWeapon items, check if weight needs to be re-applied
            local needsReapply = false
            local successCheck, isCustom = pcall(function()
                if item.isCustomWeight then
                    return item:isCustomWeight()
                end
                return false
            end)
            if not successCheck or not isCustom then
                needsReapply = true
            end
            
            if needsReapply then
                -- Re-apply weight reduction
                local rarity = modData.itemRarity
                if ZItemTiers and ZItemTiers.ApplyRarityBonuses then
                    pcall(function()
                        ZItemTiers.ApplyRarityBonuses(item, rarity)
                    end)
                end
            end
        end
    end
end

-- Hook into OnContainerUpdate to apply rarity to items added to containers
-- This catches items added via crafting, looting, etc.
-- Event signature: (container)
local function onContainerUpdate(container)
    if not container then return end
    
    local items = container:getItems()
    if not items then return end
    
    -- Process all items in the container
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        applyRarityToItem(item)
        -- Also check if weight needs to be re-applied (for items loaded from save)
        reapplyWeightIfNeeded(item)
    end
end

-- Hook into OnContainerUpdate event
Events.OnContainerUpdate.Add(onContainerUpdate)

-- Optional: Apply rarity to existing items on game start (one-time migration)
-- This ensures items that already existed before the mod was installed get rarity
-- Also re-applies bonuses to items that already have rarity (for fixes/updates)
local function onGameStart()
    -- Only run once per game session
    if ZItemTiers._migrationRun then return end
    ZItemTiers._migrationRun = true
    
    -- Process all items in the world
    local processed = 0
    local reapplied = 0
    local cells = getCell()
    if cells then
        for x = 0, cells:getWidth() - 1 do
            for y = 0, cells:getHeight() - 1 do
                local square = cells:getGridSquare(x, y, 0)
                if square then
                    -- Process items on the ground
                    local worldObjects = square:getWorldObjects()
                    if worldObjects then
                        for i = 0, worldObjects:size() - 1 do
                            local worldObj = worldObjects:get(i)
                            if worldObj and worldObj.getItem() then
                                local item = worldObj.getItem()
                                local hadRarity = false
                                local success, modData = pcall(function() return item:getModData() end)
                                if success and modData and modData.itemRarity then
                                    hadRarity = true
                                end
                                applyRarityToItem(item, true) -- Force re-apply bonuses
                                -- Also re-apply weight if needed (for items loaded from save)
                                reapplyWeightIfNeeded(item)
                                if hadRarity then
                                    reapplied = reapplied + 1
                                else
                                    processed = processed + 1
                                end
                            end
                        end
                    end
                    
                    -- Process items in containers on this square
                    local container = square:getContainer()
                    if container then
                        local items = container:getItems()
                        if items then
                            for j = 0, items:size() - 1 do
                                local item = items:get(j)
                                local hadRarity = false
                                local success, modData = pcall(function() return item:getModData() end)
                                if success and modData and modData.itemRarity then
                                    hadRarity = true
                                end
                                applyRarityToItem(item, true) -- Force re-apply bonuses
                                -- Also re-apply weight if needed (for items loaded from save)
                                reapplyWeightIfNeeded(item)
                                if hadRarity then
                                    reapplied = reapplied + 1
                                else
                                    processed = processed + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
                    -- Process items in player inventory
                    local player = getPlayer()
                    if player then
                        local inv = player:getInventory()
                        if inv then
                            local items = inv:getItems()
                            if items then
                                for i = 0, items:size() - 1 do
                                    local item = items:get(i)
                                    local hadRarity = false
                                    local success, modData = pcall(function() return item:getModData() end)
                                    if success and modData and modData.itemRarity then
                                        hadRarity = true
                                    end
                                    applyRarityToItem(item, true) -- Force re-apply bonuses
                                    -- Also re-apply weight if needed (for items loaded from save)
                                    reapplyWeightIfNeeded(item)
                                    if hadRarity then
                                        reapplied = reapplied + 1
                                    else
                                        processed = processed + 1
                                    end
                                end
                            end
                        end
                    end
    
    if processed > 0 or reapplied > 0 then
        print("ZItemTiers: Applied rarity to " .. processed .. " new items, re-applied bonuses to " .. reapplied .. " existing items")
    end
end

-- Hook into OnGameStart event for migration
Events.OnGameStart.Add(onGameStart)

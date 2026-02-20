-- Item spawning and tier application hooks
-- Hooks into item creation events (OnFillContainer, OnContainerUpdate, OnGameStart)
-- to apply tier-based bonuses when items are spawned or loaded from save

require "ZItemTiers/core"

-- Helper function to apply tier to an item if it doesn't already have one
-- If the item already has tier, re-apply bonuses (useful for migration/fixes)
local function applyTierToItem(item, forceReapply)
    if not item or not item.getModData then return end
    
    local itemType = nil
    local successType, typeValue = pcall(function() return item:getFullType() end)
    if successType and typeValue then
        itemType = typeValue
    end
    
    -- Debug logging for gas cans
    if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan")) then
        print("ZItemTiers: [DEBUG] applyTierToItem called for " .. itemType)
    end
    
    -- Safely get modData
    local success, modData = pcall(function() return item:getModData() end)
    if not success or not modData then 
        if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan")) then
            print("ZItemTiers: [DEBUG] No modData for " .. itemType)
        end
        return 
    end
    
    -- Skip items that were crafted with tier (they already have their tier set)
    if modData.craftedFromTier then
        if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan")) then
            print("ZItemTiers: [DEBUG] Skipping " .. itemType .. " - crafted from tier")
        end
        return
    end
    
    -- Skip VHS items that are being restored from ejection (to prevent overriding restored tier)
    if modData._vhsRestored or modData._vhsRestoring then
        if itemType and string.find(itemType, "VHS") then
            print("ZItemTiers: [VHS] Skipping " .. itemType .. " - VHS being restored from ejection")
        end
        return
    end
    
    -- Check if this is a VHS item for logging
    local isVHS = false
    if itemType and string.find(itemType, "VHS") then
        isVHS = true
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
        if hasActiveCrafting and not modData.itemTier then
            -- Skip this item temporarily - crafting hook will apply tier within a few ticks
            -- This prevents spawn_hooks from applying Common tier before crafting hook applies Epic/Legendary/etc
            print("ZItemTiers: [spawn_hooks] Skipping " .. tostring(itemType) .. " - crafting in progress (will be handled by crafting hook)")
            return
        end
    end
    
    local tier = nil
    
    -- Check if item already has tier
    if modData.itemTier then
        if forceReapply then
            -- Re-apply bonuses for existing items (for migration/fixes)
            tier = modData.itemTier
            if isVHS then
                print("ZItemTiers: [VHS] Re-applying bonuses for " .. itemType .. " (existing tier: " .. tostring(tier) .. ")")
            end
        else
            -- Item already has tier and we're not forcing re-apply, skip
            if isVHS then
                print("ZItemTiers: [VHS] " .. itemType .. " already has tier: " .. tostring(modData.itemTier) .. ", skipping")
            end
            return
        end
    else
        -- Item doesn't have tier, roll for it
        if ZItemTiers and ZItemTiers.RollTier then
            tier = ZItemTiers.RollTier()
            if isVHS then
                print("ZItemTiers: [VHS] Rolled tier for " .. itemType .. ": " .. tostring(tier))
            end
        end
    end
    
    -- Skip blacklisted items (keys, ID cards, etc.)
    if ZItemTiers and ZItemTiers.IsItemBlacklisted and ZItemTiers.IsItemBlacklisted(item) then
        if isVHS then
            print("ZItemTiers: [VHS] " .. itemType .. " is blacklisted, skipping")
        end
        return
    end
    
    if tier then
        -- Apply tier bonuses to all items (not just items with specific properties)
        if ZItemTiers and ZItemTiers.ApplyTierBonuses then
            if isVHS then
                print("ZItemTiers: [VHS] Calling ApplyTierBonuses for " .. itemType .. " with tier " .. tostring(tier))
            end
            local success13 = pcall(function() 
                ZItemTiers.ApplyTierBonuses(item, tier)
            end)
            if not success13 then
                if isVHS then
                    print("ZItemTiers: [VHS] ERROR: ApplyTierBonuses failed for " .. itemType)
                end
            end
        end
    else
        if isVHS then
            print("ZItemTiers: [VHS] No tier for " .. itemType .. ", skipping bonus application")
        end
    end
end

-- Hook into OnFillContainer event to apply tier bonuses when items are spawned
-- Event signature: (roomName, containerType, itemContainer)
-- This fires during world generation when containers are filled
local function onFillContainer(roomName, containerType, itemContainer)
    if not itemContainer then return end
    
    -- Safely get items from container (some container types don't have getItems())
    -- ItemPickerContainer doesn't support getItems(), so we need to catch the error
    local success, items = pcall(function()
        -- Try to call getItems() - will fail for ItemPickerContainer
        return itemContainer:getItems()
    end)
    
    -- If getItems() failed or returned nil, this container type doesn't support it
    if not success or not items then return end
    
    -- Process all items in the container
    local successSize, size = pcall(function()
        if items.size then
            return items:size()
        end
        return 0
    end)
    
    if not successSize or not size or size == 0 then return end
    
    for i = 0, size - 1 do
        local successGet, item = pcall(function()
            if items.get then
                return items:get(i)
            end
            return nil
        end)
        
        if successGet and item then
            applyTierToItem(item)
        end
    end
end

-- Hook into OnFillContainer event
Events.OnFillContainer.Add(onFillContainer)

-- Helper function to re-apply weight reduction and run speed modifier to items that have tier but lost their bonuses
-- This happens when items are loaded from save (load() resets customWeight to false, run speed modifier might get reset)
-- For HandWeapon items, damage is applied from Lua, weight is handled by Java patch if available
local function reapplyBonusesIfNeeded(item)
    if not item or not item.getModData then return end
    
    local success, modData = pcall(function() return item:getModData() end)
    if not success or not modData then return end
    
    if modData.itemTier then
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
        else
            -- For non-HandWeapon items, check if bonuses need to be re-applied
            local needsReapply = false
            
            -- Check encumbrance reduction (for containers)
            if modData.itemEncumbranceReduction then
                local isContainer = false
                local successContainer, resultContainer = pcall(function()
                    return instanceof(item, "InventoryContainer")
                end)
                if successContainer and resultContainer then
                    isContainer = true
                end
                
                if isContainer then
                    -- Get base encumbrance reduction from script item
                    local baseEncumbranceReduction = 0
                    local successGetBase, baseValue = pcall(function()
                        if item.getScriptItem then
                            local scriptItem = item:getScriptItem()
                            if scriptItem and scriptItem.weightReduction then
                                return scriptItem.weightReduction
                            end
                        end
                        return 0
                    end)
                    if successGetBase and baseValue then
                        baseEncumbranceReduction = baseValue
                    end
                    
                    local successGet, currentEncumbranceReduction = pcall(function()
                        if item.getWeightReduction then
                            return item:getWeightReduction()
                        end
                        return baseEncumbranceReduction
                    end)
                    
                    if successGet then
                        -- Calculate expected encumbrance reduction (additive, flat value)
                        local expectedValue = math.min(baseEncumbranceReduction + modData.itemEncumbranceReduction, 85)
                        if math.abs((currentEncumbranceReduction or baseEncumbranceReduction) - expectedValue) > 0.01 then
                            needsReapply = true
                        end
                    end
                end
            end
            
            -- Check weight reduction (for non-container items)
            if modData.itemWeightReduction then
                local isContainer = false
                local successContainer, resultContainer = pcall(function()
                    return instanceof(item, "InventoryContainer")
                end)
                if successContainer and resultContainer then
                    isContainer = true
                end
                
                if not isContainer then
                    -- For regular items, check custom weight flag
                    local successCheck, isCustom = pcall(function()
                        if item.isCustomWeight then
                            return item:isCustomWeight()
                        end
                        return false
                    end)
                    if not successCheck or not isCustom then
                        needsReapply = true
                    end
                end
            end
            
            -- Check run speed modifier (for all clothing items with run speed modifiers)
            -- Also check if item has tier but no run speed modifier bonus stored (needs initial application)
            local isClothing = false
            local successClothing, resultClothing = pcall(function()
                return instanceof(item, "Clothing")
            end)
            if successClothing and resultClothing then
                isClothing = true
            end
            
            if isClothing then
                -- Get base run speed modifier using shared helper
                local baseRunSpeedMod = ZItemTiers.GetBaseRunSpeedModifier(item, modData)
                
                -- Check if item has a non-default run speed modifier
                if math.abs(baseRunSpeedMod - 1.0) > 0.001 then
                    -- If item has tier but no run speed modifier bonus stored, it needs initial application
                    local tier = modData.itemTier
                    if tier and tier ~= "Common" then
                        local bonuses = ZItemTiers and ZItemTiers.TierBonuses and ZItemTiers.TierBonuses[tier]
                        if bonuses and bonuses.runSpeedModifier and not modData.itemRunSpeedModifierBonus then
                            -- Item has tier but run speed modifier wasn't applied yet
                            needsReapply = true
                        elseif modData.itemRunSpeedModifierBonus then
                            -- Check if run speed modifier needs re-application
                            local successGet, currentRunSpeedMod = pcall(function()
                                if item.getRunSpeedModifier then
                                    return item:getRunSpeedModifier()
                                end
                                return baseRunSpeedMod
                            end)
                            
                            if successGet then
                                local expectedValue = baseRunSpeedMod + modData.itemRunSpeedModifierBonus
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
            end
            
            -- Check bite and scratch defense bonuses
            -- Also check if item has tier but no defense bonuses stored (needs initial application)
            local isClothing = false
            local successClothing, resultClothing = pcall(function()
                return instanceof(item, "Clothing")
            end)
            if successClothing and resultClothing then
                isClothing = true
            end
            
            if isClothing then
                -- Get base defense values to check if item has defense
                local baseBiteDefense = 0
                local baseScratchDefense = 0
                local successGetBiteBase, biteBaseValue = pcall(function()
                    if item.getScriptItem then
                        local scriptItem = item:getScriptItem()
                        if scriptItem and scriptItem.biteDefense then
                            return scriptItem.biteDefense
                        end
                    end
                    return 0
                end)
                if successGetBiteBase and biteBaseValue then
                    baseBiteDefense = biteBaseValue
                end
                
                local successGetScratchBase, scratchBaseValue = pcall(function()
                    if item.getScriptItem then
                        local scriptItem = item:getScriptItem()
                        if scriptItem and scriptItem.scratchDefense then
                            return scriptItem.scratchDefense
                        end
                    end
                    return 0
                end)
                if successGetScratchBase and scratchBaseValue then
                    baseScratchDefense = scratchBaseValue
                end
                
                local tier = modData.itemTier
                if tier and tier ~= "Common" then
                    local bonuses = ZItemTiers and ZItemTiers.TierBonuses and ZItemTiers.TierBonuses[tier]
                    if bonuses then
                        -- Check if item needs initial defense bonus application (only if item has defense)
                        if (bonuses.biteDefenseBonus and baseBiteDefense > 0 and not modData.itemBiteDefenseBonus) or
                           (bonuses.scratchDefenseBonus and baseScratchDefense > 0 and not modData.itemScratchDefenseBonus) then
                            needsReapply = true
                        end
                    end
                end
                
                -- Check if stored bonuses need re-application (only if item has defense)
                if modData.itemBiteDefenseBonus and baseBiteDefense > 0 then
                    local successGet, currentBiteDefense = pcall(function()
                        if item.getBiteDefense then
                            return item:getBiteDefense()
                        end
                        return baseBiteDefense
                    end)
                    
                    if successGet then
                        local expectedValue = math.min(baseBiteDefense + modData.itemBiteDefenseBonus, 100)
                        if math.abs((currentBiteDefense or baseBiteDefense) - expectedValue) > 0.01 then
                            needsReapply = true
                        end
                    end
                end
                
                if modData.itemScratchDefenseBonus and baseScratchDefense > 0 then
                    local successGet, currentScratchDefense = pcall(function()
                        if item.getScratchDefense then
                            return item:getScratchDefense()
                        end
                        return baseScratchDefense
                    end)
                    
                    if successGet then
                        local expectedValue = math.min(baseScratchDefense + modData.itemScratchDefenseBonus, 100)
                        if math.abs((currentScratchDefense or baseScratchDefense) - expectedValue) > 0.01 then
                            needsReapply = true
                        end
                    end
                end
            end
            
            -- Check capacity bonus (for InventoryContainer items)
            if modData.itemCapacityBonus then
                local isContainer = false
                local successContainer, resultContainer = pcall(function()
                    return instanceof(item, "InventoryContainer")
                end)
                if successContainer and resultContainer then
                    isContainer = true
                end
                
                if isContainer then
                    -- Get base capacity: prefer stored base, then script item getter, then instance
                    local baseCapacity = 0
                    if modData.itemCapacityBase and modData.itemCapacityBase > 0 then
                        baseCapacity = modData.itemCapacityBase
                    else
                        local successGetBase, baseValue = pcall(function()
                            if item.getScriptItem then
                                local scriptItem = item:getScriptItem()
                                if scriptItem then
                                    if scriptItem.getCapacity then
                                        return scriptItem:getCapacity()
                                    end
                                    if scriptItem.capacity then
                                        return scriptItem.capacity
                                    end
                                end
                            end
                            return 0
                        end)
                        if successGetBase and baseValue and baseValue > 0 then
                            baseCapacity = baseValue
                        end
                    end
                    
                    local successGet, currentCapacity = pcall(function()
                        if item.getCapacity then
                            return item:getCapacity()
                        end
                        return baseCapacity
                    end)
                    
                    if successGet and baseCapacity > 0 then
                        -- Calculate expected capacity using percentage multiplier
                        local capacityMultiplier = 1.0 + (modData.itemCapacityBonus / 100.0)
                        local expectedValue = math.min(math.floor(baseCapacity * capacityMultiplier + 0.5), 50)
                        if math.abs((currentCapacity or baseCapacity) - expectedValue) > 0.01 then
                            needsReapply = true
                        end
                    end
                end
            end
            
            -- Check max encumbrance bonus (for InventoryContainer items)
            -- Note: This is handled by Java patch at runtime, but we should ensure modData has the bonus stored
            if modData.itemTier and modData.itemTier ~= "Common" then
                local isContainer = false
                local successContainer, resultContainer = pcall(function()
                    return instanceof(item, "InventoryContainer")
                end)
                if successContainer and resultContainer then
                    isContainer = true
                end
                
                if isContainer then
                    -- Check if item has a max item size and should have the bonus
                    local successGet, maxItemSize = pcall(function()
                        if item.getMaxItemSize then
                            return item:getMaxItemSize()
                        end
                        return 0
                    end)
                    
                    if successGet and maxItemSize and maxItemSize > 0 then
                        -- Check if bonus should be stored but isn't
                        local tier = modData.itemTier
                        local bonuses = ZItemTiers and ZItemTiers.TierBonuses and ZItemTiers.TierBonuses[tier]
                        if bonuses and bonuses.maxEncumbranceBonus and not modData.itemMaxEncumbranceBonus then
                            -- Bonus is missing, needs reapplication
                            needsReapply = true
                            print("ZItemTiers: Max encumbrance bonus missing for " .. tier .. " container, will reapply")
                        end
                    end
                end
            end
            
                -- Check drainable capacity bonus (for Drainable items)
                if modData.itemDrainableCapacityBonus then
                    local isDrainable = false
                    local successDrainable, resultDrainable = pcall(function()
                        if item.getFluidContainer then
                            local fluidContainer = item:getFluidContainer()
                            return fluidContainer ~= nil
                        end
                        return false
                    end)
                    if successDrainable and resultDrainable then
                        isDrainable = true
                    end
                    
                    if isDrainable then
                        local baseCapacity = modData.itemDrainableCapacityBase or 0
                        if not modData.itemDrainableCapacityBase then
                            local successGetBase, baseValue = pcall(function()
                                if item.getFluidContainer then
                                    local fluidContainer = item:getFluidContainer()
                                    if fluidContainer and fluidContainer.getCapacity then
                                        return fluidContainer:getCapacity()
                                    end
                                end
                                return 0
                            end)
                            if successGetBase and baseValue then
                                baseCapacity = baseValue
                            end
                        end

                        local successGet, currentCapacity = pcall(function()
                            if item.getFluidContainer then
                                local fluidContainer = item:getFluidContainer()
                                if fluidContainer and fluidContainer.getCapacity then
                                    return fluidContainer:getCapacity()
                                end
                            end
                            return baseCapacity
                        end)
                        
                        if successGet and baseCapacity > 0 then
                            -- Calculate expected capacity: base * (1 + bonus percentage / 100)
                            local expectedCapacity = baseCapacity * (1 + modData.itemDrainableCapacityBonus / 100.0)
                            if math.abs((currentCapacity or baseCapacity) - expectedCapacity) > 0.01 then
                                needsReapply = true
                            end
                        end
                    end
                else
                    -- Check if bonus should be stored but isn't (for drainable items with tier)
                    local tier = modData.itemTier
                    if tier and tier ~= "Common" then
                        local bonuses = ZItemTiers and ZItemTiers.TierBonuses and ZItemTiers.TierBonuses[tier]
                        if bonuses and bonuses.drainableCapacityBonus then
                            local isDrainable = false
                            local successDrainable, resultDrainable = pcall(function()
                                if item.getFluidContainer then
                                    local fluidContainer = item:getFluidContainer()
                                    return fluidContainer ~= nil
                                end
                                return false
                            end)
                            if successDrainable and resultDrainable then
                                isDrainable = true
                            end
                            
                            if isDrainable then
                                -- Bonus is missing, needs reapplication
                                needsReapply = true
                            end
                        end
                    end
                end
            
            if needsReapply then
                -- Re-apply all bonuses
                local tier = modData.itemTier
                if ZItemTiers and ZItemTiers.ApplyTierBonuses then
                    pcall(function()
                        ZItemTiers.ApplyTierBonuses(item, tier)
                    end)
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
                local successGetType, itemType = pcall(function()
                    return item:getFullType()
                end)
                local itemTypeStr = successGetType and itemType or "unknown"
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
    
    local successGetItems, items = pcall(function()
        return container:getItems()
    end)
    if not successGetItems or not items then return end
    
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            local successGetType, itemType = pcall(function()
                return item:getFullType()
            end)
            local itemTypeStr = successGetType and itemType or "unknown"
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
local function onContainerUpdate(container)
    if not ZItemTiers then return end
    if not container then return end
    
    -- Check if container has getType method
    if not container.getType then
        -- If no getType method, try to process items directly (might be a special container)
        processContainerItems(container)
        return
    end
    
    -- Check if this is the floor container (world items on the ground)
    local successGetType, containerType = pcall(function()
        return container:getType()
    end)
    if successGetType and containerType == "floor" then
        -- For floor container, process world items on all nearby squares
        -- Get the player to find their current square
        local player = getPlayer()
        if player then
            local square = player:getCurrentSquare()
            if square then
                -- Process world items on the player's current square
                processSquareWorldItems(square)
                -- Also process adjacent squares (in case items are on nearby squares)
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
    else
        -- Process all items in the container when it's updated
        processContainerItems(container)
    end
end

-- Hook into OnContainerUpdate event
Events.OnContainerUpdate.Add(onContainerUpdate)

-- Hook into ISInventoryPane:refreshContainer to ensure bonuses are applied when inventory is viewed
-- This catches cases where items exist but bonuses weren't applied
-- Also processes world items when loot window is opened
local originalRefreshContainer = ISInventoryPane.refreshContainer
if originalRefreshContainer then
    function ISInventoryPane:refreshContainer(...)
        local result = originalRefreshContainer(self, ...)
        
        -- After refresh, check all items in the container and ensure bonuses are applied
        if self.inventory then
            local success, items = pcall(function()
                if self.inventory.getItems then
                    return self.inventory:getItems()
                end
                return nil
            end)
            
            if success and items then
                for i = 0, items:size() - 1 do
                    local item = items:get(i)
                    if item then
                        -- Check if item has tier but bonuses might not be applied
                        local successModData, modData = pcall(function() return item:getModData() end)
                        if successModData and modData and modData.itemTier then
                            -- Force re-apply bonuses to ensure they're all applied
                            reapplyBonusesIfNeeded(item)
                        end
                    end
                end
            end
        end
        
        return result
    end
end


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
Events.OnGameStart.Add(onGameStart)

-- Hook into ISRemoveSheetAction to apply tier to produced sheets
if ISRemoveSheetAction and ISRemoveSheetAction.complete then
    local originalRemoveSheetComplete = ISRemoveSheetAction.complete
    function ISRemoveSheetAction:complete()
        -- Try to get the curtain's tier before removing it
        local curtainTier = nil
        local curtainItem = nil
        
        -- Check if self.item is an IsoCurtain or has curtains
        if self.item then
            if instanceof(self.item, "IsoCurtain") then
                curtainItem = self.item
            elseif instanceof(self.item, "IsoDoor") and self.item.HasCurtains then
                local successGetCurtain, curtain = pcall(function()
                    return self.item:HasCurtains()
                end)
                if successGetCurtain and curtain then
                    curtainItem = curtain
                end
            end
            
            -- Try to get tier from curtain's modData
            if curtainItem and curtainItem.getModData then
                local successGetModData, modData = pcall(function()
                    return curtainItem:getModData()
                end)
                if successGetModData and modData and modData.itemTier then
                    curtainTier = modData.itemTier
                    print("ZItemTiers: [RemoveCurtain] Found curtain tier: " .. curtainTier)
                end
            end
        end
        
        -- Call original complete method
        originalRemoveSheetComplete(self)
        
        -- Use OnTick to check for the sheet after a short delay (item might be added asynchronously)
        local character = self.character
        local storedTier = curtainTier  -- Store for use in OnTick handler
        local checkTicks = 0
        local maxTicks = 3  -- Check for 3 ticks
        Events.OnTick.Add(function()
            checkTicks = checkTicks + 1
            
            if checkTicks > maxTicks then
                return false  -- Remove this event handler
            end
            
            -- Apply tier to the sheet that was just added to inventory
            if character and character.getInventory then
                local successGetInv, inv = pcall(function()
                    return character:getInventory()
                end)
                
                if successGetInv and inv and inv.getItems then
                    local successGetItems, items = pcall(function()
                        return inv:getItems()
                    end)
                    
                    if successGetItems and items then
                        -- Find a sheet without tier
                        for i = 0, items:size() - 1 do
                            local item = items:get(i)
                            if item and not ZItemTiers.IsItemBlacklisted(item) then
                                local itemType = nil
                                local successType, typeValue = pcall(function() return item:getFullType() end)
                                if successType and typeValue then
                                    itemType = typeValue
                                end
                                
                                -- Check if this is a sheet
                                if itemType and (itemType == "Base.Sheet" or string.find(itemType, "Sheet")) then
                                    local modData = item:getModData()
                                    if modData then
                                        local currentTier = modData.itemTier
                                        
                                        -- Apply tier if sheet doesn't have one yet
                                        if not currentTier then
                                            -- Use stored tier from curtain if available, otherwise roll new one
                                            local tier = storedTier or ZItemTiers.RollTier()
                                            modData.itemTier = tier
                                            
                                            -- Apply the tier bonuses
                                            if ZItemTiers and ZItemTiers.ApplyTierBonuses then
                                                ZItemTiers.ApplyTierBonuses(item, tier)
                                            end
                                            
                                            if storedTier then
                                                print("ZItemTiers: [RemoveCurtain] Preserved tier " .. tier .. " from curtain to produced sheet: " .. itemType)
                                            else
                                                print("ZItemTiers: [RemoveCurtain] Applied tier " .. tier .. " to produced sheet: " .. itemType)
                                            end
                                            return false  -- Found and applied, remove handler
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            return true
        end)
    end
    
    print("ZItemTiers: Hooked ISRemoveSheetAction:complete for sheet tier")
end

-- Hook into ISAddSheetAction to preserve sheet tier when creating curtains
if ISAddSheetAction and ISAddSheetAction.complete then
    local originalAddSheetComplete = ISAddSheetAction.complete
    function ISAddSheetAction:complete()
        -- Get the sheet's tier before it's removed from inventory
        local sheetTier = nil
        if self.character and self.character.getInventory then
            local successGetInv, inv = pcall(function()
                return self.character:getInventory()
            end)
            
            if successGetInv and inv and inv.FindAndReturn then
                local successFindSheet, sheet = pcall(function()
                    return inv:FindAndReturn("Sheet")
                end)
                
                if successFindSheet and sheet then
                    local successGetModData, modData = pcall(function()
                        return sheet:getModData()
                    end)
                    if successGetModData and modData and modData.itemTier then
                        sheetTier = modData.itemTier
                        print("ZItemTiers: [AddCurtain] Found sheet tier: " .. sheetTier)
                    end
                end
            end
        end
        
        -- Call original complete method (this will remove the sheet and create the curtain)
        originalAddSheetComplete(self)
        
        -- Apply the sheet's tier to the newly created curtain
        if sheetTier and self.item then
            -- Use OnTick to check for the curtain after a short delay
            local windowItem = self.item
            local storedTier = sheetTier
            local checkTicks = 0
            local maxTicks = 3
            Events.OnTick.Add(function()
                checkTicks = checkTicks + 1
                
                if checkTicks > maxTicks then
                    return false  -- Remove this event handler
                end
                
                -- Find the curtain that was just created
                if windowItem and windowItem.getSquare then
                    local successGetSquare, square = pcall(function()
                        return windowItem:getSquare()
                    end)
                    
                    if successGetSquare and square then
                        -- Check for curtains on this square and adjacent squares
                        local squaresToCheck = {square}
                        if windowItem.north then
                            local adjSquare = getCell():getGridSquare(square:getX(), square:getY() - 1, square:getZ())
                            if adjSquare then table.insert(squaresToCheck, adjSquare) end
                        else
                            local adjSquare = getCell():getGridSquare(square:getX() - 1, square:getY(), square:getZ())
                            if adjSquare then table.insert(squaresToCheck, adjSquare) end
                        end
                        
                        for _, sq in ipairs(squaresToCheck) do
                            if sq and sq.getSpecialObjects then
                                local successGetObjects, objects = pcall(function()
                                    return sq:getSpecialObjects()
                                end)
                                
                                if successGetObjects and objects then
                                    for i = 0, objects:size() - 1 do
                                        local obj = objects:get(i)
                                        if obj and instanceof(obj, "IsoCurtain") then
                                            local successGetModData, modData = pcall(function()
                                                return obj:getModData()
                                            end)
                                            if successGetModData and modData then
                                                local currentTier = modData.itemTier
                                                
                                                -- Apply tier if curtain doesn't have one yet
                                                if not currentTier then
                                                    modData.itemTier = storedTier
                                                    print("ZItemTiers: [AddCurtain] Preserved tier " .. storedTier .. " from sheet to curtain")
                                                    return false  -- Found and applied, remove handler
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                return true
            end)
        end
    end
    
    print("ZItemTiers: Hooked ISAddSheetAction:complete for curtain tier")
end

-- Item spawning and rarity application hooks
-- Hooks into item creation events (OnFillContainer, OnContainerUpdate, OnGameStart)
-- to apply rarity-based bonuses when items are spawned or loaded from save

require "ZItemTiers/core"

-- Helper function to apply rarity to an item if it doesn't already have one
-- If the item already has rarity, re-apply bonuses (useful for migration/fixes)
local function applyRarityToItem(item, forceReapply)
    if not item or not item.getModData then return end
    
    local itemType = nil
    local successType, typeValue = pcall(function() return item:getFullType() end)
    if successType and typeValue then
        itemType = typeValue
    end
    
    -- Debug logging for gas cans
    if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan")) then
        print("ZItemTiers: [DEBUG] applyRarityToItem called for " .. itemType)
    end
    
    -- Safely get modData
    local success, modData = pcall(function() return item:getModData() end)
    if not success or not modData then 
        if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan")) then
            print("ZItemTiers: [DEBUG] No modData for " .. itemType)
        end
        return 
    end
    
    -- Skip items that were crafted with rarity (they already have their rarity set)
    if modData.craftedFromRarity then
        if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan")) then
            print("ZItemTiers: [DEBUG] Skipping " .. itemType .. " - crafted from rarity")
        end
        return
    end
    
    -- Skip items that might be in the crafting process (check if crafting state exists)
    -- This prevents spawn_hooks from applying Common rarity to items that are about to get crafting rarity
    if ZItemTiers and ZItemTiers._craftingState then
        -- Check if any character is currently crafting (items might be created soon)
        local hasActiveCrafting = false
        for characterId, state in pairs(ZItemTiers._craftingState) do
            if state then
                hasActiveCrafting = true
                break
            end
        end
        -- If there's active crafting, skip applying rarity to new items (let crafting hook handle it)
        -- Only skip if the item was created very recently (has no rarity yet)
        if hasActiveCrafting and not modData.itemRarity then
            -- Skip this item temporarily - crafting hook will apply rarity within a few ticks
            -- This prevents spawn_hooks from applying Common rarity before crafting hook applies Epic/Legendary/etc
            if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan")) then
                print("ZItemTiers: [DEBUG] Skipping " .. itemType .. " - crafting in progress")
            end
            return
        end
    end
    
    local rarity = nil
    
    -- Check if item already has rarity
    if modData.itemRarity then
        if forceReapply then
            -- Re-apply bonuses for existing items (for migration/fixes)
            rarity = modData.itemRarity
        else
            -- Item already has rarity and we're not forcing re-apply, skip
            if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan")) then
                print("ZItemTiers: [DEBUG] " .. itemType .. " already has rarity: " .. tostring(modData.itemRarity) .. ", skipping")
            end
            return
        end
    else
        -- Item doesn't have rarity, roll for it
        if ZItemTiers and ZItemTiers.RollRarity then
            rarity = ZItemTiers.RollRarity()
            if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan")) then
                print("ZItemTiers: [DEBUG] Rolled rarity for " .. itemType .. ": " .. tostring(rarity))
            end
        end
    end
    
    -- Skip blacklisted items (keys, ID cards, etc.)
    if ZItemTiers and ZItemTiers.IsItemBlacklisted and ZItemTiers.IsItemBlacklisted(item) then
        if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan")) then
            print("ZItemTiers: [DEBUG] " .. itemType .. " is blacklisted, skipping")
        end
        return
    end
    
    if rarity then
        -- Apply rarity bonuses to all items (not just items with specific properties)
        if ZItemTiers and ZItemTiers.ApplyRarityBonuses then
            if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan")) then
                print("ZItemTiers: [DEBUG] Calling ApplyRarityBonuses for " .. itemType .. " with rarity " .. tostring(rarity))
            end
            local success13 = pcall(function() 
                ZItemTiers.ApplyRarityBonuses(item, rarity)
            end)
            if not success13 then
                if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan")) then
                    print("ZItemTiers: [DEBUG] ERROR: ApplyRarityBonuses failed for " .. itemType)
                end
            end
        end
    else
        if itemType and (string.find(itemType, "PetrolCan") or string.find(itemType, "GasCan")) then
            print("ZItemTiers: [DEBUG] No rarity for " .. itemType .. ", skipping bonus application")
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

-- Helper function to re-apply weight reduction and run speed modifier to items that have rarity but lost their bonuses
-- This happens when items are loaded from save (load() resets customWeight to false, run speed modifier might get reset)
-- For HandWeapon items, damage is applied from Lua, weight is handled by Java patch if available
local function reapplyBonusesIfNeeded(item)
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
            -- Also check if item has rarity but no run speed modifier bonus stored (needs initial application)
            local isClothing = false
            local successClothing, resultClothing = pcall(function()
                return instanceof(item, "Clothing")
            end)
            if successClothing and resultClothing then
                isClothing = true
            end
            
            if isClothing then
                -- Get base run speed modifier
                local baseRunSpeedMod = modData.itemRunSpeedModifierBase or 1.0
                if not modData.itemRunSpeedModifierBase then
                    -- Try to get from script item
                    local successGetBase, baseValue = pcall(function()
                        if item.getScriptItem then
                            local scriptItem = item:getScriptItem()
                            if scriptItem and scriptItem.runSpeedModifier then
                                return scriptItem.runSpeedModifier
                            end
                        end
                        return 1.0
                    end)
                    if successGetBase and baseValue then
                        baseRunSpeedMod = baseValue
                        -- Store it for future checks
                        modData.itemRunSpeedModifierBase = baseValue
                    end
                end
                
                -- Check if item has a non-default run speed modifier
                if math.abs(baseRunSpeedMod - 1.0) > 0.001 then
                    -- If item has rarity but no run speed modifier bonus stored, it needs initial application
                    local rarity = modData.itemRarity
                    if rarity and rarity ~= "Common" then
                        local bonuses = ZItemTiers and ZItemTiers.RarityBonuses and ZItemTiers.RarityBonuses[rarity]
                        if bonuses and bonuses.runSpeedModifier and not modData.itemRunSpeedModifierBonus then
                            -- Item has rarity but run speed modifier wasn't applied yet
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
            -- Also check if item has rarity but no defense bonuses stored (needs initial application)
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
                
                local rarity = modData.itemRarity
                if rarity and rarity ~= "Common" then
                    local bonuses = ZItemTiers and ZItemTiers.RarityBonuses and ZItemTiers.RarityBonuses[rarity]
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
                    -- Get base capacity from script item
                    local baseCapacity = 0
                    local successGetBase, baseValue = pcall(function()
                        if item.getScriptItem then
                            local scriptItem = item:getScriptItem()
                            if scriptItem and scriptItem.capacity then
                                return scriptItem.capacity
                            end
                        end
                        return 0
                    end)
                    if successGetBase and baseValue then
                        baseCapacity = baseValue
                    end
                    
                    local successGet, currentCapacity = pcall(function()
                        if item.getCapacity then
                            return item:getCapacity()
                        end
                        return baseCapacity
                    end)
                    
                    if successGet then
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
            if modData.itemRarity and modData.itemRarity ~= "Common" then
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
                        local rarity = modData.itemRarity
                        local bonuses = ZItemTiers and ZItemTiers.RarityBonuses and ZItemTiers.RarityBonuses[rarity]
                        if bonuses and bonuses.maxEncumbranceBonus and not modData.itemMaxEncumbranceBonus then
                            -- Bonus is missing, needs reapplication
                            needsReapply = true
                            print("ZItemTiers: Max encumbrance bonus missing for " .. rarity .. " container, will reapply")
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
                    -- Check if bonus should be stored but isn't (for drainable items with rarity)
                    local rarity = modData.itemRarity
                    if rarity and rarity ~= "Common" then
                        local bonuses = ZItemTiers and ZItemTiers.RarityBonuses and ZItemTiers.RarityBonuses[rarity]
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
    
    -- Safely check if container has getItems method
    local success, items = pcall(function()
        if container.getItems then
            return container:getItems()
        end
        return nil
    end)
    
    if not success or not items then return end
    
    -- Process all items in the container
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        applyRarityToItem(item)
        -- Also check if bonuses need to be re-applied (for items loaded from save)
        reapplyBonusesIfNeeded(item)
    end
end

-- Hook into OnContainerUpdate event
Events.OnContainerUpdate.Add(onContainerUpdate)

-- Hook into ISInventoryPane:refreshContainer to ensure bonuses are applied when inventory is viewed
-- This catches cases where items exist but bonuses weren't applied
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
                        -- Check if item has rarity but bonuses might not be applied
                        local successModData, modData = pcall(function() return item:getModData() end)
                        if successModData and modData and modData.itemRarity then
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

-- Optional: Apply rarity to existing items on game start (one-time migration)
-- This ensures items that already existed before the mod was installed get rarity
-- Also re-applies bonuses to items that already have rarity (for fixes/updates)
local function onGameStart()
    -- Ensure ZItemTiers is initialized
    if not ZItemTiers then return end
    
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
                                reapplyBonusesIfNeeded(item)
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
                                reapplyBonusesIfNeeded(item)
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
                                    reapplyBonusesIfNeeded(item)
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

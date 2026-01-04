-- Crafting rarity system
-- Implements Factorio-style crafting where output rarity is based on ingredient rarities
-- If all ingredients are Epic, output is at least Epic
-- If ingredients have different rarities, output rarity is based on their ratio/probability

require "ZItemTiers/core"

-- Ensure ZItemTiers is initialized as a table
ZItemTiers = ZItemTiers or {}

-- Calculate output rarity based on ingredient rarities (Factorio-style)
-- Returns the calculated rarity name
-- Parameters:
--   ingredientItems: ArrayList of ingredient items
--   character: (optional) IsoGameCharacter performing the craft
--   recipe: (optional) CraftRecipe being performed
-- Rules:
-- 1. If all ingredients are Epic, output is at least Epic
-- 2. If ingredients have different rarities, output rarity is based on their ratio/probability
-- 3. Output is always at least the minimum (highest tier) rarity among ingredients
-- 4. Skill level affects the result:
--    - Level 0: 50% chance to be 1 tier lower
--    - Level 1: Keep calculated tier (no change)
--    - Level > 1: Small chance (5% per level above 1) to be 1 tier higher
function ZItemTiers.CalculateCraftingRarity(ingredientItems, character, recipe)
    if not ingredientItems or ingredientItems:size() == 0 then
        -- No ingredients, use normal spawn probability
        return ZItemTiers.RollRarity()
    end
    
    -- Get crafting skill level
    local skillLevel = 0
    if character and recipe then
        local success, level = pcall(function()
            if recipe.getHighestRelevantSkillLevel then
                return recipe:getHighestRelevantSkillLevel(character)
            end
            return 0
        end)
        if success and level then
            skillLevel = level
        end
    end
    
    -- Collect rarities from all ingredients
    local rarityCounts = {}
    local totalIngredients = 0
    
    for i = 0, ingredientItems:size() - 1 do
        local ingredient = ingredientItems:get(i)
        if ingredient then
            local rarity = ZItemTiers.GetItemRarity(ingredient)
            if rarity then
                rarityCounts[rarity] = (rarityCounts[rarity] or 0) + 1
                totalIngredients = totalIngredients + 1
            end
        end
    end
    
    if totalIngredients == 0 then
        -- No ingredients with rarity, use normal spawn probability
        return ZItemTiers.RollRarity()
    end
    
    -- Find the minimum rarity index (highest tier) among all ingredients
    -- This is the "floor" - output will be at least this tier
    local minRarityIndex = nil
    for rarityName, count in pairs(rarityCounts) do
        local rarityData = ZItemTiers.Rarities[rarityName]
        if rarityData then
            if minRarityIndex == nil or rarityData.index > minRarityIndex then
                minRarityIndex = rarityData.index
            end
        end
    end
    
    if not minRarityIndex then
        return "Common"
    end
    
    -- Calculate weighted average of ingredient rarities based on count
    local weightedSum = 0
    for rarityName, count in pairs(rarityCounts) do
        local rarityData = ZItemTiers.Rarities[rarityName]
        if rarityData then
            weightedSum = weightedSum + (rarityData.index * count)
        end
    end
    local averageIndex = weightedSum / totalIngredients
    
    -- Round to nearest integer
    local targetIndex = math.floor(averageIndex + 0.5)
    
    -- Ensure output is at least the minimum rarity tier (Factorio rule: all Epic -> at least Epic)
    targetIndex = math.max(minRarityIndex, targetIndex)
    
    -- Apply skill level modifiers
    if skillLevel == 0 then
        -- Skill level 0: 50% chance to be 1 tier lower
        local roll = ZombRand(10000) / 10000.0  -- Random 0.0 to 1.0
        if roll < 0.5 then
            -- Reduce by 1 tier (but not below Common/1)
            targetIndex = math.max(1, targetIndex - 1)
            print("ZItemTiers: [Crafting] Skill level 0 reduced tier from " .. (targetIndex + 1) .. " to " .. targetIndex)
        end
    elseif skillLevel > 1 then
        -- Skill level > 1: Small chance to be 1 tier higher
        -- Chance = 5% per level above 1 (so level 2 = 5%, level 3 = 10%, etc.)
        local upgradeChance = (skillLevel - 1) * 0.05
        local roll = ZombRand(10000) / 10000.0  -- Random 0.0 to 1.0
        
        if roll < upgradeChance then
            -- Upgrade by 1 tier (up to Legendary/5)
            local oldIndex = targetIndex
            targetIndex = math.min(5, targetIndex + 1)
            print("ZItemTiers: [Crafting] Skill level " .. skillLevel .. " upgraded tier from " .. oldIndex .. " to " .. targetIndex)
        end
    end
    -- Skill level 1: No change (keep calculated tier)
    
    -- Clamp to valid rarity range (1-5)
    targetIndex = math.max(1, math.min(5, targetIndex))
    
    -- Find rarity name by index
    for rarityName, rarityData in pairs(ZItemTiers.Rarities) do
        if rarityData.index == targetIndex then
            return rarityName
        end
    end
    
    -- Fallback: return the minimum rarity
    for rarityName, rarityData in pairs(ZItemTiers.Rarities) do
        if rarityData.index == minRarityIndex then
            return rarityName
        end
    end
    
    return "Common"
end

-- Hook into RecipeManager.PerformMakeItem to apply crafting rarity
-- We need to intercept the ItemRecipe creation to get the actual source items that will be consumed
local originalPerformMakeItem = RecipeManager.PerformMakeItem
RecipeManager.PerformMakeItem = function(recipe, item, character, containers)
    -- Create a temporary ItemRecipe to get the source items that will actually be consumed
    -- This matches what PerformMakeItem does internally
    local sourceItems = nil
    local successGet = pcall(function()
        if recipe and RecipeManager then
            -- Use the same approach as PerformMakeItem - create ItemRecipe to get source items
            -- We need to use ItemRecipe.Alloc to get the actual items that will be consumed
            if ItemRecipe and ItemRecipe.Alloc then
                local tempItemRecipe = ItemRecipe.Alloc(recipe, character, containers, item, nil, false)
                if tempItemRecipe then
                    -- Get source items before perform() is called
                    sourceItems = tempItemRecipe:getSourceItems()
                    -- Release the ItemRecipe (we don't want to actually perform it yet)
                    ItemRecipe.Release(tempItemRecipe)
                end
            end
            
            -- Fallback: try getAvailableItemsNeeded if ItemRecipe.Alloc doesn't work
            if (not sourceItems or sourceItems:size() == 0) and RecipeManager.getAvailableItemsNeeded then
                sourceItems = RecipeManager.getAvailableItemsNeeded(recipe, character, containers, item, nil)
            end
        end
    end)
    
    -- Store crafting state BEFORE performing recipe (for Actions.addOrDropItem hook)
    local characterId = nil
    if character then
        local successId, id = pcall(function() 
            if character.getOnlineID then
                return character:getOnlineID()
            end
            return nil
        end)
        if successId and id then
            characterId = id
        end
    end
    
    -- Calculate output rarity BEFORE performing recipe (so we can store it in crafting state)
    local outputRarity = nil
    if successGet and sourceItems and sourceItems:size() > 0 then
        outputRarity = ZItemTiers.CalculateCraftingRarity(sourceItems, character, recipe)
        
        -- Debug: log source items and their rarities
        local debugMsg = "ZItemTiers: [PerformMakeItem] Crafting with " .. sourceItems:size() .. " ingredients: "
        for i = 0, sourceItems:size() - 1 do
            local ing = sourceItems:get(i)
            if ing then
                local rarity = ZItemTiers.GetItemRarity(ing)
                local fullType = ing:getFullType()
                debugMsg = debugMsg .. fullType .. "(" .. rarity .. ") "
            end
        end
        print(debugMsg)
        print("ZItemTiers: [PerformMakeItem] Calculated output rarity: " .. outputRarity)
        
        -- Store crafting state for Actions.addOrDropItem hook
        if characterId then
            _craftingState[characterId] = {
                rarity = outputRarity,
                timestamp = getGameTime():getWorldAgeHours() or 0,
                character = character
            }
            print("ZItemTiers: [PerformMakeItem] Stored crafting state for character " .. characterId .. " with rarity " .. outputRarity)
        end
    end
    
    -- Perform the recipe (consumes items, creates outputs)
    local result = originalPerformMakeItem(recipe, item, character, containers)
    
    -- Apply rarity to created items if we got source items
    -- Note: Some items might be added via Actions.addOrDropItem (which will handle them),
    -- but items returned directly by PerformMakeItem should also be handled here
    if result and result:size() > 0 and outputRarity then
        print("ZItemTiers: [PerformMakeItem] Applying rarity to " .. result:size() .. " created items")
        
        -- Apply rarity to all created items
        for i = 0, result:size() - 1 do
            local createdItem = result:get(i)
            if createdItem and not ZItemTiers.IsItemBlacklisted(createdItem) then
                -- Store rarity in modData FIRST to prevent spawn_hooks from overriding it
                local modData = createdItem:getModData()
                if modData then
                    modData.itemRarity = outputRarity
                    modData.craftedFromRarity = true  -- Flag to indicate this was crafted
                end
                
                -- Apply the calculated rarity
                ZItemTiers.ApplyRarityBonuses(createdItem, outputRarity)
                
                -- Verify rarity was applied
                local verifyRarity = ZItemTiers.GetItemRarity(createdItem)
                print("ZItemTiers: [PerformMakeItem] Applied rarity " .. outputRarity .. " to crafted item: " .. createdItem:getFullType() .. " (verified: " .. verifyRarity .. ")")
            end
        end
        
        -- Clean up crafting state after items are created
        if characterId and _craftingState[characterId] then
            _craftingState[characterId] = nil
            print("ZItemTiers: [PerformMakeItem] Cleaned up crafting state for character " .. characterId)
        end
    else
        if result and result:size() > 0 then
            print("ZItemTiers: [PerformMakeItem] WARNING: Could not get source items for crafting. successGet=" .. tostring(successGet) .. ", sourceItems=" .. tostring(sourceItems) .. ", size=" .. (sourceItems and sourceItems:size() or "nil"))
        end
        -- Clean up crafting state if we couldn't calculate rarity
        if characterId and _craftingState[characterId] then
            _craftingState[characterId] = nil
        end
    end
    
    return result
end

-- Track crafting state to catch items created in OnCreate callbacks (like ripClothing)
-- Maps character ID to crafting state (rarity, timestamp)
-- Expose through ZItemTiers so spawn_hooks can check if crafting is in progress
ZItemTiers._craftingState = ZItemTiers._craftingState or {}
local _craftingState = ZItemTiers._craftingState

-- Hook into ISHandcraftAction:performRecipe to store crafting state before items are added
-- This is needed because ISHandcraftAction calls Actions.addOrDropItem directly
if ISHandcraftAction and ISHandcraftAction.performRecipe then
    local originalHandcraftPerformRecipe = ISHandcraftAction.performRecipe
    function ISHandcraftAction:performRecipe()
        -- Get consumed items BEFORE performing the recipe
        local consumedItems = nil
        if self.logic then
            local successGet, recipeData = pcall(function()
                if self.logic and self.logic.getRecipeData then
                    return self.logic:getRecipeData()
                end
                return nil
            end)
            
            if successGet and recipeData and recipeData.getAllConsumedItems then
                consumedItems = ArrayList.new()
                recipeData:getAllConsumedItems(consumedItems, false)
            end
        end
        
        -- Store crafting state BEFORE performing (for Actions.addOrDropItem hook)
        local character = self.character
        local characterId = nil
        if character then
            local successId, id = pcall(function() 
                if character.getOnlineID then
                    return character:getOnlineID()
                end
                return nil
            end)
            if successId and id then
                characterId = id
            end
        end
        
        -- Calculate output rarity BEFORE performing recipe
        if characterId and consumedItems and consumedItems:size() > 0 then
            -- Get recipe from logic for skill level calculation
            local recipe = nil
            if self.logic then
                local successGetRecipe, recipeData = pcall(function()
                    if self.logic and self.logic.getRecipeData then
                        return self.logic:getRecipeData()
                    end
                    return nil
                end)
                if successGetRecipe and recipeData and recipeData.getRecipe then
                    recipe = recipeData:getRecipe()
                end
            end
            
            local outputRarity = ZItemTiers.CalculateCraftingRarity(consumedItems, character, recipe)
            
            -- Debug: log consumed items
            local debugMsg = "ZItemTiers: [ISHandcraftAction] Crafting with " .. consumedItems:size() .. " ingredients: "
            for i = 0, consumedItems:size() - 1 do
                local ing = consumedItems:get(i)
                if ing then
                    local rarity = ZItemTiers.GetItemRarity(ing)
                    local fullType = ing:getFullType()
                    debugMsg = debugMsg .. fullType .. "(" .. rarity .. ") "
                end
            end
            print(debugMsg)
            print("ZItemTiers: [ISHandcraftAction] Calculated output rarity: " .. outputRarity)
            
            -- Store crafting state for Actions.addOrDropItem hook
            _craftingState[characterId] = {
                rarity = outputRarity,
                timestamp = getGameTime():getWorldAgeHours() or 0,
                character = character
            }
            print("ZItemTiers: [ISHandcraftAction] Stored crafting state for character " .. characterId .. " with rarity " .. outputRarity)
        end
        
        -- Perform the original recipe (this will call Actions.addOrDropItem)
        local result = originalHandcraftPerformRecipe(self)
        
        -- Clean up crafting state after a short delay (to allow Actions.addOrDropItem to process items)
        if characterId and _craftingState[characterId] then
            local cleanupCharacterId = characterId
            local cleanupTicks = 0
            Events.OnTick.Add(function()
                cleanupTicks = cleanupTicks + 1
                -- Clean up after 3 ticks to allow all items to be processed
                if cleanupTicks >= 3 then
                    if _craftingState[cleanupCharacterId] then
                        _craftingState[cleanupCharacterId] = nil
                        print("ZItemTiers: [ISHandcraftAction] Cleaned up crafting state for character " .. cleanupCharacterId)
                    end
                    return false  -- Remove this event handler
                end
                return true
            end)
        end
        
        return result
    end
    
    print("ZItemTiers: Hooked ISHandcraftAction:performRecipe for crafting rarity")
end

-- Hook into Actions.addOrDropItem to catch crafted items
-- This is called when items are added to inventory during crafting (both ISCraftAction and ISHandcraftAction)
local originalAddOrDropItem = Actions.addOrDropItem
if originalAddOrDropItem then
    function Actions.addOrDropItem(character, item)
        -- Check if there's an active crafting state for this character
        if character and item then
            local characterId = nil
            local successId, id = pcall(function() 
                if character.getOnlineID then
                    return character:getOnlineID()
                end
                return nil
            end)
            if successId and id then
                characterId = id
            end
            
            -- Check if this item is being added during crafting
            if characterId and _craftingState[characterId] then
                local state = _craftingState[characterId]
                if state and state.rarity then
                    -- Check if item is blacklisted
                    if not ZItemTiers.IsItemBlacklisted(item) then
                        -- Check if item already has rarity (might have been set by RecipeManager.PerformMakeItem)
                        local modData = item:getModData()
                        if modData then
                            local currentRarity = modData.itemRarity
                            local isCrafted = modData.craftedFromRarity == true
                            
                            -- Apply rarity if item doesn't have it yet, or if it's Common (spawn_hooks might have set it)
                            if not currentRarity or (currentRarity == "Common" and not isCrafted) then
                                print("ZItemTiers: [addOrDropItem] Applying rarity " .. state.rarity .. " to crafted item: " .. item:getFullType() .. " (was: " .. tostring(currentRarity) .. ")")
                                modData.itemRarity = state.rarity
                                modData.craftedFromRarity = true
                                
                                -- Apply the calculated rarity bonuses
                                if ZItemTiers and ZItemTiers.ApplyRarityBonuses then
                                    ZItemTiers.ApplyRarityBonuses(item, state.rarity)
                                end
                                
                                print("ZItemTiers: [addOrDropItem] Applied rarity " .. state.rarity .. " to crafted item: " .. item:getFullType())
                            else
                                print("ZItemTiers: [addOrDropItem] Item already has rarity: " .. tostring(currentRarity) .. " (skipping)")
                            end
                        end
                    end
                end
            end
        end
        
        -- Call original addOrDropItem
        return originalAddOrDropItem(character, item)
    end
    
    print("ZItemTiers: Hooked Actions.addOrDropItem for crafting rarity")
else
    print("ZItemTiers: WARNING: Actions.addOrDropItem not found, cannot hook crafting rarity")
end

-- Hook into OnContainerUpdate to catch items created in OnCreate callbacks
-- This fires when items are added to containers (including player inventory)
local function onContainerUpdateForCrafting(container)
    if not container then return end
    
    -- Check all active crafting states and see if any match this container
    for characterId, state in pairs(_craftingState) do
        if state and state.character then
            local successCheck, isMatch = pcall(function()
                if not state.character or not state.character.getInventory then
                    return false
                end
                local charInv = state.character:getInventory()
                if not charInv then
                    return false
                end
                return charInv == container
            end)
            
            if successCheck and isMatch then
                local preCraftItemIds = state.preCraftItemIds or {}
                print("ZItemTiers: [OnContainerUpdate] Container matches character " .. characterId .. " inventory")
                local successGetItems, items = pcall(function()
                    return container:getItems()
                end)
                if successGetItems and items then
                    print("ZItemTiers: [OnContainerUpdate] Checking " .. items:size() .. " items")
                    local foundNewItems = false
                    for i = 0, items:size() - 1 do
                        local item = items:get(i)
                        if item then
                            -- Check if this is a new item (not in pre-craft snapshot)
                            local isNewItem = false
                            local successId, itemId = pcall(function() 
                                if item.getID then
                                    return item:getID()
                                end
                                return nil
                            end)
                            if successId and itemId then
                                isNewItem = not preCraftItemIds[itemId]
                            end
                            
                            local modData = item:getModData()
                            if modData then
                                local hasRarity = modData.itemRarity ~= nil
                                local currentRarity = modData.itemRarity or "Common"
                                local isCrafted = modData.craftedFromRarity == true
                                local isBlacklisted = ZItemTiers and ZItemTiers.IsItemBlacklisted and ZItemTiers.IsItemBlacklisted(item) or false
                                local itemType = item:getFullType()
                                
                                -- Apply rarity to new items, or override Common rarity on items created during crafting
                                -- Be more aggressive: if item has Common rarity and we're in a crafting state, override it
                                local shouldApply = false
                                if isNewItem and not isCrafted and not isBlacklisted then
                                    -- New item created during crafting
                                    shouldApply = true
                                    print("ZItemTiers: [OnContainerUpdate] Detected new item: " .. itemType .. " (isNewItem=true)")
                                elseif hasRarity and currentRarity == "Common" and not isCrafted and not isBlacklisted then
                                    -- Item has Common rarity but was created during crafting - override it
                                    -- Don't require isNewItem here, as spawn_hooks might have applied Common before we could check
                                    shouldApply = true
                                    print("ZItemTiers: [OnContainerUpdate] Detected Common item to override: " .. itemType .. " (hasRarity=" .. tostring(hasRarity) .. ", currentRarity=" .. currentRarity .. ")")
                                end
                                
                                if shouldApply then
                                    foundNewItems = true
                                    print("ZItemTiers: [OnContainerUpdate] Applying rarity " .. state.rarity .. " to item: " .. itemType .. " (was: " .. currentRarity .. ")")
                                    modData.itemRarity = state.rarity
                                    modData.craftedFromRarity = true
                                    if ZItemTiers and ZItemTiers.ApplyRarityBonuses then
                                        ZItemTiers.ApplyRarityBonuses(item, state.rarity)
                                    end
                                    print("ZItemTiers: [OnContainerUpdate] Applied rarity " .. state.rarity .. " to OnCreate-crafted item: " .. itemType)
                                else
                                    -- Debug: log why we didn't apply
                                    print("ZItemTiers: [OnContainerUpdate] Skipped item: " .. itemType .. " (isNewItem=" .. tostring(isNewItem) .. ", hasRarity=" .. tostring(hasRarity) .. ", currentRarity=" .. tostring(currentRarity) .. ", isCrafted=" .. tostring(isCrafted) .. ", isBlacklisted=" .. tostring(isBlacklisted) .. ")")
                                end
                            end
                        end
                    end
                    
                    -- Clean up state after processing (items are added immediately during OnCreate)
                    if foundNewItems then
                        -- Delay cleanup slightly to catch any items added in the same frame
                        if not state._cleanupScheduled then
                            state._cleanupScheduled = true
                            local cleanupTicks = 0
                            local cleanupCharacterId = characterId
                            Events.OnTick.Add(function()
                                cleanupTicks = cleanupTicks + 1
                                -- Clean up after 5 ticks to allow all items to be added
                                if cleanupTicks >= 5 then
                                    if _craftingState[cleanupCharacterId] then
                                        _craftingState[cleanupCharacterId] = nil
                                        print("ZItemTiers: [OnContainerUpdate] Cleaned up crafting state for character " .. cleanupCharacterId)
                                    end
                                    return false  -- Remove this event handler
                                end
                                return true
                            end)
                        end
                    else
                        print("ZItemTiers: [OnContainerUpdate] No new items found without rarity")
                    end
                end
                break  -- Found matching state, no need to check others
            end
        end
    end
end

-- Hook into OnContainerUpdate event (add our handler, don't replace existing ones)
Events.OnContainerUpdate.Add(onContainerUpdateForCrafting)

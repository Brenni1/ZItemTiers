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
    
    -- Fallback: if recipe method failed, try to manually check common crafting skills
    if skillLevel == 0 and character then
        local successFallback, fallbackLevel = pcall(function()
            -- Check common crafting skills
            local commonSkills = {
                "Tailoring", "Cooking", "Metalworking", "Electricity", "Mechanics",
                "Carpentry", "Farming", "Trapping", "Fishing", "FirstAid"
            }
            local maxLevel = 0
            for _, skillName in ipairs(commonSkills) do
                local perk = Perks[skillName]
                if perk and character.getPerkLevel then
                    local level = character:getPerkLevel(perk)
                    if level and level > maxLevel then
                        maxLevel = level
                    end
                end
            end
            return maxLevel
        end)
        if successFallback and fallbackLevel and fallbackLevel > 0 then
            print("ZItemTiers: [Crafting] Using fallback skill level detection: " .. fallbackLevel)
            skillLevel = fallbackLevel
        end
    end
    
    -- Debug: log skill level detection
    if not character or not recipe then
        print("ZItemTiers: [Crafting] WARNING: Missing character or recipe for skill level detection (character=" .. tostring(character ~= nil) .. ", recipe=" .. tostring(recipe ~= nil) .. ", skillLevel=" .. skillLevel .. ")")
    else
        print("ZItemTiers: [Crafting] Detected skill level: " .. skillLevel)
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
    
    -- Debug: log calculation before skill modifiers
    print("ZItemTiers: [Crafting] Calculated targetIndex=" .. targetIndex .. " (skillLevel=" .. skillLevel .. ")")
    
    -- Apply skill level modifiers
    if skillLevel == 0 then
        -- Skill level 0: 50% chance to be 1 tier lower
        local roll = ZombRand(10000) / 10000.0  -- Random 0.0 to 1.0
        if roll < 0.5 then
            -- Reduce by 1 tier (but not below Common/1)
            local oldIndex = targetIndex
            targetIndex = math.max(1, targetIndex - 1)
            print("ZItemTiers: [Crafting] Skill level 0 reduced tier from " .. oldIndex .. " to " .. targetIndex .. " (roll=" .. roll .. ")")
        else
            print("ZItemTiers: [Crafting] Skill level 0 kept tier at " .. targetIndex .. " (roll=" .. roll .. " >= 0.5)")
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
    else
        -- Skill level 1: No change (keep calculated tier)
        print("ZItemTiers: [Crafting] Skill level 1 kept tier at " .. targetIndex .. " (no change)")
    end
    
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
                    local onlineId = character:getOnlineID()
                    -- Normalize nil to 0 for single-player
                    if onlineId == nil then
                        return 0
                    end
                    return onlineId
                end
                return 0  -- Default to 0 for single-player
            end)
            if successId and id ~= nil then
                characterId = id
            end
        end
        
        -- Calculate output rarity BEFORE performing recipe
        local outputRarity = nil
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
                    print("ZItemTiers: [ISHandcraftAction] Retrieved recipe: " .. tostring(recipe))
                else
                    print("ZItemTiers: [ISHandcraftAction] WARNING: Could not retrieve recipe (successGetRecipe=" .. tostring(successGetRecipe) .. ", recipeData=" .. tostring(recipeData ~= nil) .. ")")
                end
            else
                print("ZItemTiers: [ISHandcraftAction] WARNING: No logic available for recipe retrieval")
            end
            
            outputRarity = ZItemTiers.CalculateCraftingRarity(consumedItems, character, recipe)
            
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
            
            -- Get expected output item types from recipe (if available)
            local expectedOutputTypes = {}
            if recipe then
                local successGetOutputs, outputs = pcall(function()
                    -- Try different methods to get output types
                    if recipe.getOutputs then
                        return recipe:getOutputs()
                    elseif recipe.outputs then
                        return recipe.outputs
                    end
                    return nil
                end)
                if successGetOutputs and outputs then
                    -- outputs might be an ArrayList or table
                    if type(outputs) == "table" then
                        -- Check if it's an ArrayList (has size() method)
                        local successSize, size = pcall(function()
                            if outputs.size then
                                return outputs:size()
                            end
                            return nil
                        end)
                        if successSize and size then
                            -- It's an ArrayList
                            for i = 0, size - 1 do
                                local output = outputs:get(i)
                                if output then
                                    local successType, outputType = pcall(function()
                                        if output.getFullType then
                                            return output:getFullType()
                                        elseif output.getType then
                                            return output:getType()
                                        elseif type(output) == "string" then
                                            return output
                                        end
                                        return nil
                                    end)
                                    if successType and outputType then
                                        expectedOutputTypes[outputType] = true
                                    end
                                end
                            end
                        else
                            -- It's a regular table - iterate safely
                            local successIterate, _ = pcall(function()
                                for _, outputType in ipairs(outputs) do
                                    if type(outputType) == "string" then
                                        expectedOutputTypes[outputType] = true
                                    end
                                end
                            end)
                            if not successIterate then
                                -- If ipairs fails, try treating it as a simple value
                                if type(outputs) == "string" then
                                    expectedOutputTypes[outputs] = true
                                end
                            end
                        end
                    end
                end
            end
            
            -- Take snapshot of existing item IDs BEFORE performing recipe (for OnContainerUpdate detection)
            local preCraftItemIds = {}
            if character and character.getInventory then
                local inventory = character:getInventory()
                if inventory then
                    local successGetItems, items = pcall(function()
                        if inventory.getItems then
                            return inventory:getItems()
                        end
                        return nil
                    end)
                    if successGetItems and items then
                        for i = 0, items:size() - 1 do
                            local item = items:get(i)
                            if item then
                                local successId, itemId = pcall(function()
                                    if item.getID then
                                        return item:getID()
                                    end
                                    return nil
                                end)
                                if successId and itemId then
                                    preCraftItemIds[itemId] = true
                                end
                            end
                        end
                    end
                end
            end
            
            -- Store rarities of consumed items for bundle/unbundle operations
            local consumedRarities = {}
            if consumedItems then
                for i = 0, consumedItems:size() - 1 do
                    local consumedItem = consumedItems:get(i)
                    if consumedItem then
                        -- Check if this is a bundle with stored rarities (unbundling scenario)
                        local consumedModData = consumedItem:getModData()
                        if consumedModData and consumedModData.bundledRarities then
                            -- This is a bundle being unbundled - use stored rarities
                            for _, storedRarity in ipairs(consumedModData.bundledRarities) do
                                table.insert(consumedRarities, storedRarity)
                            end
                            print("ZItemTiers: [ISHandcraftAction] Found bundle with " .. #consumedModData.bundledRarities .. " stored rarities for unbundling")
                        else
                            -- Regular item - use its rarity (store ALL rarities including Common)
                            local itemRarity = ZItemTiers.GetItemRarity(consumedItem)
                            if itemRarity then
                                table.insert(consumedRarities, itemRarity)
                            else
                                -- Default to Common if no rarity found
                                table.insert(consumedRarities, "Common")
                            end
                        end
                    end
                end
            end
            
            -- Store crafting state for Actions.addOrDropItem hook and OnContainerUpdate
            _craftingState[characterId] = {
                rarity = outputRarity,
                timestamp = getGameTime():getWorldAgeHours() or 0,
                character = character,
                preCraftItemIds = preCraftItemIds,
                expectedOutputTypes = expectedOutputTypes,
                consumedRarities = consumedRarities  -- Store for bundle preservation
            }
            local itemCount = 0
            for _ in pairs(preCraftItemIds) do
                itemCount = itemCount + 1
            end
            local expectedTypesCount = 0
            for _ in pairs(expectedOutputTypes) do
                expectedTypesCount = expectedTypesCount + 1
            end
            print("ZItemTiers: [ISHandcraftAction] Stored crafting state for character " .. characterId .. " with rarity " .. outputRarity .. " (snapshot: " .. itemCount .. " items, expected outputs: " .. expectedTypesCount .. ")")
        end
        
        -- Perform the original recipe (this will call Actions.addOrDropItem)
        local result = originalHandcraftPerformRecipe(self)
        
        -- Try to get created items directly from logic after recipe is performed
        if characterId and _craftingState[characterId] and self.logic then
            local state = _craftingState[characterId]
            local successGetItems, createdItems = pcall(function()
                if self.logic.getCreatedOutputItems then
                    local items = ArrayList.new()
                    self.logic:getCreatedOutputItems(items)
                    return items
                end
                return nil
            end)
            
            if successGetItems and createdItems and createdItems:size() > 0 then
                print("ZItemTiers: [ISHandcraftAction] Found " .. createdItems:size() .. " created items via getCreatedOutputItems")
                for i = 0, createdItems:size() - 1 do
                    local item = createdItems:get(i)
                    if item then
                        local itemType = item:getFullType()
                        local modData = item:getModData()
                        if modData and not ZItemTiers.IsItemBlacklisted(item) then
                            local currentRarity = modData.itemRarity
                            local isCrafted = modData.craftedFromRarity == true
                            
                            if not currentRarity or (currentRarity == "Common" and not isCrafted) then
                                print("ZItemTiers: [ISHandcraftAction] Applying rarity " .. state.rarity .. " to created item: " .. itemType .. " (was: " .. tostring(currentRarity) .. ")")
                                modData.itemRarity = state.rarity
                                modData.craftedFromRarity = true
                                
                                -- If this is a bundle and we have consumed rarities, store them for later restoration
                                if state.consumedRarities and #state.consumedRarities > 0 then
                                    if string.find(itemType, "Bundle") then
                                        modData.bundledRarities = state.consumedRarities
                                        print("ZItemTiers: [ISHandcraftAction] Stored " .. #state.consumedRarities .. " consumed rarities in bundle modData")
                                    end
                                end
                                
                                if ZItemTiers and ZItemTiers.ApplyRarityBonuses then
                                    ZItemTiers.ApplyRarityBonuses(item, state.rarity)
                                end
                                print("ZItemTiers: [ISHandcraftAction] Applied rarity " .. state.rarity .. " to created item: " .. itemType)
                            else
                                print("ZItemTiers: [ISHandcraftAction] Item already has rarity: " .. tostring(currentRarity) .. " (skipping)")
                            end
                        end
                    end
                end
                -- Clean up state immediately since we handled it
                _craftingState[characterId] = nil
                print("ZItemTiers: [ISHandcraftAction] Cleaned up crafting state after direct item application")
            else
                -- Fallback: use OnTick to scan inventory for new items
                print("ZItemTiers: [ISHandcraftAction] Could not get created items directly, using OnTick fallback")
            local cleanupCharacterId = characterId
            local cleanupTicks = 0
                local foundItem = false
            Events.OnTick.Add(function()
                cleanupTicks = cleanupTicks + 1
                    
                    -- Stop if we already found the item
                    if foundItem then
                        return false
                    end
                    
                    -- Try to find items in inventory (check for up to 30 ticks)
                    if cleanupTicks <= 30 and _craftingState[cleanupCharacterId] then
                        local state = _craftingState[cleanupCharacterId]
                        if state and state.character and state.character.getInventory then
                            local inventory = state.character:getInventory()
                            if inventory then
                                local successGetItems, items = pcall(function()
                                    if inventory.getItems then
                                        return inventory:getItems()
                                    end
                                    return nil
                                end)
                                if successGetItems and items then
                                    local preCraftItemIds = state.preCraftItemIds or {}
                                    for i = 0, items:size() - 1 do
                                        local item = items:get(i)
                                        if item then
                                            local successId, itemId = pcall(function()
                                                if item.getID then
                                                    return item:getID()
                                                end
                                                return nil
                                            end)
                                            
                                            local modData = item:getModData()
                                            if modData and not modData.craftedFromRarity and not ZItemTiers.IsItemBlacklisted(item) then
                                                local currentRarity = modData.itemRarity
                                                local isNewItem = false
                                                if successId and itemId then
                                                    isNewItem = not preCraftItemIds[itemId]
                                                end
                                                
                                                -- Only apply to new items (not in pre-craft snapshot)
                                                if isNewItem then
                                                    local itemType = item:getFullType()
                                                    local expectedOutputTypes = state.expectedOutputTypes or {}
                                                    
                                                    -- Check if this item matches expected output types (if we have them)
                                                    local matchesExpected = true
                                                    -- Check if expectedOutputTypes has any entries by counting them
                                                    local hasEntries = false
                                                    local count = 0
                                                    for _ in pairs(expectedOutputTypes) do
                                                        count = count + 1
                                                        hasEntries = true
                                                        break  -- Just need to know if it has entries
                                                    end
                                                    
                                                    if hasEntries then
                                                        matchesExpected = expectedOutputTypes[itemType] == true
                                                        if not matchesExpected then
                                                            print("ZItemTiers: [ISHandcraftAction] OnTick: New item " .. itemType .. " does not match expected output types")
                                                        end
                                                    end
                                                    
                                                    -- Apply rarity if item is new and matches expected output (or if we don't have expected outputs)
                                                    if matchesExpected then
                                                        print("ZItemTiers: [ISHandcraftAction] OnTick (tick " .. cleanupTicks .. "): Applying rarity " .. state.rarity .. " to new item: " .. itemType .. " (was: " .. tostring(currentRarity) .. ")")
                                                        modData.itemRarity = state.rarity
                                                        modData.craftedFromRarity = true
                                                        if ZItemTiers and ZItemTiers.ApplyRarityBonuses then
                                                            ZItemTiers.ApplyRarityBonuses(item, state.rarity)
                                                        end
                                                        foundItem = true
                                                        _craftingState[cleanupCharacterId] = nil
                                                        print("ZItemTiers: [ISHandcraftAction] OnTick: Cleaned up crafting state after finding item")
                                                        return false
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    -- Clean up after 30 ticks if still active
                    if cleanupTicks >= 30 then
                        if _craftingState[cleanupCharacterId] then
                            print("ZItemTiers: [ISHandcraftAction] Cleaned up crafting state for character " .. cleanupCharacterId .. " after " .. cleanupTicks .. " ticks (safety cleanup)")
                        _craftingState[cleanupCharacterId] = nil
                    end
                    return false  -- Remove this event handler
                end
                return true
            end)
            end
        end
        
        return result
    end
    
    print("ZItemTiers: Hooked ISHandcraftAction:performRecipe for crafting rarity")
end

-- Hook into Actions.addOrDropItem to catch crafted items
-- This is called when items are added to inventory during crafting (both ISCraftAction and ISHandcraftAction)
if not Actions then
    print("ZItemTiers: WARNING: Actions table does not exist!")
end
local originalAddOrDropItem = Actions and Actions.addOrDropItem or nil
if originalAddOrDropItem then
    print("ZItemTiers: Found Actions.addOrDropItem, setting up hook")
    function Actions.addOrDropItem(character, item)
        -- Check if there's an active crafting state for this character
        local hasAnyCraftingState = false
        for _ in pairs(_craftingState) do
            hasAnyCraftingState = true
            break
        end
        if hasAnyCraftingState then
            print("ZItemTiers: [addOrDropItem] ENTRY - character: " .. tostring(character ~= nil) .. ", item: " .. tostring(item ~= nil))
        end
        
        if character and item then
            local characterId = nil
            local successId, id = pcall(function() 
                if character.getOnlineID then
                    local onlineId = character:getOnlineID()
                    -- Normalize nil to 0 for single-player
                    if onlineId == nil then
                        return 0
                    end
                    return onlineId
                end
                return 0  -- Default to 0 for single-player
            end)
            if successId and id ~= nil then
                characterId = id
            end
            
            local itemType = nil
            local successType, typeValue = pcall(function() return item:getFullType() end)
            if successType and typeValue then
                itemType = typeValue
            end
            
            -- Log all addOrDropItem calls if there's any active crafting state
            if hasAnyCraftingState then
                print("ZItemTiers: [addOrDropItem] Called for item: " .. tostring(itemType) .. " (characterId: " .. tostring(characterId) .. ", hasState: " .. tostring(characterId and _craftingState[characterId] ~= nil) .. ")")
                -- Also log all active state IDs for debugging
                local stateIds = {}
                for id, _ in pairs(_craftingState) do
                    table.insert(stateIds, tostring(id))
                end
                print("ZItemTiers: [addOrDropItem] Active crafting state IDs: " .. table.concat(stateIds, ", "))
                -- Also try to get character ID via different methods
                local altId = nil
                local successAlt, altIdValue = pcall(function()
                    if character.getPlayerNum then
                        return character:getPlayerNum()
                    end
                    return nil
                end)
                if successAlt and altIdValue then
                    altId = altIdValue
                end
                print("ZItemTiers: [addOrDropItem] Character alt ID (getPlayerNum): " .. tostring(altId))
            end
            
            -- Check if this item is being added during crafting
            -- Try to match by character ID first, then by character object
            local matchedState = nil
            if characterId and _craftingState[characterId] then
                matchedState = _craftingState[characterId]
            else
                -- Fallback: match by character object
                for id, state in pairs(_craftingState) do
                    if state and state.character == character then
                        matchedState = state
                        characterId = id
                        print("ZItemTiers: [addOrDropItem] Matched crafting state by character object (id: " .. tostring(id) .. ")")
                        break
                    end
                end
            end
            
            if matchedState and matchedState.rarity then
                    -- Check if item is blacklisted
                    if not ZItemTiers.IsItemBlacklisted(item) then
                        -- Check if item already has rarity (might have been set by RecipeManager.PerformMakeItem)
                        local modData = item:getModData()
                        if modData then
                            local currentRarity = modData.itemRarity
                            local isCrafted = modData.craftedFromRarity == true
                        
                        -- Check if we're unbundling (check consumed items for bundles with stored rarities)
                        local rarityToApply = matchedState.rarity
                        local unbundleRarityIndex = matchedState._unbundleRarityIndex or 0
                        
                        if matchedState.consumedRarities and #matchedState.consumedRarities > 0 then
                            -- We have stored rarities from consumed items (unbundling scenario)
                            unbundleRarityIndex = unbundleRarityIndex + 1
                            if unbundleRarityIndex <= #matchedState.consumedRarities then
                                rarityToApply = matchedState.consumedRarities[unbundleRarityIndex]
                                matchedState._unbundleRarityIndex = unbundleRarityIndex
                                print("ZItemTiers: [addOrDropItem] Unbundling: Using stored rarity " .. rarityToApply .. " (index " .. unbundleRarityIndex .. "/" .. #matchedState.consumedRarities .. ")")
                            else
                                -- Ran out of stored rarities - default to the overall calculated rarity
                                rarityToApply = matchedState.rarity
                                print("ZItemTiers: [addOrDropItem] Unbundling: Ran out of stored rarities, falling back to overall rarity: " .. rarityToApply .. " (index " .. unbundleRarityIndex .. " > " .. #matchedState.consumedRarities .. ")")
                            end
                        end
                            
                            -- Apply rarity if item doesn't have it yet, or if it's Common (spawn_hooks might have set it)
                            if not currentRarity or (currentRarity == "Common" and not isCrafted) then
                            print("ZItemTiers: [addOrDropItem] Applying rarity " .. rarityToApply .. " to crafted item: " .. tostring(itemType) .. " (was: " .. tostring(currentRarity) .. ")")
                            modData.itemRarity = rarityToApply
                                modData.craftedFromRarity = true
                                
                                -- Apply the calculated rarity bonuses
                                if ZItemTiers and ZItemTiers.ApplyRarityBonuses then
                                ZItemTiers.ApplyRarityBonuses(item, rarityToApply)
                                end
                                
                            print("ZItemTiers: [addOrDropItem] Applied rarity " .. rarityToApply .. " to crafted item: " .. tostring(itemType))
                            else
                                print("ZItemTiers: [addOrDropItem] Item already has rarity: " .. tostring(currentRarity) .. " (skipping)")
                            end
                        else
                            print("ZItemTiers: [addOrDropItem] WARNING: No modData for item: " .. tostring(itemType))
                        end
                    else
                        print("ZItemTiers: [addOrDropItem] Item is blacklisted: " .. tostring(itemType))
                    end
            elseif matchedState then
                print("ZItemTiers: [addOrDropItem] WARNING: Crafting state exists but no rarity (state: " .. tostring(matchedState) .. ")")
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
    
    -- Log if there are any active crafting states
    local hasActiveCrafting = false
    for _ in pairs(_craftingState) do
        hasActiveCrafting = true
        break
    end
    if hasActiveCrafting then
        print("ZItemTiers: [OnContainerUpdate] Called (hasActiveCrafting: true)")
    end
    
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

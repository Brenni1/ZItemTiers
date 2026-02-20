-- Crafting tier system
-- Implements Factorio-style crafting where output tier is based on ingredient tiers
-- If all ingredients are Epic, output is at least Epic
-- If ingredients have different tiers, output tier is based on their ratio/probability

require "ZItemTiers/core"

-- Ensure ZItemTiers is initialized as a table
ZItemTiers = ZItemTiers or {}

-- Calculate output tier based on ingredient tiers (Factorio-style)
-- Returns the calculated tier name
-- Parameters:
--   ingredientItems: ArrayList of ingredient items
--   character: (optional) IsoGameCharacter performing the craft
--   recipe: (optional) CraftRecipe being performed
-- Rules:
-- 1. If all ingredients are Epic, output is at least Epic
-- 2. If ingredients have different tiers, output tier is based on their ratio/probability
-- 3. Output is always at least the minimum (highest tier) tier among ingredients
-- 4. Skill level affects the result:
--    - Level 0: 50% chance to be 1 tier lower
--    - Level 1: Keep calculated tier (no change)
--    - Level > 1: Small chance (5% per level above 1) to be 1 tier higher
function ZItemTiers.CalculateCraftingTier(ingredientItems, character, recipe)
    if not ingredientItems or ingredientItems:size() == 0 then
        -- No ingredients, use normal spawn probability
        return ZItemTiers.RollTier()
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
    
    -- Collect tiers from all ingredients
    local tierCounts = {}
    local totalIngredients = 0
    
    for i = 0, ingredientItems:size() - 1 do
        local ingredient = ingredientItems:get(i)
        if ingredient then
            local tier = ZItemTiers.GetItemTier(ingredient)
            if tier then
                tierCounts[tier] = (tierCounts[tier] or 0) + 1
                totalIngredients = totalIngredients + 1
            end
        end
    end
    
    if totalIngredients == 0 then
        -- No ingredients with tier, use normal spawn probability
        return ZItemTiers.RollTier()
    end
    
    -- Find the minimum tier index (highest tier) among all ingredients
    -- This is the "floor" - output will be at least this tier
    local minTierIndex = nil
    for tierName, count in pairs(tierCounts) do
        local tierData = ZItemTiers.Tiers[tierName]
        if tierData then
            if minTierIndex == nil or tierData.index > minTierIndex then
                minTierIndex = tierData.index
            end
        end
    end
    
    if not minTierIndex then
        return "Common"
    end
    
    -- Calculate weighted average of ingredient tiers based on count
    local weightedSum = 0
    for tierName, count in pairs(tierCounts) do
        local tierData = ZItemTiers.Tiers[tierName]
        if tierData then
            weightedSum = weightedSum + (tierData.index * count)
        end
    end
    local averageIndex = weightedSum / totalIngredients
    
    -- Round to nearest integer
    local targetIndex = math.floor(averageIndex + 0.5)
    
    -- Ensure output is at least the minimum tier tier (Factorio rule: all Epic -> at least Epic)
    targetIndex = math.max(minTierIndex, targetIndex)
    
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
    
    -- Clamp to valid tier range (1-5)
    targetIndex = math.max(1, math.min(5, targetIndex))
    
    -- Find tier name by index
    for tierName, tierData in pairs(ZItemTiers.Tiers) do
        if tierData.index == targetIndex then
            return tierName
        end
    end
    
    -- Fallback: return the minimum tier
    for tierName, tierData in pairs(ZItemTiers.Tiers) do
        if tierData.index == minTierIndex then
            return tierName
        end
    end
    
    return "Common"
end

-- Hook into RecipeManager.PerformMakeItem to apply crafting tier
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
    
    -- Calculate output tier BEFORE performing recipe (so we can store it in crafting state)
    local outputTier = nil
    if successGet and sourceItems and sourceItems:size() > 0 then
        outputTier = ZItemTiers.CalculateCraftingTier(sourceItems, character, recipe)
        
        -- Debug: log source items and their tiers
        local debugMsg = "ZItemTiers: [PerformMakeItem] Crafting with " .. sourceItems:size() .. " ingredients: "
        for i = 0, sourceItems:size() - 1 do
            local ing = sourceItems:get(i)
            if ing then
                local tier = ZItemTiers.GetItemTier(ing)
                local fullType = ing:getFullType()
                debugMsg = debugMsg .. fullType .. "(" .. tier .. ") "
            end
        end
        print(debugMsg)
        print("ZItemTiers: [PerformMakeItem] Calculated output tier: " .. outputTier)
        
        -- Store crafting state for Actions.addOrDropItem hook
        if characterId then
            _craftingState[characterId] = {
                tier = outputTier,
                timestamp = getGameTime():getWorldAgeHours() or 0,
                character = character
            }
            print("ZItemTiers: [PerformMakeItem] Stored crafting state for character " .. characterId .. " with tier " .. outputTier)
        end
    end
    
    -- Perform the recipe (consumes items, creates outputs)
    local result = originalPerformMakeItem(recipe, item, character, containers)
    
    -- Apply tier to created items if we got source items
    -- Note: Some items might be added via Actions.addOrDropItem (which will handle them),
    -- but items returned directly by PerformMakeItem should also be handled here
    if result and result:size() > 0 and outputTier then
        print("ZItemTiers: [PerformMakeItem] Applying tier to " .. result:size() .. " created items")
        
        -- Apply tier to all created items
        for i = 0, result:size() - 1 do
            local createdItem = result:get(i)
            if createdItem and not ZItemTiers.IsItemBlacklisted(createdItem) then
                -- Store tier in modData FIRST to prevent spawn_hooks from overriding it
                local modData = createdItem:getModData()
                if modData then
                    modData.itemTier = outputTier
                    modData.craftedFromTier = true  -- Flag to indicate this was crafted
                end
                
                -- Apply the calculated tier
                ZItemTiers.ApplyTierBonuses(createdItem, outputTier)
                
                -- Verify tier was applied
                local verifyTier = ZItemTiers.GetItemTier(createdItem)
                print("ZItemTiers: [PerformMakeItem] Applied tier " .. outputTier .. " to crafted item: " .. createdItem:getFullType() .. " (verified: " .. verifyTier .. ")")
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
        -- Clean up crafting state if we couldn't calculate tier
        if characterId and _craftingState[characterId] then
            _craftingState[characterId] = nil
        end
    end
    
    return result
end

-- Track crafting state to catch items created in OnCreate callbacks (like ripClothing)
-- Maps character ID to crafting state (tier, timestamp)
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
        
        -- Calculate output tier BEFORE performing recipe
        local outputTier = nil
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
            
            outputTier = ZItemTiers.CalculateCraftingTier(consumedItems, character, recipe)
            
            -- Debug: log consumed items
            local debugMsg = "ZItemTiers: [ISHandcraftAction] Crafting with " .. consumedItems:size() .. " ingredients: "
            for i = 0, consumedItems:size() - 1 do
                local ing = consumedItems:get(i)
                if ing then
                    local tier = ZItemTiers.GetItemTier(ing)
                    local fullType = ing:getFullType()
                    debugMsg = debugMsg .. fullType .. "(" .. tier .. ") "
                end
            end
            print(debugMsg)
            print("ZItemTiers: [ISHandcraftAction] Calculated output tier: " .. outputTier)
            
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
            
            -- Store tiers of consumed items for bundle/unbundle operations
            local consumedTiers = {}
            if consumedItems then
                for i = 0, consumedItems:size() - 1 do
                    local consumedItem = consumedItems:get(i)
                    if consumedItem then
                        -- Check if this is a bundle with stored tiers (unbundling scenario)
                        local consumedModData = consumedItem:getModData()
                        if consumedModData and consumedModData.bundledTiers then
                            -- This is a bundle being unbundled - use stored tiers
                            for _, storedTier in ipairs(consumedModData.bundledTiers) do
                                table.insert(consumedTiers, storedTier)
                            end
                            print("ZItemTiers: [ISHandcraftAction] Found bundle with " .. #consumedModData.bundledTiers .. " stored tiers for unbundling")
                        else
                            -- Regular item - use its tier (store ALL tiers including Common)
                            local itemTier = ZItemTiers.GetItemTier(consumedItem)
                            if itemTier then
                                table.insert(consumedTiers, itemTier)
                            else
                                -- Default to Common if no tier found
                                table.insert(consumedTiers, "Common")
                            end
                        end
                    end
                end
            end
            
            -- Store crafting state for Actions.addOrDropItem hook and OnContainerUpdate
            _craftingState[characterId] = {
                tier = outputTier,
                timestamp = getGameTime():getWorldAgeHours() or 0,
                character = character,
                preCraftItemIds = preCraftItemIds,
                expectedOutputTypes = expectedOutputTypes,
                consumedTiers = consumedTiers  -- Store for bundle preservation
            }
            local itemCount = 0
            for _ in pairs(preCraftItemIds) do
                itemCount = itemCount + 1
            end
            local expectedTypesCount = 0
            for _ in pairs(expectedOutputTypes) do
                expectedTypesCount = expectedTypesCount + 1
            end
            print("ZItemTiers: [ISHandcraftAction] Stored crafting state for character " .. characterId .. " with tier " .. outputTier .. " (snapshot: " .. itemCount .. " items, expected outputs: " .. expectedTypesCount .. ")")
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
                            local currentTier = modData.itemTier
                            local isCrafted = modData.craftedFromTier == true
                            
                            if not currentTier or (currentTier == "Common" and not isCrafted) then
                                print("ZItemTiers: [ISHandcraftAction] Applying tier " .. state.tier .. " to created item: " .. itemType .. " (was: " .. tostring(currentTier) .. ")")
                                modData.itemTier = state.tier
                                modData.craftedFromTier = true
                                
                                -- If this is a bundle and we have consumed tiers, store them for later restoration
                                if state.consumedTiers and #state.consumedTiers > 0 then
                                    if string.find(itemType, "Bundle") then
                                        modData.bundledTiers = state.consumedTiers
                                        print("ZItemTiers: [ISHandcraftAction] Stored " .. #state.consumedTiers .. " consumed tiers in bundle modData")
                                    end
                                end
                                
                                if ZItemTiers and ZItemTiers.ApplyTierBonuses then
                                    ZItemTiers.ApplyTierBonuses(item, state.tier)
                                end
                                print("ZItemTiers: [ISHandcraftAction] Applied tier " .. state.tier .. " to created item: " .. itemType)
                            else
                                print("ZItemTiers: [ISHandcraftAction] Item already has tier: " .. tostring(currentTier) .. " (skipping)")
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
                                            if modData and not modData.craftedFromTier and not ZItemTiers.IsItemBlacklisted(item) then
                                                local currentTier = modData.itemTier
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
                                                    
                                                    -- Apply tier if item is new and matches expected output (or if we don't have expected outputs)
                                                    if matchesExpected then
                                                        print("ZItemTiers: [ISHandcraftAction] OnTick (tick " .. cleanupTicks .. "): Applying tier " .. state.tier .. " to new item: " .. itemType .. " (was: " .. tostring(currentTier) .. ")")
                                                        modData.itemTier = state.tier
                                                        modData.craftedFromTier = true
                                                        if ZItemTiers and ZItemTiers.ApplyTierBonuses then
                                                            ZItemTiers.ApplyTierBonuses(item, state.tier)
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
    
    print("ZItemTiers: Hooked ISHandcraftAction:performRecipe for crafting tier")
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
            
            if matchedState and matchedState.tier then
                    -- Check if item is blacklisted
                    if not ZItemTiers.IsItemBlacklisted(item) then
                        -- Check if item already has tier (might have been set by RecipeManager.PerformMakeItem)
                        local modData = item:getModData()
                        if modData then
                            local currentTier = modData.itemTier
                            local isCrafted = modData.craftedFromTier == true
                        
                        -- Check if we're unbundling (check consumed items for bundles with stored tiers)
                        local tierToApply = matchedState.tier
                        local unbundleTierIndex = matchedState._unbundleTierIndex or 0
                        
                        if matchedState.consumedTiers and #matchedState.consumedTiers > 0 then
                            -- We have stored tiers from consumed items (unbundling scenario)
                            unbundleTierIndex = unbundleTierIndex + 1
                            if unbundleTierIndex <= #matchedState.consumedTiers then
                                tierToApply = matchedState.consumedTiers[unbundleTierIndex]
                                matchedState._unbundleTierIndex = unbundleTierIndex
                                print("ZItemTiers: [addOrDropItem] Unbundling: Using stored tier " .. tierToApply .. " (index " .. unbundleTierIndex .. "/" .. #matchedState.consumedTiers .. ")")
                            else
                                -- Ran out of stored tiers - default to the overall calculated tier
                                tierToApply = matchedState.tier
                                print("ZItemTiers: [addOrDropItem] Unbundling: Ran out of stored tiers, falling back to overall tier: " .. tierToApply .. " (index " .. unbundleTierIndex .. " > " .. #matchedState.consumedTiers .. ")")
                            end
                        end
                            
                            -- Apply tier if item doesn't have it yet, or if it's Common (spawn_hooks might have set it)
                            if not currentTier or (currentTier == "Common" and not isCrafted) then
                            print("ZItemTiers: [addOrDropItem] Applying tier " .. tierToApply .. " to crafted item: " .. tostring(itemType) .. " (was: " .. tostring(currentTier) .. ")")
                            modData.itemTier = tierToApply
                                modData.craftedFromTier = true
                                
                                -- Apply the calculated tier bonuses
                                if ZItemTiers and ZItemTiers.ApplyTierBonuses then
                                ZItemTiers.ApplyTierBonuses(item, tierToApply)
                                end
                                
                            print("ZItemTiers: [addOrDropItem] Applied tier " .. tierToApply .. " to crafted item: " .. tostring(itemType))
                            else
                                print("ZItemTiers: [addOrDropItem] Item already has tier: " .. tostring(currentTier) .. " (skipping)")
                            end
                        else
                            print("ZItemTiers: [addOrDropItem] WARNING: No modData for item: " .. tostring(itemType))
                        end
                    else
                        print("ZItemTiers: [addOrDropItem] Item is blacklisted: " .. tostring(itemType))
                    end
            elseif matchedState then
                print("ZItemTiers: [addOrDropItem] WARNING: Crafting state exists but no tier (state: " .. tostring(matchedState) .. ")")
            end
        end
        
        -- Call original addOrDropItem
        return originalAddOrDropItem(character, item)
    end
    
    print("ZItemTiers: Hooked Actions.addOrDropItem for crafting tier")
else
    print("ZItemTiers: WARNING: Actions.addOrDropItem not found, cannot hook crafting tier")
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
                                local hasTier = modData.itemTier ~= nil
                                local currentTier = modData.itemTier or "Common"
                                local isCrafted = modData.craftedFromTier == true
                                local isBlacklisted = ZItemTiers and ZItemTiers.IsItemBlacklisted and ZItemTiers.IsItemBlacklisted(item) or false
                                local itemType = item:getFullType()
                                
                                -- Apply tier to new items, or override Common tier on items created during crafting
                                -- Be more aggressive: if item has Common tier and we're in a crafting state, override it
                                local shouldApply = false
                                if isNewItem and not isCrafted and not isBlacklisted then
                                    -- New item created during crafting
                                    shouldApply = true
                                    print("ZItemTiers: [OnContainerUpdate] Detected new item: " .. itemType .. " (isNewItem=true)")
                                elseif hasTier and currentTier == "Common" and not isCrafted and not isBlacklisted then
                                    -- Item has Common tier but was created during crafting - override it
                                    -- Don't require isNewItem here, as spawn_hooks might have applied Common before we could check
                                    shouldApply = true
                                    print("ZItemTiers: [OnContainerUpdate] Detected Common item to override: " .. itemType .. " (hasTier=" .. tostring(hasTier) .. ", currentTier=" .. currentTier .. ")")
                                end
                                
                                if shouldApply then
                                    foundNewItems = true
                                    print("ZItemTiers: [OnContainerUpdate] Applying tier " .. state.tier .. " to item: " .. itemType .. " (was: " .. currentTier .. ")")
                                    modData.itemTier = state.tier
                                    modData.craftedFromTier = true
                                    if ZItemTiers and ZItemTiers.ApplyTierBonuses then
                                        ZItemTiers.ApplyTierBonuses(item, state.tier)
                                    end
                                    print("ZItemTiers: [OnContainerUpdate] Applied tier " .. state.tier .. " to OnCreate-crafted item: " .. itemType)
                                else
                                    -- Debug: log why we didn't apply
                                    print("ZItemTiers: [OnContainerUpdate] Skipped item: " .. itemType .. " (isNewItem=" .. tostring(isNewItem) .. ", hasTier=" .. tostring(hasTier) .. ", currentTier=" .. tostring(currentTier) .. ", isCrafted=" .. tostring(isCrafted) .. ", isBlacklisted=" .. tostring(isBlacklisted) .. ")")
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
                        print("ZItemTiers: [OnContainerUpdate] No new items found without tier")
                    end
                end
                break  -- Found matching state, no need to check others
            end
        end
    end
end

-- Hook into OnContainerUpdate event (add our handler, don't replace existing ones)
Events.OnContainerUpdate.Add(onContainerUpdateForCrafting)

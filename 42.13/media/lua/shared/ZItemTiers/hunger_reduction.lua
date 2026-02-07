-- Hunger reduction bonus for edible items
-- Makes food items reduce hunger 20% more effectively per tier

require "ZItemTiers/core"

-- Get stored rarity and replaceOnUse from food item
local function getStoredRarityAndReplace(food, modData)
    if not modData or not modData.itemRarity then
        return nil, nil
    end
    
    local storedRarity = modData.itemRarity
    local storedReplaceOnUse = nil
    
    local successGetReplace, replaceOnUse = pcall(function()
        if food.getReplaceOnUse then
            return food:getReplaceOnUse()
        end
        return nil
    end)
    if successGetReplace and replaceOnUse then
        storedReplaceOnUse = replaceOnUse
    end
    
    return storedRarity, storedReplaceOnUse
end

-- Calculate and apply hunger reduction bonus
local function applyHungerBonus(food, modData, rarityData)
    local originalHungChange = modData.itemHungerChangeOriginal
    if originalHungChange >= 0.0 then
        return false
    end
    
    local tierIndex = rarityData.index
    local multiplier = 1.0 + (tierIndex - 1) * 0.2
    local modifiedHungerChange = originalHungChange * multiplier
    
    local successSet = pcall(function()
        if food.setHungChange then
            food:setHungChange(modifiedHungerChange)
        end
        if food.setBaseHunger then
            food:setBaseHunger(modifiedHungerChange)
        end
    end)
    
    return successSet
end

-- Check if item still exists in inventory
local function checkItemStillExists(character, inventoryItem)
    local inventory = character:getInventory()
    if not inventory then
        return false
    end
    
    local successContains, contains = pcall(function()
        if inventory.contains then
            return inventory:contains(inventoryItem)
        end
        return false
    end)
    
    return successContains and contains or false
end

-- Find replacement item in inventory and apply rarity (immediate check)
local function findAndApplyRarityToReplacement(character, storedReplaceOnUse, storedRarity)
    local inventory = character:getInventory()
    if not inventory then
        return false
    end
    
    local successGetItems, items = pcall(function()
        if inventory.getItems then
            return inventory:getItems()
        end
        return nil
    end)
    
    if not successGetItems or not items then
        return false
    end
    
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            local successType, itemType = pcall(function()
                return item:getFullType()
            end)
            
            if successType and itemType == storedReplaceOnUse then
                local itemModData = item:getModData()
                if itemModData and (not itemModData.itemRarity or itemModData.itemRarity == "Common") then
                    itemModData.itemRarity = storedRarity
                    if ZItemTiers and ZItemTiers.ApplyRarityBonuses then
                        ZItemTiers.ApplyRarityBonuses(item, storedRarity)
                    end
                    return true
                end
            end
        end
    end
    
    return false
end

-- Find replacement item using OnTick (delayed check)
local function findReplacementWithOnTick(character, storedReplaceOnUse, storedRarity)
    local ticksWaited = 0
    Events.OnTick.Add(function()
        ticksWaited = ticksWaited + 1
        
        if findAndApplyRarityToReplacement(character, storedReplaceOnUse, storedRarity) then
            return false
        end
        
        if ticksWaited >= 5 then
            return false
        end
        return true
    end)
end

-- Preserve rarity on replacement item after eating
local function preserveRarityOnReplacement(character, inventoryItem, storedRarity, storedReplaceOnUse)
    if not storedRarity or not storedReplaceOnUse then
        return
    end
    
    if checkItemStillExists(character, inventoryItem) then
        return
    end
    
    if not findAndApplyRarityToReplacement(character, storedReplaceOnUse, storedRarity) then
        findReplacementWithOnTick(character, storedReplaceOnUse, storedRarity)
    end
end

-- Hook into IsoGameCharacter:Eat to apply hunger reduction bonus and preserve rarity on replacement items
if IsoGameCharacter and IsoGameCharacter.Eat then
    local originalEat = IsoGameCharacter.Eat
    function IsoGameCharacter:Eat(inventoryItem, percentage, useUtensil)
        if not inventoryItem or not instanceof(inventoryItem, "Food") then
            return originalEat(self, inventoryItem, percentage, useUtensil)
        end
        
        local food = inventoryItem
        local modData = inventoryItem:getModData()
        if not modData then
            return originalEat(self, inventoryItem, percentage, useUtensil)
        end
        
        local storedRarity, storedReplaceOnUse = getStoredRarityAndReplace(food, modData)
            
        -- Check if this food has rarity and stored original hunger value
        if modData.itemRarity and modData.itemHungerChangeOriginal then
            local rarity = modData.itemRarity
            local rarityData = ZItemTiers.Rarities[rarity]
            
            if rarityData and applyHungerBonus(food, modData, rarityData) then
                local result = originalEat(self, inventoryItem, percentage, useUtensil)
                preserveRarityOnReplacement(self, inventoryItem, storedRarity, storedReplaceOnUse)
                return result
            end
        end
        
        -- No bonus, call original method
        return originalEat(self, inventoryItem, percentage, useUtensil)
    end
    
    print("ZItemTiers: Hooked IsoGameCharacter:Eat for hunger reduction bonus")
end

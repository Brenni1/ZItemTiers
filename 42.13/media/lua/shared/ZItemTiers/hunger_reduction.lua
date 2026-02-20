-- Hunger reduction bonus for edible items
-- Makes food items reduce hunger 20% more effectively per tier

require "ZItemTiers/core"

-- Get stored tier and replaceOnUse from food item
local function getStoredTierAndReplace(food, modData)
    if not modData or not modData.itemTier then
        return nil, nil
    end
    
    local storedTier = modData.itemTier
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
    
    return storedTier, storedReplaceOnUse
end

-- Calculate and apply hunger reduction bonus
local function applyHungerBonus(food, modData, tierData)
    local originalHungChange = modData.itemHungerChangeOriginal
    if originalHungChange >= 0.0 then
        return false
    end
    
    local tierIndex = tierData.index
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

-- Find replacement item in inventory and apply tier (immediate check)
local function findAndApplyTierToReplacement(character, storedReplaceOnUse, storedTier)
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
                if itemModData and (not itemModData.itemTier or itemModData.itemTier == "Common") then
                    itemModData.itemTier = storedTier
                    if ZItemTiers and ZItemTiers.ApplyTierBonuses then
                        ZItemTiers.ApplyTierBonuses(item, storedTier)
                    end
                    return true
                end
            end
        end
    end
    
    return false
end

-- Find replacement item using OnTick (delayed check)
local function findReplacementWithOnTick(character, storedReplaceOnUse, storedTier)
    local ticksWaited = 0
    Events.OnTick.Add(function()
        ticksWaited = ticksWaited + 1
        
        if findAndApplyTierToReplacement(character, storedReplaceOnUse, storedTier) then
            return false
        end
        
        if ticksWaited >= 5 then
            return false
        end
        return true
    end)
end

-- Preserve tier on replacement item after eating
local function preserveTierOnReplacement(character, inventoryItem, storedTier, storedReplaceOnUse)
    if not storedTier or not storedReplaceOnUse then
        return
    end
    
    if checkItemStillExists(character, inventoryItem) then
        return
    end
    
    if not findAndApplyTierToReplacement(character, storedReplaceOnUse, storedTier) then
        findReplacementWithOnTick(character, storedReplaceOnUse, storedTier)
    end
end

-- Hook into IsoGameCharacter:Eat to apply hunger reduction bonus and preserve tier on replacement items
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
        
        local storedTier, storedReplaceOnUse = getStoredTierAndReplace(food, modData)
            
        -- Check if this food has tier and stored original hunger value
        if modData.itemTier and modData.itemHungerChangeOriginal then
            local tier = modData.itemTier
            local tierData = ZItemTiers.Tiers[tier]
            
            if tierData and applyHungerBonus(food, modData, tierData) then
                local result = originalEat(self, inventoryItem, percentage, useUtensil)
                preserveTierOnReplacement(self, inventoryItem, storedTier, storedReplaceOnUse)
                return result
            end
        end
        
        -- No bonus, call original method
        return originalEat(self, inventoryItem, percentage, useUtensil)
    end
    
    print("ZItemTiers: Hooked IsoGameCharacter:Eat for hunger reduction bonus")
end

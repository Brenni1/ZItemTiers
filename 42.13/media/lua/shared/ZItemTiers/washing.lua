-- Preserve tier when washing items that get replaced (e.g., dirty rags -> clean rags)

require "ZItemTiers/core"

-- Hook into ISWashClothing:complete() to preserve tier when items are replaced
local function setupWashingHook()
    local ISWashClothing = ISWashClothing
    if not ISWashClothing then
        return
    end
    
    local originalComplete = ISWashClothing.complete
    if not originalComplete then
        return
    end
    
    function ISWashClothing:complete()
        local item = self.item
        local character = self.character
        
        -- Check if this item will be replaced (has getItemAfterCleaning)
        local willBeReplaced = false
        local storedTier = nil
        local storedReplaceOnUse = nil
        
        if item then
            local successGetReplace, replaceOnUse = pcall(function()
                if item.getItemAfterCleaning then
                    return item:getItemAfterCleaning()
                end
                return nil
            end)
            
            if successGetReplace and replaceOnUse then
                willBeReplaced = true
                local modData = item:getModData()
                if modData and modData.itemTier then
                    storedTier = modData.itemTier
                    storedReplaceOnUse = replaceOnUse
                end
            end
        end
        
        -- Call original complete function
        local result = originalComplete(self)
        
        -- Helper function to find and apply tier to replacement item
        local function findAndApplyTier()
            if not character then
                return false
            end
            
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
            
            local successSize, size = pcall(function()
                if items.size then
                    return items:size()
                end
                return 0
            end)
            
            if not successSize or not size then
                return false
            end
            
            -- Find the newly created item (matching the replacement type, no tier or Common)
            for i = 0, size - 1 do
                local successGet, newItem = pcall(function()
                    if items.get then
                        return items:get(i)
                    end
                    return nil
                end)
                
                if successGet and newItem then
                    local successGetType, itemType = pcall(function()
                        if newItem.getFullType then
                            return newItem:getFullType()
                        end
                        return nil
                    end)
                    
                    if successGetType and itemType == storedReplaceOnUse then
                        local newModData = newItem:getModData()
                        if newModData then
                            local currentTier = newModData.itemTier
                            -- Apply tier if item doesn't have it yet, or if it's Common (spawn_hooks might have set it)
                            if not currentTier or currentTier == "Common" then
                                newModData.itemTier = storedTier
                                newModData.craftedFromTier = true
                                
                                -- Apply the tier bonuses
                                if ZItemTiers and ZItemTiers.ApplyTierBonuses then
                                    ZItemTiers.ApplyTierBonuses(newItem, storedTier)
                                end
                                
                                print("ZItemTiers: [Washing] Preserved tier " .. storedTier .. " for washed item: " .. itemType)
                                return true
                            end
                        end
                    end
                end
            end
            
            return false
        end
        
        -- If item was replaced, find the new item and apply tier
        if willBeReplaced and storedTier and storedReplaceOnUse then
            -- Try immediately first
            if not findAndApplyTier() then
                -- If not found, use OnTick fallback (item might not be added yet)
                local ticks = 0
                Events.OnTick.Add(function()
                    ticks = ticks + 1
                    if findAndApplyTier() then
                        return false  -- Remove this event handler
                    end
                    -- Give up after 10 ticks
                    if ticks >= 10 then
                        return false  -- Remove this event handler
                    end
                    return true
                end)
            end
        end
        
        return result
    end
end

-- Initialize the hook
Events.OnGameBoot.Add(function()
    setupWashingHook()
end)

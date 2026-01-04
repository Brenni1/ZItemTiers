-- CleanUI mod integration for inventory item name coloring
-- Hooks into CleanUI_getItemNameColor() to return rarity colors
-- Uses ISInventoryItem.renderItemIcon() hook to set item context before getItemNameColor is called
--
-- NOTE TO CLEANUI AUTHOR:
-- It would be much better if CleanUI_getItemNameColor() could accept an item parameter,
-- e.g. CleanUI_getItemNameColor(item), instead of requiring mods to use workarounds like
-- hooking into renderItemIcon() to set a global context variable. This would make the
-- API more reliable and easier to use for modders.

require "ZItemTiers/core"

-- Initialize current item variable (set by isUnwanted hook)
if not ZItemTiers._cleanui_currentItem then
    ZItemTiers._cleanui_currentItem = nil
end

-- Check if CleanUI mod is active
local hasCleanUI = false
local successCleanUI, resultCleanUI = pcall(function()
    if _G and _G.CleanUI_getItemNameColor then
        hasCleanUI = true
        return true
    end
    return false
end)

if hasCleanUI and _G and _G.CleanUI_getItemNameColor then
    -- Hook into CleanUI_getItemNameColor to return rarity colors
    local originalCleanUI_getItemNameColor = _G.CleanUI_getItemNameColor
    if originalCleanUI_getItemNameColor then
        function _G.CleanUI_getItemNameColor()
            -- Get the current item from context (set by isUnwanted hook)
            local currentItem = ZItemTiers._cleanui_currentItem
            
            if currentItem then
                -- Check if item has rarity
                local rarity = ZItemTiers.GetItemRarity(currentItem)
                
                if rarity and ZItemTiers and ZItemTiers.Rarities and ZItemTiers.Rarities[rarity] then
                    local rarityData = ZItemTiers.Rarities[rarity]
                    local color = rarityData.color
                    
                    -- Return rarity color (only if not Common, since Common is white like default)
                    if rarity ~= "Common" then
                        return {r = color.r, g = color.g, b = color.b}
                    end
                end
            end
            
            -- Fall back to original CleanUI color
            return originalCleanUI_getItemNameColor()
        end
    end
    
    -- Hook into ISInventoryItem.renderItemIcon() to set context before getItemNameColor is called
    -- CleanUI calls renderItemIcon() on line 2589 with the item as a parameter
    -- This is called before getItemNameColor() on line 2790, so we can set the context here
    if not ISInventoryItem._zItemTiers_cleanui_renderItemIcon_hooked then
        ISInventoryItem._zItemTiers_cleanui_renderItemIcon_hooked = true
        
        -- Store original renderItemIcon
        local originalRenderItemIcon = ISInventoryItem.renderItemIcon
        
        -- Override renderItemIcon to set context
        ISInventoryItem.renderItemIcon = function(self, item, x, y, alpha, width, height)
            -- Set this item as the current item (will be used by getItemNameColor)
            if item then
                ZItemTiers._cleanui_currentItem = item
            end
            
            -- Call original renderItemIcon
            if originalRenderItemIcon then
                return originalRenderItemIcon(self, item, x, y, alpha, width, height)
            end
        end
        
        print("ZItemTiers: Hooked ISInventoryItem.renderItemIcon for CleanUI integration")
    end
    
    -- Hook into ISInventoryPane:renderdetails to clear context
    if not ISInventoryPane._zItemTiers_cleanui_hooked then
        ISInventoryPane._zItemTiers_cleanui_hooked = true
        
        -- Store the original renderdetails
        local originalRenderDetails = ISInventoryPane.renderdetails
        
        -- Wrap renderdetails to clear context
        local wrappedRenderDetails = function(self, doDragged)
            -- Clear context at start
            ZItemTiers._cleanui_currentItem = nil
            
            -- Call original renderdetails (isUnwanted() will set context for each item)
            originalRenderDetails(self, doDragged)
            
            -- Clear context at end
            ZItemTiers._cleanui_currentItem = nil
        end
        
        -- Replace renderdetails with our wrapper
        ISInventoryPane.renderdetails = wrappedRenderDetails
    end
    
    -- Hook into refreshContainer to ungroup items with different rarities
    if not ISInventoryPane._zItemTiers_cleanui_refreshContainer_hooked then
        ISInventoryPane._zItemTiers_cleanui_refreshContainer_hooked = true
        
        -- Store the original refreshContainer
        local originalRefreshContainer = ISInventoryPane.refreshContainer
        
        -- Wrap refreshContainer to ungroup items with different rarities
        function ISInventoryPane:refreshContainer()
            -- Call original refreshContainer first
            originalRefreshContainer(self)
            
            -- After items are grouped, check for mixed rarities and ungroup them
            if self.itemslist then
                local playerObj = getSpecificPlayer(self.player)
                local newItemslist = {}
                
                for _, group in ipairs(self.itemslist) do
                    if group.items and #group.items > 0 then
                        -- Check if all items in this group have the same rarity
                        local rarities = {}
                        local itemsByRarity = {}
                        
                        -- CleanUI adds a duplicate first item at the end of refreshContainer
                        -- Since we hook after originalRefreshContainer, the duplicate should already be there
                        -- We need to check all items (including potential duplicates) and group by rarity
                        
                        -- Collect all unique items and their rarities
                        local seenItems = {}
                        for _, item in ipairs(group.items) do
                            if item then
                                -- Use item ID to avoid counting duplicates
                                local itemId = nil
                                local successId, id = pcall(function()
                                    if item.getID then
                                        return item:getID()
                                    end
                                    return nil
                                end)
                                if successId and id then
                                    itemId = id
                                end
                                
                                -- Only process each unique item once
                                if itemId and not seenItems[itemId] then
                                    seenItems[itemId] = true
                                    local rarity = ZItemTiers and ZItemTiers.GetItemRarity and ZItemTiers.GetItemRarity(item) or "Common"
                                    if not itemsByRarity[rarity] then
                                        itemsByRarity[rarity] = {}
                                        rarities[#rarities + 1] = rarity
                                    end
                                    table.insert(itemsByRarity[rarity], item)
                                elseif not itemId then
                                    -- Fallback: if we can't get ID, check by object reference
                                    local found = false
                                    for _, seenItem in pairs(seenItems) do
                                        if seenItem == item then
                                            found = true
                                            break
                                        end
                                    end
                                    if not found then
                                        seenItems[item] = true
                                        local rarity = ZItemTiers and ZItemTiers.GetItemRarity and ZItemTiers.GetItemRarity(item) or "Common"
                                        if not itemsByRarity[rarity] then
                                            itemsByRarity[rarity] = {}
                                            rarities[#rarities + 1] = rarity
                                        end
                                        table.insert(itemsByRarity[rarity], item)
                                    end
                                end
                            end
                        end
                        
                        -- If all items have the same rarity, keep the group as-is
                        if #rarities <= 1 then
                            table.insert(newItemslist, group)
                        else
                            -- Items have different rarities - split into separate groups
                            for _, rarity in ipairs(rarities) do
                                local rarityItems = itemsByRarity[rarity]
                                if rarityItems and #rarityItems > 0 then
                                    -- Create a new group for this rarity
                                    local newGroup = {}
                                    newGroup.items = {}
                                    
                                    -- Add the first item of THIS rarity as duplicate (CleanUI uses this for title/display)
                                    -- This ensures each rarity group shows the correct rarity in the title
                                    if #rarityItems > 0 then
                                        table.insert(newGroup.items, rarityItems[1])
                                    end
                                    
                                    -- Add all items of this rarity
                                    for _, item in ipairs(rarityItems) do
                                        table.insert(newGroup.items, item)
                                    end
                                    
                                    newGroup.count = #newGroup.items
                                    newGroup.invPanel = group.invPanel
                                    
                                    -- Recalculate name from the first item of this rarity group using the same logic as CleanUI
                                    -- This ensures each rarity group shows the correct item name
                                    if #newGroup.items > 0 and newGroup.items[1] and playerObj then
                                        local itemName = newGroup.items[1]:getName(playerObj)
                                        
                                        -- Apply the same prefixes that CleanUI uses (equipped, keyring, hotbar)
                                        if group.equipped then
                                            if string.find(itemName, "^equipped:") == nil and
                                               string.find(itemName, "^keyring:") == nil then
                                                itemName = "equipped:" .. itemName
                                            end
                                        end
                                        if group.inHotbar and not group.equipped then
                                            if string.find(itemName, "^hotbar:") == nil then
                                                itemName = "hotbar:" .. itemName
                                            end
                                        end
                                        
                                        newGroup.name = itemName
                                    else
                                        newGroup.name = group.name  -- Fallback to original name
                                    end
                                    
                                    newGroup.cat = group.cat
                                    newGroup.equipped = group.equipped
                                    newGroup.inHotbar = group.inHotbar
                                    newGroup.matchesSearch = group.matchesSearch
                                    
                                    -- Calculate weight for this rarity group
                                    local weight = 0
                                    for _, item in ipairs(rarityItems) do
                                        if item then
                                            weight = weight + item:getUnequippedWeight()
                                        end
                                    end
                                    newGroup.weight = weight
                                    
                                    -- Copy collapsed state (use the new name for the key)
                                    if self.collapsed then
                                        if self.collapsed[newGroup.name] == nil then
                                            self.collapsed[newGroup.name] = true
                                        end
                                    end
                                    
                                    table.insert(newItemslist, newGroup)
                                end
                            end
                        end
                    else
                        -- Group has no items or is a separator, keep as-is
                        table.insert(newItemslist, group)
                    end
                end
                
                -- Replace itemslist with the ungrouped version
                self.itemslist = newItemslist
            end
        end
        
        print("ZItemTiers: Hooked ISInventoryPane.refreshContainer for CleanUI rarity ungrouping")
    end
end

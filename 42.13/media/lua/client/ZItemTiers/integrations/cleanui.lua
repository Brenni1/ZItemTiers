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
end

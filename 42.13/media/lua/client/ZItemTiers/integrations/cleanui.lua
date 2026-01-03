-- CleanUI mod integration for inventory item name coloring
-- Hooks into CleanUI_getItemNameColor() to return rarity colors

require "ZItemTiers/core"

-- Initialize context variable
if not ZItemTiers._currentRenderingItem then
    ZItemTiers._currentRenderingItem = nil
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
            -- Get the current item from the rendering context
            local currentItem = ZItemTiers._currentRenderingItem
            if currentItem then
                -- Check if item has rarity
                local modData = currentItem:getModData()
                if modData and modData.itemRarity then
                    local rarity = modData.itemRarity
                    if ZItemTiers and ZItemTiers.Rarities and ZItemTiers.Rarities[rarity] then
                        local rarityData = ZItemTiers.Rarities[rarity]
                        local color = rarityData.color
                        -- Return rarity color
                        return {r = color.r, g = color.g, b = color.b}
                    end
                end
            end
            
            -- Fall back to original CleanUI color
            return originalCleanUI_getItemNameColor()
        end
        print("ZItemTiers: Hooked into CleanUI_getItemNameColor for rarity colors")
    end
    
    -- Hook into InventoryItem:getName() to set context before CleanUI_getItemNameColor is called
    -- The vanilla code calls item:getName() in the rendering loop, then CleanUI calls getItemNameColor()
    -- So if we hook getName() and set context there, CleanUI will see it
    if not InventoryItem._zItemTiers_cleanui_getName_hooked then
        InventoryItem._zItemTiers_cleanui_getName_hooked = true
        
        local originalGetName = InventoryItem.getName
        function InventoryItem:getName(player)
            -- Set this item as the current rendering item
            -- This will be available when CleanUI calls getItemNameColor()
            ZItemTiers._currentRenderingItem = self
            
            -- Call original getName
            local result = originalGetName(self, player)
            
            -- Note: We don't clear _currentRenderingItem here because CleanUI might call
            -- getItemNameColor() after getName() returns. We'll clear it in renderdetails.
            
            return result
        end
        
        print("ZItemTiers: Hooked into InventoryItem.getName for CleanUI integration")
    end
    
    -- Hook into ISInventoryPane:renderdetails to clear context after rendering
    if not ISInventoryPane._zItemTiers_cleanui_hooked then
        ISInventoryPane._zItemTiers_cleanui_hooked = true
        
        -- Store the original renderdetails if not already stored by inventory.lua
        if not ISInventoryPane._zItemTiers_originalRenderDetails then
            ISInventoryPane._zItemTiers_originalRenderDetails = ISInventoryPane.renderdetails
        end
        
        local originalRenderDetails = ISInventoryPane._zItemTiers_originalRenderDetails
        
        -- Wrap renderdetails to clear context after rendering
        local wrappedRenderDetails = function(self, doDragged)
            -- Clear context at start of render
            ZItemTiers._currentRenderingItem = nil
            
            -- Call original renderdetails
            originalRenderDetails(self, doDragged)
            
            -- Clear context at end of render
            ZItemTiers._currentRenderingItem = nil
        end
        
        -- Only wrap if not already wrapped by inventory.lua
        if ISInventoryPane.renderdetails == originalRenderDetails then
            ISInventoryPane.renderdetails = wrappedRenderDetails
        end
        
        print("ZItemTiers: Hooked into ISInventoryPane.renderdetails for CleanUI integration")
    end
end

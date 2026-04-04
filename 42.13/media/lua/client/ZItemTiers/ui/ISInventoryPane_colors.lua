-- now works with CleanUI as well

zdk.hook({
    -- Hook into ISInventoryItem.renderItemIcon() to set context before getItemNameColor is called
    -- CleanUI calls renderItemIcon() on line 2589 with the item as a parameter
    -- This is called before getItemNameColor() on line 2790, so we can set the context here
    ISInventoryItem = {
        renderItemIcon = function(orig, self, item, ...)
            -- Set this item as the current item (will be used by getItemNameColor)
            if item then
                ZItemTiers._zit_currentItem = item
            end

            -- Call original renderItemIcon
            return orig(self, item, ...)
        end,
    },

    ISInventoryPane = {
        renderdetails = function(orig, self, ...)
            ZItemTiers._zit_currentItem = nil
            local result = orig(self, ...)
            ZItemTiers._zit_currentItem = nil
            return result
        end,

        drawText = function(orig, self, text, x, y, r, g, b, ...)
            if ZItemTiers._zit_currentItem then
                local item = ZItemTiers._zit_currentItem
                local tier = ZItemTiers.GetItemTierKey(item)
                if tier and tier ~= "Common" then
                    local tierData = ZItemTiers.Tiers[tier]
                    r, g, b = tierData.color.r, tierData.color.g, tierData.color.b
                end
            end
            return orig(self, text, x, y, r, g, b, ...)
        end,
    },
})

-- Hook into ISInventoryPage:setNewContainer to trigger processing of world items when loot window opens for ground items
--local originalSetNewContainer = ISInventoryPage.setNewContainer
--if originalSetNewContainer then
--    function ISInventoryPage:setNewContainer(inventory)
--        local result = originalSetNewContainer(self, inventory)
--        
--        -- Check if this is the floor container (world items on the ground)
--        if inventory and inventory:getType() == "floor" then
--            if LuaEventManager then
--                LuaEventManager.triggerEvent("OnContainerUpdate", inventory)
--            end
--        end
--        
--        return result
--    end
--end

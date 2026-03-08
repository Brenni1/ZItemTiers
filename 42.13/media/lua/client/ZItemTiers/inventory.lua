-- Inventory display for item tier
-- Changes item text color in inventory panes based on tier (without affecting icons)
-- Supports CleanUI mod (if CleanUI is active, it handles coloring, so we skip this)

require "ZItemTiers/core"

-- Check if CleanUI is active - if so, skip this hook (CleanUI handles it)
local hasCleanUI = _G and _G.CleanUI_getItemNameColor ~= nil

-- Only hook if CleanUI is not active
if not hasCleanUI then
    zbHook({
        ISInventoryPane = {
            renderdetails = function(orig, self, doDragged, ...)
                -- Build item color map for this render pass
                local itemColorMap = {}
                if self.items then
                    for _, v in ipairs(self.items) do
                        if v and v.item then
                            local item = v.item
                            -- Check if item has tier
                            local tier = ZItemTiers.GetItemTierKey(item)
                            if tier and tier ~= "Common" and ZItemTiers and ZItemTiers.Tiers[tier] then
                                local tierData = ZItemTiers.Tiers[tier]
                                local color = tierData.color
                                
                                local itemName = item:getName(getSpecificPlayer(self.player))
                                -- Map both the item name and the item object
                                itemColorMap[itemName] = {r = color.r, g = color.g, b = color.b}
                                if v.count > 2 then
                                    itemColorMap[itemName .. " (" .. (v.count - 1) .. ")"] = {r = color.r, g = color.g, b = color.b}
                                end
                            end
                        end
                    end
                end
                
                -- Store color map for use in drawText override
                self._zItemTiers_colorMap = itemColorMap
                
                -- Override drawText temporarily for this render pass
                if not self._zItemTiers_originalDrawText then
                    self._zItemTiers_originalDrawText = self.drawText
                end
                
                -- TODO: refactor
                local selfRef = self
                local originalDrawText = self._zItemTiers_originalDrawText
                self.drawText = function(self, text, x, y, r, g, b, a, font)
                    -- Check if this text matches an item name with tier
                    if selfRef._zItemTiers_colorMap and selfRef._zItemTiers_colorMap[text] then
                        local color = selfRef._zItemTiers_colorMap[text]
                        r, g, b = color.r, color.g, color.b
                    end
                    return originalDrawText(selfRef, text, x, y, r, g, b, a, font)
                end
                
                -- Call original renderdetails
                orig(self, doDragged, ...)
                
                -- Restore original drawText
                self.drawText = self._zItemTiers_originalDrawText
                
                -- Clear color map
                self._zItemTiers_colorMap = nil
            end
        }
    })
end

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

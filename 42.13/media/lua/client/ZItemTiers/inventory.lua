-- Inventory display for item rarity
-- Changes item text color in inventory panes based on rarity (without affecting icons)
-- Supports CleanUI mod

require "ZItemTiers/core"

-- Helper function to check if item has scalable properties
local function hasScalableProperties(item)
    -- Check each bonus type using its checkApplicable function
    if ZItemTiers and ZItemTiers.Bonuses then
        for bonusType, bonusData in pairs(ZItemTiers.Bonuses) do
            if bonusData.checkApplicable then
                local success, isApplicable = pcall(bonusData.checkApplicable, item)
                if success and isApplicable then
                    return true
                end
            end
        end
    end
    return false
end

-- Hook into ISInventoryPane:renderdetails to modify text color based on rarity
-- This works with CleanUI mod by hooking at the right level
-- We override drawText to change text color for item names without affecting icons
if not ISInventoryPane._zItemTiers_hooked then
    ISInventoryPane._zItemTiers_hooked = true
    
    -- Store original renderdetails
    local originalRenderDetails = ISInventoryPane.renderdetails
    function ISInventoryPane:renderdetails(doDragged)
        -- Build item color map for this render pass
        local itemColorMap = {}
        if self.items then
            for _, v in ipairs(self.items) do
                if v and v.item then
                    local item = v.item
                    if hasScalableProperties(item) then
                        local modData = item:getModData()
                        if modData then
                            local rarity = modData.itemRarity or "Common"
                            if ZItemTiers and ZItemTiers.Rarities[rarity] then
                                local rarityData = ZItemTiers.Rarities[rarity]
                                local color = rarityData.color
                                
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
            end
        end
        
        -- Store color map for use in drawText override
        self._zItemTiers_colorMap = itemColorMap
        
        -- Override drawText temporarily for this render pass
        if not self._zItemTiers_originalDrawText then
            self._zItemTiers_originalDrawText = self.drawText
        end
        
        local selfRef = self
        local originalDrawText = self._zItemTiers_originalDrawText
        self.drawText = function(self, text, x, y, r, g, b, a, font)
            -- Check if this text matches an item name with rarity
            if selfRef._zItemTiers_colorMap and selfRef._zItemTiers_colorMap[text] then
                local color = selfRef._zItemTiers_colorMap[text]
                r, g, b = color.r, color.g, color.b
            end
            return originalDrawText(selfRef, text, x, y, r, g, b, a, font)
        end
        
        -- Call original renderdetails
        originalRenderDetails(self, doDragged)
        
        -- Restore original drawText
        self.drawText = self._zItemTiers_originalDrawText
        
        -- Clear color map
        self._zItemTiers_colorMap = nil
    end
end

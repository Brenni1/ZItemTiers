-- Tooltip display for item rarity and bonuses
-- Core functionality works without Starlit Library or BetterClothingInfo

require "ZItemTiers/core"

-- Helper function to check if item has rarity
local function hasRarity(item)
    if not item then return false end
    
    local modData = item:getModData()
    if modData and modData.itemRarity then
        return true
    end
    
    return false
end

-- Helper function to add rarity information to a tooltip layout
-- Shows rarity for all items that have been assigned a rarity
-- This function is exposed to integration modules via ZItemTiers.addRarityToLayout
local function addRarityToLayout(item, layout)
    if not item or not layout then 
        return 
    end
    
    -- Get rarity and bonuses from item
    local rarity = ZItemTiers.GetItemRarity(item)
    local itemBonuses = ZItemTiers.GetItemBonuses(item)
    
    if ZItemTiers and ZItemTiers.Rarities[rarity] then
        local rarityData = ZItemTiers.Rarities[rarity]
        local color = rarityData.color
        
        -- Add rarity row to tooltip (formatted as key:value pair)
        if layout and layout.addItem then
            local rarityItem = layout:addItem()
            if rarityItem then
                if rarityItem.setLabel then
                    rarityItem:setLabel("Rarity:", color.r, color.g, color.b, 1.0)  -- Rarity color for label
                end
                if rarityItem.setValue then
                    rarityItem:setValue(rarityData.name, color.r, color.g, color.b, 1.0)  -- Rarity color for value
                end
            end
        end
        
        -- Build bonuses text from fixed bonuses
        local bonusTexts = {}
        for _, bonus in ipairs(itemBonuses) do
            local bonusName = ZItemTiers.GetBonusDisplayName(bonus.type)
            if bonus.value then
                table.insert(bonusTexts, "+" .. bonus.value .. "% " .. bonusName)
            end
        end
        
        -- Add bonuses if we have any
        if #bonusTexts > 0 and layout and layout.addItem then
            local bonusItem = layout:addItem()
            if bonusItem and bonusItem.setLabel then
                local bonusText = table.concat(bonusTexts, ", ")
                bonusItem:setLabel("Bonuses: " .. bonusText, color.r, color.g, color.b, 1.0)
            end
        end
    end
end

-- Expose addRarityToLayout to integration modules
ZItemTiers.addRarityToLayout = addRarityToLayout

-- Function to add rarity information to a tooltip layout
-- This can be called from both Lua (Starlit Library) and Java (patch)
function ZItemTiers.AddRarityToTooltip(item, tooltipUI, layout)
    -- If layout is nil, try to get it from tooltipUI or create a new one
    if not layout and tooltipUI then
        if tooltipUI.beginLayout then
            layout = tooltipUI:beginLayout()
            if layout then
                layout:setMinLabelWidth(80)
            end
        end
    end
    
    if not layout then
        return  -- Can't add rarity without a layout
    end
    
    addRarityToLayout(item, layout)
    
    -- If we created a new layout, we need to render it
    -- This is handled by the Java patch for DoTooltipEmbedded
    -- For Clothing.DoTooltip, the layout is already part of the tooltip flow
end

-- Load integration modules
require "ZItemTiers/integrations/starlit"
require "ZItemTiers/integrations/betterclothinginfo"
require "ZItemTiers/integrations/cleanui"

-- Check if BetterClothingInfo integration was successful
-- If not, fall back to ISToolTipInv:render hook
if not (ZItemTiers and ZItemTiers.BetterClothingInfoActive) then
    -- BetterClothingInfo is not active - use ISToolTipInv:render hook
    local originalISToolTipInvRender = ISToolTipInv.render
    if originalISToolTipInvRender then
        function ISToolTipInv:render()
            -- Call the original render first (this preserves other mods)
            originalISToolTipInvRender(self)
            
            -- After the original render is complete, append our rarity info
            -- Only add if item has rarity and we're not in a context menu
            if self.item and (not ISContextMenu.instance or not ISContextMenu.instance.visibleCheck) then
                -- Check if item has rarity
                if hasRarity(self.item) then
                    -- Get the current tooltip height to know where to append
                    local currentHeight = self.tooltip:getHeight()
                    
                    -- Create a new layout section for our rarity info
                    local layout = self.tooltip:beginLayout()
                    if layout then
                        layout:setMinLabelWidth(80)
                        -- Add our rarity info to this new layout
                        if ZItemTiers and ZItemTiers.addRarityToLayout then
                            ZItemTiers.addRarityToLayout(self.item, layout)
                        end
                        -- Render this layout section starting from the current height
                        local startY = currentHeight > 0 and (currentHeight - self.tooltip.padBottom) or self.tooltip.padTop
                        local y3 = layout:render(self.tooltip.padLeft, startY, self.tooltip)
                        self.tooltip:endLayout(layout)
                        -- Update tooltip height to include our new section
                        self.tooltip:setHeight(y3 + self.tooltip.padBottom)
                        -- Update tooltip width if needed
                        if self.tooltip:getWidth() < 150 then
                            self.tooltip:setWidth(150)
                        end
                        -- Update the ISToolTipInv panel dimensions to match
                        local tw = self.tooltip:getWidth()
                        local th = self.tooltip:getHeight()
                        self:setWidth(tw)
                        self:setHeight(th)
                    end
                end
            end
        end
        print("ZItemTiers: Hooked into ISToolTipInv:render to append rarity info")
    end
end

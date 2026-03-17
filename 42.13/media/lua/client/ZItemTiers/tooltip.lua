-- Tooltip display for item tier and bonuses
-- Core functionality works without Starlit Library or BetterClothingInfo

require "ZItemTiers/core"

-- Helper function to check if item has tier
local function hasTier(item)
    if not item then return false end
    
    local zit = ZItemTiers.GetOrCreateZIT(item)
    return zit.itemTier ~= nil and zit.itemTier ~= "Common"
end

-- Helper function to add tier information to a tooltip layout
-- Shows tier for all items that have been assigned a tier
-- This function is exposed to integration modules via ZItemTiers.addTierToLayout
local function addTierToLayout(item, layout)
    if not item or not layout then 
        return 
    end
    
    -- Get tier and bonuses from item
    local tier = ZItemTiers.GetItemTierKey(item)
    local itemBonuses = ZItemTiers.GetItemBonuses(item)
    
    if ZItemTiers and ZItemTiers.Tiers[tier] then
        local tierData = ZItemTiers.Tiers[tier]
        local color = tierData.color
        
        -- Add tier row to tooltip (formatted as key:value pair)
        if layout and layout.addItem then
            local tierItem = layout:addItem()
            if tierItem then
                if tierItem.setLabel then
                    tierItem:setLabel("Tier:", color.r, color.g, color.b, 1.0)  -- Tier color for label
                end
                if tierItem.setValue then
                    tierItem:setValue(tierData.name, color.r, color.g, color.b, 1.0)  -- Tier color for value
                end
            end
        end
        
        -- Add each bonus on its own row with empty label
        -- Each bonus row shows just the bonus text on the right (e.g., "+20% Damage")
        for _, bonus in ipairs(itemBonuses) do
            local bonusName = ZItemTiers.GetBonusDisplayName(bonus.type)
            if bonus.value and layout and layout.addItem then
                -- Format bonus text based on bonus type
                local bonusText = ""
                if bonus.type == "RunSpeedModifier" or bonus.type == "VisionImpairmentReduction" or bonus.type == "HearingImpairmentReduction" then
                    -- These are already formatted with decimal places (e.g., "0.1")
                    bonusText = "+" .. bonus.value .. " " .. bonusName
                        elseif bonus.type == "EncumbranceReduction" or bonus.type == "MaxEncumbranceBonus" or bonus.type == "BiteDefenseBonus" or bonus.type == "ScratchDefenseBonus" or bonus.type == "VhsSkillXpBonus" then
                            -- These are flat values, no % sign (e.g., "+5 Bite Defense", "+50 Skill XP Bonus")
                            bonusText = "+" .. bonus.value .. " " .. bonusName
                        elseif bonus.type == "MoodBonus" or bonus.type == "ReadingSpeedBonus" then
                            -- Percentage bonuses (e.g., "+10% Mood Benefits", "+10% Reading Speed")
                            bonusText = "+" .. bonus.value .. "% " .. bonusName
                else
                    -- Percentage bonuses (e.g., "+20% Damage")
                    bonusText = "+" .. bonus.value .. "% " .. bonusName
                end
                
                -- Create a separate item for each bonus
                local bonusItem = layout:addItem()
                if bonusItem then
                    -- Empty label so only the value is shown on the right
                    if bonusItem.setLabel then
                        bonusItem:setLabel("", color.r, color.g, color.b, 1.0)
                    end
                    if bonusItem.setValue then
                        bonusItem:setValue(bonusText, color.r, color.g, color.b, 1.0)
                    end
                end
            end
        end
    end
end

-- Expose addTierToLayout to integration modules
ZItemTiers.addTierToLayout = addTierToLayout

-- Function to add tier information to a tooltip layout
-- This can be called from both Lua (Starlit Library) and Java (patch)
function ZItemTiers.AddTierToTooltip(item, tooltipUI, layout)
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
        return  -- Can't add tier without a layout
    end
    
    addTierToLayout(item, layout)
    
    -- If we created a new layout, we need to render it
    -- This is handled by the Java patch for DoTooltipEmbedded
    -- For Clothing.DoTooltip, the layout is already part of the tooltip flow
end

-- Load reading speed hook (shared, but ensure it's loaded on client)
require "ZItemTiers/reading_speed"

-- Load integration modules
require "ZItemTiers/integrations/starlit"
require "ZItemTiers/integrations/betterclothinginfo"
require "ZItemTiers/integrations/cleanui"
require "ZItemTiers/integrations/contextmenu"

if not ZItemTiers.BetterClothingInfoActive then
    -- BetterClothingInfo is not active - use ISToolTipInv:render hook
    zbHook({
        ISToolTipInv = {
            render = function(orig, self, ...)
                orig(self, ...)
            
                -- After the original render is complete, append our tier info
                -- Only add if item has tier and we're not in a context menu
                if self.item and (not ISContextMenu.instance or not ISContextMenu.instance.visibleCheck) then
                    -- Check if item has tier
                    if hasTier(self.item) then
                        -- Get the current tooltip height to know where to append
                        local currentHeight = self.tooltip:getHeight()
                        
                        -- Create a new layout section for our tier info
                        local layout = self.tooltip:beginLayout()
                        if layout then
                            layout:setMinLabelWidth(80)
                            -- Add our tier info to this new layout
                            if ZItemTiers and ZItemTiers.addTierToLayout then
                                ZItemTiers.addTierToLayout(self.item, layout)
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
            end -- render
        } -- ISToolTipInv
    }) -- zbHook
end -- if not BetterClothingInfoActive

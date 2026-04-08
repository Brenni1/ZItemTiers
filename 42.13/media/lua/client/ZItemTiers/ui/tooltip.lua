-- Tooltip display for item tier and bonuses

ZItemTiers.pad = ZItemTiers.pad or 15

-- Helper function to check if item has tier
local function hasTier(item)
    if not item then return false end
    
    local zit = ZItemTiers.GetOrCreateZIT(item)
    return zit.itemTier ~= nil and zit.itemTier ~= "Common"
end

-- Helper function to add tier information to a tooltip layout
-- Shows tier for all items that have been assigned a tier
-- This function is exposed to integration modules via ZItemTiers.addTierToLayout
function ZItemTiers.addTierToLayout(item, layout)
    if not item or not layout then 
        return 
    end
    
    -- Get tier and bonuses from item
    local tier = ZItemTiers.GetItemTierKey(item)
    local bonuses = ZItemTiers.GetItemShownBonuses(item)
    
    local tierData = ZItemTiers.Tiers[tier]
    local color = tierData.color
    
    -- tier row
    local tierItem = layout:addItem()
    tierItem:setLabel("Tier:",       color.r, color.g, color.b, 1.0)
    tierItem:setValue(tierData.name, color.r, color.g, color.b, 1.0)
    
    -- Add each bonus on its own row with empty label
    -- Each bonus row shows just the bonus text on the right (e.g., "+20% Damage")
    for bonusKey, bonus in pairs(bonuses) do
        local bonusName = ZItemTiers.GetBonusDisplayName(bonusKey)
        local bonusItem = layout:addItem()

        local delta = bonus.modified - bonus.base
        -- local bonusText = string.format("%+.2f %s", delta, bonusName)
        local bonusText = string.format("%s %+.2f", bonusName, delta)

        --bonusItem:setLabel(deltaText, color.r, color.g, color.b, 1.0)
        bonusItem:setValue(bonusText, color.r, color.g, color.b, 1.0)
    end
end

-- Function to add tier information to a tooltip layout
--function ZItemTiers.AddTierToTooltip(item, tooltipUI, layout)
--    -- If layout is nil, try to get it from tooltipUI or create a new one
--    if not layout and tooltipUI then
--        if tooltipUI.beginLayout then
--            layout = tooltipUI:beginLayout()
--            -- layout:setMinLabelWidth(80)
--        end
--    end
--    
--    -- Can't add tier without a layout
--    if not layout then return end
--    
--    ZItemTiers.addTierToLayout(item, layout)
--end

---- Load reading speed hook (shared, but ensure it's loaded on client)
--require "ZItemTiers/reading_speed"
--
---- Load integration modules
--require "ZItemTiers/integrations/betterclothinginfo"
--require "ZItemTiers/integrations/contextmenu"

--if ZItemTiers.BetterClothingInfoActive then return end
-- BetterClothingInfo is not active - use ISToolTipInv:render hook

local function table_size(t)
    local count = 0
    if t then
        for _ in pairs(t) do count = count + 1 end
    end
    return count
end

local function createTierLayout(tooltipObj, item)
    local layout = tooltipObj:beginLayout()
    --layout:setMinLabelWidth(110)
    ZItemTiers.addTierToLayout(item, layout)
    return layout
end

-- try to hook the last override of ISToolTipInv
Events.OnGameStart.Add(function()
    zdk.hook({
        ISToolTipInv = {
            render = function(orig, self)
                -- local padX = Math.max(TextManager.instance:MeasureStringX(self.tooltip:getFont(), "W"), 8) -- as in ObjectTooltip.java

                orig(self)
                if not self.item then return end

                local w0 = self:getWidth()
                local h0 = self:getHeight()

                local bonuses = ZItemTiers.GetItemShownBonuses(self.item)
                local h1 = (table_size(bonuses) + 1) * self.tooltip:getLineSpacing()

                self.tooltip:setMeasureOnly(true)
                local layout = createTierLayout(self.tooltip, self.item)
                local startX = ZItemTiers.pad
                local startY = h0
                layout:render(startX, startY, self.tooltip)
                self.tooltip:setMeasureOnly(false)

                local w1 = math.max(w0, self.tooltip:getWidth())
                -- local h1 = self.tooltip:getHeight() -- returns incorrect hieght for some reason

                self:drawRect      (0, h0, w1, h1, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
                self:drawRectBorder(0, h0, w1, h1, self.borderColor.a,     self.borderColor.r,     self.borderColor.g,     self.borderColor.b)

                layout:render(startX, startY, self.tooltip)
                self.tooltip:endLayout(layout)

                if self:getWidth() < w1 then
                    self:setWidth(w1)
                end
                if self:getHeight() < h0 + h1 then
                    self:setHeight(h0 + h1)
                end
            end,
        }
    })
end)

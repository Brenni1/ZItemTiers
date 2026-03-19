-- Tooltip display for item tier and bonuses

require "ZItemTiers/core"

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
    local bonuses = ZItemTiers.GetItemBonuses(item)
    
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
function ZItemTiers.AddTierToTooltip(item, tooltipUI, layout)
    -- If layout is nil, try to get it from tooltipUI or create a new one
    if not layout and tooltipUI then
        if tooltipUI.beginLayout then
            layout = tooltipUI:beginLayout()
            -- layout:setMinLabelWidth(80)
        end
    end
    
    -- Can't add tier without a layout
    if not layout then return end
    
    ZItemTiers.addTierToLayout(item, layout)
end

---- Load reading speed hook (shared, but ensure it's loaded on client)
--require "ZItemTiers/reading_speed"
--
---- Load integration modules
--require "ZItemTiers/integrations/betterclothinginfo"
--require "ZItemTiers/integrations/contextmenu"

--if ZItemTiers.BetterClothingInfoActive then return end
-- BetterClothingInfo is not active - use ISToolTipInv:render hook

local _addW = 0
local _addH = 0

local function table_size(t)
    local count = 0
    if t then
        for _ in pairs(t) do count = count + 1 end
    end
    return count
end

zbHook({
    ISToolTipInv = {
        new = function(orig, self, ...)
            local o = orig(self, ...)
            zbHook({
                [o.tooltip] = {
                    getWidth  = function(orig, self) return orig(self) + _addW end,
                    getHeight = function(orig, self) return orig(self) + _addH + 20 end,
                }})
            _G.gToolTipInv = o
            return o
        end,

        render = function(orig, self)
            if self.item then
                local bonuses = ZItemTiers.GetItemBonuses(self.item)
                _addW = 0; _addH = (table_size(bonuses) + 1) * self.tooltip:getLineSpacing()
            end

            orig(self)

            _addW = 0; _addH = 0
            local layout = self.tooltip:beginLayout()
            layout:setMinLabelWidth(110)
            ZItemTiers.addTierToLayout(self.item, layout)
            local startX = ZItemTiers.pad
            local startY = self.tooltip:getHeight() - ZItemTiers.pad
            layout:render(startX, startY, self.tooltip)
            self.tooltip:endLayout(layout)
        end,
    }
})

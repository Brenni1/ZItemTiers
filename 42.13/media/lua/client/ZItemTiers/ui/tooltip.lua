-- Tooltip display for item tier and bonuses

ZItemTiers.pad = ZItemTiers.pad or 15

local TRANSFORM_VALUES = {
    Insulation      = function(x) return x*100 end,
    HearingModifier = function(x) return -x end,
    VisionModifier  = function(x) return -x end,
    WaterResistance = function(x) return x*100 end,
    Windresistance  = function(x) return x*100 end,
}

-- Helper function to check if item has tier
local function hasTier(item)
    if not item then return false end
    
    local zit = ZItemTiers.GetOrCreateZIT(item)
    return zit.itemTier ~= nil and zit.itemTier ~= "Common"
end

local _i18n_cache = {}
local function getBonusDisplayName(bonusType)
    if _i18n_cache[bonusType] then return _i18n_cache[bonusType] end

    local bonus = ZItemTiers.Bonuses[bonusType]
    if bonus and bonus.tipKey then
        local result = getTextOrNull("Tooltip_" .. bonus.tipKey)
        if result then
            _i18n_cache[bonusType] = result
            return result
        end
    end

    -- "Tooltip_item_VisionImpariment":  "Vision Impairment",
    -- "Tooltip_item_HearingImpariment": "Hearing Impairment",
    if bonusType:contains("Modifier") then
        local result = (
            getTextOrNull("Tooltip_item_" .. bonusType:gsub("Modifier", "Impariment")) or
            getTextOrNull("Tooltip_item_" .. bonusType:gsub("Modifier", "Impairment"))
        )
        if result then
            _i18n_cache[bonusType] = result
            return result
        end
    end

    local result = (
        getTextOrNull("Tooltip_ZIT_Bonus_" .. bonusType) or
        getTextOrNull("Tooltip_" .. bonusType) or
        getTextOrNull("Tooltip_item_" .. bonusType) or
        getTextOrNull("Tooltip_item_" .. bonusType:gsub("Modifier", "")) or
        bonusType
    )
    _i18n_cache[bonusType] = result
    return result
end

-- Helper function to add tier information to a tooltip layout
-- Shows tier for all items that have been assigned a tier
-- This function is exposed to integration modules via ZItemTiers.addTierToLayout
function ZItemTiers.addTierToLayout(item, layout, font)
    if not item or not layout then 
        return 0
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
    local maxValueWidth = TextManager.instance:MeasureStringX(font, tierData.name)
    
    -- Add each bonus on its own row with empty label
    -- Each bonus row shows just the bonus text on the right (e.g., "+20% Damage")
    for bonusKey, bonus in pairs(bonuses) do
        local delta     = bonus.modified - bonus.base
        local abs_delta = math.abs(delta)

        local bonusName = getBonusDisplayName(bonusKey)
        if TRANSFORM_VALUES[bonusKey] then
            delta = TRANSFORM_VALUES[bonusKey](delta)
        end

        local bonusText = abs_delta >= 0.01 and string.format("%+.2f", delta) or string.format("%+.4f", delta)
        local bonusItem = layout:addItem()
        bonusItem:setLabel(bonusName, color.r, color.g, color.b, 1.0)
        bonusItem:setValue(bonusText, color.r, color.g, color.b, 1.0)
        maxValueWidth = math.max(maxValueWidth, TextManager.instance:MeasureStringX(font, bonusText))
        --bonusItem:setValueRight(delta, true)
        --bonusItem:setValueRightNoPlus(delta)
    end
    return maxValueWidth
end

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
    local layout        = tooltipObj:beginLayout()
    local font          = tooltipObj:getFont()
    local maxValueWidth = ZItemTiers.addTierToLayout(item, layout, font)

    local padX = Math.max(TextManager.instance:MeasureStringX(font, "W"), 8) -- as in ObjectTooltip.java
    local minLabelWidth = tooltipObj:getWidth() - ZItemTiers.pad * 2 - maxValueWidth - padX
    layout:setMinLabelWidth(minLabelWidth)

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

                local w0 = self.tooltip:getWidth()
                layout:render(startX, startY, self.tooltip)
                -- zdk.logger:debug("w0 = %d, w1 = %d, tw = %d", w0, w1, self.tooltip:getWidth())
                -- self:drawRectBorder(startX, startY, self.tooltip:getWidth() - ZItemTiers.pad * 2, h1, 55, 30, 0, 30)
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

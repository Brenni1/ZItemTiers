-- Tooltip display for item tier and bonuses

ZItemTiers.pad = ZItemTiers.pad or 15

local TRANSFORM_VALUES = {
    Insulation      = function(x) return x*100 end,
    HearingModifier = function(x) return -x end,
    UnhappyChange   = function(x) return -x end,
    VisionModifier  = function(x) return -x end,
    WaterResistance = function(x) return x*100 end,
    Windresistance  = function(x) return x*100 end,
}

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

local function getItemTierAndBonuses(item)
    local lines = {}
    local tier = ZItemTiers.GetItemTierKey(item)
    local bonuses = ZItemTiers.GetItemShownBonuses(item)

    local tierData = ZItemTiers.Tiers[tier]
    local color = tierData.color

    local rgba = { color.r, color.g, color.b, 1.0 }
    table.insert(lines, {
        name  = "Tier",
        text  = tierData.name,
        color = rgba
    })

    for bonusKey, bonus in pairs(bonuses) do
        local base     = bonus.base
        local modified = bonus.modified

        local divider  = zdk.dig(ZItemTiers.Bonuses, bonusKey, "div")
        if divider then modified = modified * divider end

        local delta = modified - base

        if TRANSFORM_VALUES[bonusKey] then
            delta = TRANSFORM_VALUES[bonusKey](delta)
        end

        local decimals  = math.abs(delta) >= 0.01 and 2 or 4
        local text      = string.format("%+." .. decimals .. "f", delta)
        table.insert(lines, {
            name     = getBonusDisplayName(bonusKey),
            delta    = delta,
            text     = text,
            decimals = decimals,
            highGood = delta > 0,
            color    = rgba,
        })
    end
    return lines
end

-- Helper function to add tier information to a tooltip layout
-- Shows tier for all items that have been assigned a tier
-- This function is exposed to integration modules via ZItemTiers.addTierToLayout
function ZItemTiers.addTierToLayout(item, layout, font)
    local maxValueWidth = 0
    if item and layout then
        local lines = getItemTierAndBonuses(item)
        for _, line in ipairs(lines) do
            local bonusItem = layout:addItem()
            bonusItem:setLabel(line.name, unpack(line.color))
            bonusItem:setValue(line.text, unpack(line.color))
            maxValueWidth = math.max(maxValueWidth, TextManager.instance:MeasureStringX(font, line.text))
        end
    end
    return maxValueWidth
end

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

local function setupTooltips()
    local logger = ZItemTiers.logger:withPrefix("setupTooltips(): ")

    if TooltipLib and TooltipLib.registerProvider then
        logger:info("TooltipLib detected")
        TooltipLib.registerProvider({
            id = "ZItemTiers",
            callback = function(ctx)
                for _, l in ipairs(getItemTierAndBonuses(ctx.item)) do
                    if l.delta then
                        ctx:addFloat(l.name, l.delta, l.decimals, l.highGood, l.color, l.color)
                    else
                        ctx:addKeyValue(l.name, l.text, l.color, l.color)
                    end
                end
            end
        })
        return
    end

    local tooltip_render_fname = getFilenameOfClosure and getFilenameOfClosure(ISToolTipInv.render) or ""
    logger:info("ISToolTipInv.render is owned by %s", tooltip_render_fname)

    if tooltip_render_fname:contains("/Starlit/client/ui/InventoryUI.lua") then
        logger:info("Starlit detected")
        local InventoryUI = require("Starlit/client/ui/InventoryUI")
        InventoryUI.onFillItemTooltip:addListener(function(tooltip, layout, item)
            for _, l in ipairs(getItemTierAndBonuses(item)) do
                InventoryUI.addTooltipKeyValue(layout, l.name, l.text, l.color, l.color)
            end
        end)
        return
    end

    -- no BCI or BCI non-clothing path
    zdk.patch_all_metatables("DoTooltip", {
        DoTooltip = function(orig, self, ...)
            while instanceof(self, "InventoryItem") and select('#', ...) == 1 do
                local tooltip = select(1, ...) -- zombie.ui.ObjectTooltip
                if not tooltip or not tooltip.beginLayout then break end

                orig(self, ...)

                local layout    = createTierLayout(tooltip, self)
                local charWidth = TextManager.instance:MeasureStringX(tooltip:getFont(), "0") -- as in ObjectTooltip.checkFont
                local padLeft   = charWidth
                local padBottom = charWidth/2
                local h0 = tooltip:getHeight()
                local h1 = layout:render(padLeft, h0-padBottom, tooltip);
                tooltip:setHeight(h1 + padBottom)
                return
            end
            return orig(self, ...)
        end
    })

    if tooltip_render_fname:contains("/3604080281/mods/BetterClothingInfo/") and _G.BCI_TooltipInv_Active then
        logger:info("BetterClothingInfo detected")

        -- BCI clothing path
        zdk.hook({
            _G = {
                DoTooltipClothing = function(orig, objTooltip, item, layout, ...)
                    local result = orig(objTooltip, item, layout, ...)
                    ZItemTiers.addTierToLayout(item, layout, objTooltip:getFont())
                    return result
                end
            }
        })
        return
    end
end

Events.OnGameStart.Add(setupTooltips)

--[[
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
]]

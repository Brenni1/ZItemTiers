-- BetterClothingInfo mod integration for tooltip display
-- This integration hooks into BetterClothingInfo's DoTooltipClothing function if available
-- Uses the same DrawItem pattern as BetterClothingInfo uses for material display

require "ZItemTiers/core"

-- Expose whether BetterClothingInfo integration is active
ZItemTiers.BetterClothingInfoActive = false

-- Store current item being processed for tooltip to pass context to SetItemInfoAsText
ZItemTiers._currentItemForTooltip = nil

-- Check if BetterClothingInfo mod is active and has DoTooltipClothing function
-- DoTooltipClothing is defined at global scope: function DoTooltipClothing(objTooltip, item, layoutTooltip)
local hasBetterClothingInfo = DoTooltipClothing ~= nil

if not hasBetterClothingInfo then return end

-- returns number of hooks applied
local hookResult = zbHook({
    _G = {
        SetItemInfoAsText = function(orig, newItemValue, label, layoutItem, layoutTooltip, ...)
--            while true do
--                if label ~= "Tier" and label ~= "" then break end
--
--                local item = ZItemTiers._currentItemForTooltip
--                local tier = ZItemTiers.GetItemTierKey(item)
--                if not item or not tier then break end
--
--                local tierColor = ZItemTiers.Tiers[tier].color
--
--                -- Extract just the display value (remove the item type and ID suffix we added for uniqueness)
--                -- Format: "TierName_ItemType_ItemID" -> "TierName"
--                -- Or: "BonusText_ItemType_ItemID_BonusType" -> "BonusText"
----                if string.find(newItemValue, "_") then
----                    displayValue = string.match(newItemValue, "^([^_]+)")
----                end
--
--                layoutItem = layoutTooltip:addItem()
--                if label == "Tier" then
--                    layoutItem:setLabel(getText(label) .. ":", tierColor.r, tierColor.g, tierColor.b, 1.0)
--                else
--                    -- Empty label for bonus rows
--                    layoutItem:setLabel("", tierColor.r, tierColor.g, tierColor.b, 1.0)
--                end
--                layoutItem:setValue(newItemValue, tierColor.r, tierColor.g, tierColor.b, 1.0)
--
--                return
--            end
            return orig(newItemValue, label, layoutItem, layoutTooltip, ...)
        end,

        DoTooltipClothing = function(orig, objTooltip, item, layoutTooltip, ...)
            orig(objTooltip, item, layoutTooltip, ...)
        end,
    }
})

ZItemTiers.BetterClothingInfoActive = hookResult ~= 0

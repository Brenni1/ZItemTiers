-- Starlit Library integration for tooltip display
-- This integration adds tier information to tooltips via Starlit Library's tooltip events

-- XXX can't use because it's broken for 42.15 :(
-- (onFillItemTooltip is never triggered)

-- Try to load Starlit Library
--local InventoryUI = require("Starlit/client/ui/InventoryUI")
--
---- Hook into Starlit Library's tooltip event - this should work for all items including clothing
--if InventoryUI and InventoryUI.onFillItemTooltip and InventoryUI.onFillItemTooltip.addListener then
--    InventoryUI.onFillItemTooltip:addListener(function(tooltip, layout, item)
--        print("Starlit tooltip event", tooltip, layout, item)
--        -- Use the shared function to add tier and bonuses
--        ZItemTiers.addTierToLayout(item, layout)
--    end)
--end

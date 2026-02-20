-- Starlit Library integration for tooltip display
-- This integration adds tier information to tooltips via Starlit Library's tooltip events

-- Try to load Starlit Library
local InventoryUI = nil
local success, result = pcall(function() return require("Starlit/client/ui/InventoryUI") end)
if success and result then
    InventoryUI = result
end

-- Hook into Starlit Library's tooltip event - this should work for all items including clothing
if InventoryUI and InventoryUI.onFillItemTooltip then
    local success2, err = pcall(function()
        if InventoryUI.onFillItemTooltip.addListener then
            InventoryUI.onFillItemTooltip:addListener(function(tooltip, layout, item)
                -- Use the shared function to add tier and bonuses
                if ZItemTiers and ZItemTiers.addTierToLayout then
                    ZItemTiers.addTierToLayout(item, layout)
                end
            end)
        end
    end)
    
    if not success2 then
        print("ZItemTiers: Failed to register Starlit tooltip listener: " .. tostring(err))
    else
        print("ZItemTiers: Starlit Library tooltip hook registered")
    end
end

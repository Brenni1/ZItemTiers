-- Context menu integration for item comparison
-- This integration ensures items with different tiers are properly compared in context menu tooltips
-- BetterClothingInfo replaces doWearClothingTooltip. We hook into it and ensure it works for items with
-- different tiers even if they have the same getFullType().

require "ZItemTiers/core"

-- Hook into doWearClothingTooltip
-- BetterClothingInfo completely replaces this function. We need to ensure it works correctly.
-- The function uses object reference comparison which should work, but we verify it does.
if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.doWearClothingTooltip then
    local originalDoWearClothingTooltip = ISInventoryPaneContextMenu.doWearClothingTooltip
    
    function ISInventoryPaneContextMenu.doWearClothingTooltip(playerObj, newItem, currentItem, option)
        -- Call BetterClothingInfo's version (or vanilla if BCI is not active)
        local replaceItems = originalDoWearClothingTooltip(playerObj, newItem, currentItem, option)
        
        -- BetterClothingInfo's version should work because it uses object references and gets values from instances.
        -- However, if it returns nil (no tooltip created), we need to check if items have different tiers
        -- and create a tooltip ourselves if needed.
        
        -- If replaceItems is nil and option.toolTip is nil, BetterClothingInfo didn't create a tooltip.
        -- This happens when all values are 0 and there are no items to replace.
        -- But if items have different tiers, they should have different defense values, so this shouldn't happen.
        -- However, if BetterClothingInfo is checking getFullType() and skipping the comparison, we need to handle it.
        
        if not replaceItems and not option.toolTip then
            -- BetterClothingInfo didn't create a tooltip. Check if items have different tiers.
            -- If they do, we should create a tooltip to show the comparison.
            local newItemTier = ZItemTiers.GetItemTier(newItem)
            
            if newItemTier and newItem:IsClothing() then
                -- Get the currently worn item in the same location
                local wornItems = playerObj:getWornItems()
                local bodyLocationGroup = wornItems:getBodyLocationGroup()
                local location = newItem:getBodyLocation()
                
                for i = 1, wornItems:size() do
                    local wornItem = wornItems:get(i - 1)
                    local item = wornItem:getItem()
                    
                    if (newItem:getBodyLocation() == wornItem:getLocation()) or
                       (location ~= "" and bodyLocationGroup:isExclusive(location, wornItem:getLocation())) then
                        if item ~= newItem and item ~= currentItem then
                            local currentItemTier = ZItemTiers.GetItemTier(item)
                            
                            -- If items have different tiers, they should have different defense values
                            -- Create a tooltip to show the comparison
                            local newBiteDefense = newItem:getBiteDefense()
                            local newScratchDefense = newItem:getScratchDefense()
                            local previousBiteDefense = item:getBiteDefense()
                            local previousScratchDefense = item:getScratchDefense()
                            
                            -- If there's a difference, create a tooltip
                            if newBiteDefense ~= previousBiteDefense or newScratchDefense ~= previousScratchDefense then
                                local tooltip = ISInventoryPaneContextMenu.addToolTip()
                                tooltip.maxLineWidth = 1000
                                
                                local font = ISToolTip.GetFont()
                                local labelWidth = 0
                                labelWidth = math.max(labelWidth, getTextManager():MeasureStringX(font, getText("Tooltip_BiteDefense") .. ":"))
                                labelWidth = math.max(labelWidth, getTextManager():MeasureStringX(font, getText("Tooltip_ScratchDefense") .. ":"))
                                
                                -- Use BetterClothingInfo's formatWearTooltip if available, otherwise use vanilla format
                                if ISInventoryPaneContextMenu.formatWearTooltip then
                                    ISInventoryPaneContextMenu.formatWearTooltip(tooltip, labelWidth, previousBiteDefense, newBiteDefense, 1, "Tooltip_BiteDefense", false, false)
                                    ISInventoryPaneContextMenu.formatWearTooltip(tooltip, labelWidth, previousScratchDefense, newScratchDefense, 1, "Tooltip_ScratchDefense", false, false)
                                else
                                    -- Vanilla format
                                    local hc = getCore():getGoodHighlitedColor()
                                    local plus = "+"
                                    if previousBiteDefense > 0 and previousBiteDefense > newBiteDefense then
                                        hc = getCore():getBadHighlitedColor()
                                        plus = ""
                                    end
                                    local text = string.format(" <RGB:%.2f,%.2f,%.2f> %s: <SETX:%d> %d (%s%d) <LINE> ",
                                        hc:getR(), hc:getG(), hc:getB(), getText("Tooltip_BiteDefense"), labelWidth + 10,
                                        newBiteDefense, plus, newBiteDefense - previousBiteDefense)
                                    tooltip.description = tooltip.description .. text
                                    
                                    hc = getCore():getGoodHighlitedColor()
                                    plus = "+"
                                    if previousScratchDefense > 0 and previousScratchDefense > newScratchDefense then
                                        hc = getCore():getBadHighlitedColor()
                                        plus = ""
                                    end
                                    text = string.format(" <RGB:%.2f,%.2f,%.2f> %s: <SETX:%d> %d (%s%d) <LINE> ",
                                        hc:getR(), hc:getG(), hc:getB(), getText("Tooltip_ScratchDefense"), labelWidth + 10,
                                        newScratchDefense, plus, newScratchDefense - previousScratchDefense)
                                    tooltip.description = tooltip.description .. text
                                end
                                
                                option.toolTip = tooltip
                                return {}
                            end
                        end
                    end
                end
            end
        end
        
        return replaceItems
    end
    
    print("ZItemTiers: Hooked into ISInventoryPaneContextMenu.doWearClothingTooltip")
end

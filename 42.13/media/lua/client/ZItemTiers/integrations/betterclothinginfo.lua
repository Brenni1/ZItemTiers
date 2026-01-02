-- BetterClothingInfo mod integration for tooltip display
-- This integration hooks into BetterClothingInfo's DoTooltipClothing function if available
-- Uses the same DrawItem pattern as BetterClothingInfo uses for material display

-- Expose whether BetterClothingInfo integration is active
ZItemTiers.BetterClothingInfoActive = false

-- Check if BetterClothingInfo mod is active and has DoTooltipClothing function
-- DoTooltipClothing is defined at global scope: function DoTooltipClothing(objTooltip, item, layoutTooltip)
local hasBetterClothingInfo = false
local DrawItem = nil
local successBCI, resultBCI = pcall(function()
    if _G and _G.DoTooltipClothing then
        hasBetterClothingInfo = true
        -- Check if DrawItem is available (from BetterClothingInfo)
        if _G.DrawItem then
            DrawItem = _G.DrawItem
        end
        return true
    end
    return false
end)

if hasBetterClothingInfo and _G and _G.DoTooltipClothing then
    -- Hook into SetItemInfoAsText to apply custom colors for Rarity and Bonuses
    local originalSetItemInfoAsText = _G.SetItemInfoAsText
    if originalSetItemInfoAsText then
        function _G.SetItemInfoAsText(newItemValue, label, layoutItem, layoutTooltip)
            -- Check if this is our Rarity or Bonuses label
            local labelText = getText(label) or label
            local isRarity = (labelText == "Rarity" or label == "Rarity")
            local isBonuses = (labelText == "Bonuses" or label == "Bonuses")
            
            if isRarity or isBonuses then
                -- Get the current item from context (we'll store it when creating DrawItem)
                local currentItem = ZItemTiers._currentItemForTooltip
                if currentItem then
                    local modData = currentItem:getModData()
                    local rarity = "Common"
                    if modData then
                        rarity = modData.itemRarity or "Common"
                    end
                    
                    if ZItemTiers and ZItemTiers.Rarities and ZItemTiers.Rarities[rarity] then
                        local rarityData = ZItemTiers.Rarities[rarity]
                        local color = rarityData.color
                        
                        -- Create layout item and set colors
                        layoutItem = layoutTooltip:addItem()
                        layoutItem:setLabel(labelText .. ":", color.r, color.g, color.b, 1.0)
                        layoutItem:setValue(newItemValue, color.r, color.g, color.b, 1.0)
                        return
                    end
                end
            end
            
            -- For other labels, use the original function
            originalSetItemInfoAsText(newItemValue, label, layoutItem, layoutTooltip)
        end
        print("ZItemTiers: Hooked into SetItemInfoAsText for custom colors")
    end
    
    -- BetterClothingInfo is active - hook into its DoTooltipClothing function
    -- Function signature: DoTooltipClothing(objTooltip, item, layoutTooltip)
    local originalDoTooltipClothing = _G.DoTooltipClothing
    if originalDoTooltipClothing then
        function _G.DoTooltipClothing(objTooltip, item, layoutTooltip)
            -- Store current item for SetItemInfoAsText hook
            ZItemTiers._currentItemForTooltip = item
            
            -- Call the original BetterClothingInfo function first
            originalDoTooltipClothing(objTooltip, item, layoutTooltip)
            
            -- Add our rarity info directly to layoutTooltip (same pattern as BetterClothingInfo uses)
            if ZItemTiers and item and layoutTooltip then
                -- Check if item has scalable properties (could have rarity)
                local hasProps = false
                if ZItemTiers.Bonuses then
                    for bonusType, bonusData in pairs(ZItemTiers.Bonuses) do
                        if bonusData.checkApplicable then
                            local success, isApplicable = pcall(bonusData.checkApplicable, item)
                            if success and isApplicable then
                                hasProps = true
                                break
                            end
                        end
                    end
                end
                
                -- Also check if item has rarity data directly (might have been assigned but no bonuses apply)
                local modData = item:getModData()
                if modData and modData.itemRarity then
                    hasProps = true  -- If item has rarity, we should show it
                end
                
                if hasProps then
                    -- Get rarity and bonuses from item modData
                    local modData = item:getModData()
                    local rarity = "Common"
                    local itemBonuses = {}
                    
                    if modData then
                        rarity = modData.itemRarity or "Common"
                        itemBonuses = modData.itemBonuses or {}
                    end
                    
                    if ZItemTiers.Rarities and ZItemTiers.Rarities[rarity] and DrawItem then
                        local rarityData = ZItemTiers.Rarities[rarity]
                        local rarityName = rarityData.name
                        
                        -- Build bonuses text from stored bonuses
                        local bonusTexts = {}
                        for _, bonus in ipairs(itemBonuses) do
                            local bonusName = ZItemTiers.GetBonusDisplayName(bonus.type)
                            local bonusPercent = math.floor((bonus.multiplier - 1.0) * 100)
                            table.insert(bonusTexts, "+" .. bonusPercent .. "% " .. bonusName)
                        end
                        
                        -- Create DrawItem for rarity using the same pattern as BetterClothingInfo
                        -- DrawItem:New(newItemValue, icon, label, layoutItem, layoutTooltip, ...)
                        -- newItemValue must be a string or number for Render() to work (DrawItem:Render checks type)
                        local rarityDrawItem = DrawItem:New(
                            rarityName,  -- newItemValue: string (rarity name) - this is what gets drawn
                            nil,         -- icon
                            "Rarity",    -- label (translation key or label)
                            nil,         -- layoutItem (not used in tooltip context)
                            layoutTooltip, -- layoutTooltip
                            nil,         -- additional params
                            nil,
                            nil
                        )
                        
                        -- Render the rarity DrawItem (always show if item has scalable properties)
                        if rarityDrawItem and rarityDrawItem.Render then
                            rarityDrawItem:Render(true)
                        end
                        
                        -- If there are bonuses, create another DrawItem for them
                        if #bonusTexts > 0 then
                            local bonusText = table.concat(bonusTexts, ", ")
                            local bonusDrawItem = DrawItem:New(
                                bonusText,  -- newItemValue: string (bonus text)
                                nil,        -- icon
                                "Bonuses",  -- label
                                nil,        -- layoutItem
                                layoutTooltip, -- layoutTooltip
                                nil,
                                nil,
                                nil
                            )
                            
                            -- Render the bonuses DrawItem
                            if bonusDrawItem and bonusDrawItem.Render then
                                bonusDrawItem:Render(true)
                            end
                        end
                    else
                        print("ZItemTiers: Rarity data not found for: " .. tostring(rarity))
                    end
                end
            end
            
            -- Clear the stored item after tooltip is done
            ZItemTiers._currentItemForTooltip = nil
        end
        ZItemTiers.BetterClothingInfoActive = true
        print("ZItemTiers: Hooked into BetterClothingInfo.DoTooltipClothing using DrawItem pattern")
    end
end

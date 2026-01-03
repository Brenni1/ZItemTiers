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
local hasBetterClothingInfo = false
local DrawItem = nil
local SetItemInfoAsText = nil
local successBCI, resultBCI = pcall(function()
    if _G and _G.DoTooltipClothing then
        hasBetterClothingInfo = true
        -- Check if DrawItem is available (from BetterClothingInfo)
        if _G.DrawItem then
            DrawItem = _G.DrawItem
        end
        -- Check if SetItemInfoAsText is available (from BetterClothingInfo)
        if _G.SetItemInfoAsText then
            SetItemInfoAsText = _G.SetItemInfoAsText
        end
        return true
    end
    return false
end)

if hasBetterClothingInfo and _G and _G.DoTooltipClothing and DrawItem and SetItemInfoAsText then
    -- Hook into SetItemInfoAsText to apply custom colors for Rarity and Bonuses
    local originalSetItemInfoAsText = _G.SetItemInfoAsText
    if originalSetItemInfoAsText then
        function _G.SetItemInfoAsText(newItemValue, label, layoutItem, layoutTooltip)
            local item = ZItemTiers._currentItemForTooltip
            local rarityColor = nil
            
            if item then
                local modData = item:getModData()
                if modData and modData.itemRarity and ZItemTiers.Rarities and ZItemTiers.Rarities[modData.itemRarity] then
                    rarityColor = ZItemTiers.Rarities[modData.itemRarity].color
                end
            end
            
            -- Apply custom color if label is "Rarity" or "Bonuses"
            if rarityColor and (label == "Rarity" or label == "Bonuses") then
                layoutItem = layoutTooltip:addItem()
                layoutItem:setLabel(getText(label) .. ":", rarityColor.r, rarityColor.g, rarityColor.b, 1.0)
                layoutItem:setValue(newItemValue, rarityColor.r, rarityColor.g, rarityColor.b, 1.0)
            else
                -- Call original SetItemInfoAsText
                originalSetItemInfoAsText(newItemValue, label, layoutItem, layoutTooltip)
            end
        end
        print("ZItemTiers: Patched SetItemInfoAsText for custom rarity colors")
    end
    
    -- BetterClothingInfo is active - hook into its DoTooltipClothing function
    -- Function signature: DoTooltipClothing(objTooltip, item, layoutTooltip)
    local originalDoTooltipClothing = _G.DoTooltipClothing
    if originalDoTooltipClothing then
        function _G.DoTooltipClothing(objTooltip, item, layoutTooltip)
            -- Store the current item for SetItemInfoAsText to access
            ZItemTiers._currentItemForTooltip = item
            
            -- Call the original BetterClothingInfo function first
            originalDoTooltipClothing(objTooltip, item, layoutTooltip)
            
            -- Add our rarity info using the same DrawItem pattern as BetterClothingInfo
            if ZItemTiers and item and layoutTooltip and DrawItem then
                -- Check if item has rarity
                local rarity = ZItemTiers.GetItemRarity(item)
                local itemBonuses = ZItemTiers.GetItemBonuses(item)
                
                if rarity and ZItemTiers.Rarities and ZItemTiers.Rarities[rarity] then
                    local rarityData = ZItemTiers.Rarities[rarity]
                    local rarityName = rarityData.name
                    
                    -- Build bonuses text from fixed bonuses
                    local bonusTexts = {}
                    for _, bonus in ipairs(itemBonuses) do
                        local bonusName = ZItemTiers.GetBonusDisplayName(bonus.type)
                        if bonus.value then
                            table.insert(bonusTexts, "+" .. bonus.value .. "% " .. bonusName)
                        end
                    end
                    
                    -- Create DrawItem for rarity using the same pattern as BetterClothingInfo
                    local rarityDrawItem = DrawItem:New(
                        rarityName,  -- newItemValue: string (rarity name)
                        nil,         -- icon
                        "Rarity",    -- label
                        nil,         -- layoutItem
                        layoutTooltip, -- layoutTooltip
                        nil,
                        nil,
                        nil
                    )
                    
                    -- Render the rarity DrawItem
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
                end
            end
            -- Clear the current item after the tooltip is done
            ZItemTiers._currentItemForTooltip = nil
        end
        ZItemTiers.BetterClothingInfoActive = true
        print("ZItemTiers: Hooked into BetterClothingInfo.DoTooltipClothing using DrawItem pattern")
    end
end

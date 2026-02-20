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
    -- Hook into SetItemInfoAsText to apply custom colors for Tier and Bonuses
    local originalSetItemInfoAsText = _G.SetItemInfoAsText
    if originalSetItemInfoAsText then
        function _G.SetItemInfoAsText(newItemValue, label, layoutItem, layoutTooltip)
            local item = ZItemTiers._currentItemForTooltip
            local tierColor = nil
            local displayValue = newItemValue
            
            if item then
                local modData = item:getModData()
                if modData and modData.itemTier and ZItemTiers.Tiers and ZItemTiers.Tiers[modData.itemTier] then
                    tierColor = ZItemTiers.Tiers[modData.itemTier].color
                end
            end
            
            -- Apply custom color if label is "Tier" or empty (bonus rows)
            if tierColor and (label == "Tier" or label == "") then
                -- Extract just the display value (remove the item type and ID suffix we added for uniqueness)
                -- Format: "TierName_ItemType_ItemID" -> "TierName"
                -- Or: "BonusText_ItemType_ItemID_BonusType" -> "BonusText"
                if string.find(newItemValue, "_") then
                    displayValue = string.match(newItemValue, "^([^_]+)")
                end
                
                layoutItem = layoutTooltip:addItem()
                if label == "Tier" then
                    layoutItem:setLabel(getText(label) .. ":", tierColor.r, tierColor.g, tierColor.b, 1.0)
                else
                    -- Empty label for bonus rows
                    layoutItem:setLabel("", tierColor.r, tierColor.g, tierColor.b, 1.0)
                end
                layoutItem:setValue(displayValue, tierColor.r, tierColor.g, tierColor.b, 1.0)
            else
                -- Call original SetItemInfoAsText
                originalSetItemInfoAsText(newItemValue, label, layoutItem, layoutTooltip)
            end
        end
        print("ZItemTiers: Patched SetItemInfoAsText for custom tier colors")
    end
    
    -- BetterClothingInfo is active - hook into its DoTooltipClothing function
    -- Function signature: DoTooltipClothing(objTooltip, item, layoutTooltip)
    local originalDoTooltipClothing = _G.DoTooltipClothing
    if originalDoTooltipClothing then
        function _G.DoTooltipClothing(objTooltip, item, layoutTooltip)
            -- Store the current item for SetItemInfoAsText to access
            ZItemTiers._currentItemForTooltip = item
            
            -- Get tier and bonuses once
            local tier = ZItemTiers.GetItemTier(item)
            local itemBonuses = ZItemTiers.GetItemBonuses(item)
            local tierData = nil
            local tierName = nil
            
            if tier and ZItemTiers.Tiers and ZItemTiers.Tiers[tier] then
                tierData = ZItemTiers.Tiers[tier]
                tierName = tierData.name
            end
            
            -- Call the original BetterClothingInfo function first
            originalDoTooltipClothing(objTooltip, item, layoutTooltip)
            
            -- Add our tier info using the same DrawItem pattern as BetterClothingInfo
            if ZItemTiers and item and layoutTooltip and DrawItem and tierData and tierName then
                    
                    -- Create DrawItem for tier using the same pattern as BetterClothingInfo
                    -- Include tier in the item value to ensure items with different tiers are treated as different items
                    -- This prevents BetterClothingInfo from skipping comparison when comparing Rare vs Common items
                    local tierItemValue = tierName .. "_" .. tostring(item:getFullType()) .. "_" .. tostring(item:getID())
                    local tierDrawItem = DrawItem:New(
                        tierItemValue,  -- newItemValue: string (includes tier + item type + ID to make it unique)
                        nil,              -- icon
                        "Tier",         -- label
                        nil,              -- layoutItem
                        layoutTooltip,    -- layoutTooltip
                        nil,
                        nil,
                        nil
                    )
                    
                    -- Render the tier DrawItem
                    if tierDrawItem and tierDrawItem.Render then
                        tierDrawItem:Render(true)
                    end
                    
                    -- Create a separate DrawItem for each bonus (one row per bonus)
                    -- Each bonus row has empty label, so it just shows "+20% Damage" on the right
                    for _, bonus in ipairs(itemBonuses) do
                        local bonusName = ZItemTiers.GetBonusDisplayName(bonus.type)
                        if bonus.value then
                            -- Format bonus text (e.g., "+20% Damage")
                            local bonusText = ""
                            -- Format based on bonus type
                            if bonus.type == "RunSpeedModifier" or bonus.type == "VisionImpairmentReduction" or bonus.type == "HearingImpairmentReduction" then
                                -- These are already formatted with decimal places (e.g., "0.1")
                                bonusText = "+" .. bonus.value .. " " .. bonusName
                            elseif bonus.type == "EncumbranceReduction" or bonus.type == "MaxEncumbranceBonus" or bonus.type == "BiteDefenseBonus" or bonus.type == "ScratchDefenseBonus" or bonus.type == "VhsSkillXpBonus" then
                                -- These are flat values, no % sign (e.g., "+5 Bite Defense", "+50 Skill XP Bonus")
                                bonusText = "+" .. bonus.value .. " " .. bonusName
                            elseif bonus.type == "MoodBonus" or bonus.type == "ReadingSpeedBonus" then
                                -- Percentage bonuses (e.g., "+10% Mood Benefits", "+10% Reading Speed")
                                bonusText = "+" .. bonus.value .. "% " .. bonusName
                            else
                                -- Percentage bonuses (e.g., "+20% Damage")
                                bonusText = "+" .. bonus.value .. "% " .. bonusName
                            end
                            
                            -- Create unique item value for this specific bonus
                            local bonusItemValue = bonusText .. "_" .. tostring(item:getFullType()) .. "_" .. tostring(item:getID()) .. "_" .. bonus.type
                            local bonusDrawItem = DrawItem:New(
                                bonusItemValue,  -- newItemValue: string (bonus text + item type + ID + bonus type to make it unique)
                                nil,             -- icon
                                "",              -- label: empty string so only the value is shown
                                nil,             -- layoutItem
                                layoutTooltip,   -- layoutTooltip
                                nil,
                                nil,
                                nil
                            )
                            
                            -- Render the bonus DrawItem
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

-- Hearing impairment reduction module
-- Applies tier-based hearing impairment reduction to Clothing items

require "ZItemTiers/core"

-- Apply hearing impairment reduction to a Clothing item
-- reductionValue: The hearing impairment reduction (e.g., 0.05 for -0.05)
-- modData: The item's modData table (required for storing the reduction)
function ZItemTiers.ApplyHearingImpairmentReduction(item, reductionValue, modData)
    if not item or not reductionValue or not modData then
        return
    end
    
    if not instanceof(item, "Clothing") then
        return
    end
    
    -- Get base hearing modifier from script item
    -- Hearing modifier: 1.0 = no impairment, < 1.0 = impairment (lower = worse)
    -- We want to increase the modifier (make it closer to 1.0) by adding the reduction
    local baseHearingMod = 1.0
    local successGetBase, baseValue = pcall(function()
        if item.getScriptItem then
            local scriptItem = item:getScriptItem()
            if scriptItem then
                -- Try getHearingModifier method first
                if scriptItem.getHearingModifier then
                    return scriptItem:getHearingModifier()
                end
                -- Fallback: try hearingModifier property
                if scriptItem.hearingModifier then
                    return scriptItem.hearingModifier
                end
            end
        end
        -- Also try instance method
        if item.getHearingModifier then
            return item:getHearingModifier()
        end
        return 1.0
    end)
    if successGetBase and baseValue then
        baseHearingMod = baseValue
    end
    
    -- Only apply if the item has hearing impairment (modifier < 1.0)
    if baseHearingMod < 1.0 then
        -- Get current hearing modifier from the instance
        local successGet, currentHearingMod = pcall(function()
            if item.getHearingModifier then
                return item:getHearingModifier()
            end
            -- Fallback: try to get from script item
            if item.getScriptItem then
                local scriptItem = item:getScriptItem()
                if scriptItem then
                    if scriptItem.getHearingModifier then
                        return scriptItem:getHearingModifier()
                    end
                    if scriptItem.hearingModifier then
                        return scriptItem.hearingModifier
                    end
                end
            end
            return baseHearingMod
        end)
        
        if successGet then
            -- Calculate expected new value: base + reduction (additive, but don't go above 1.0)
            -- The modifier represents impairment when < 1.0, so increasing it means less impairment
            local newHearingMod = math.min(1.0, baseHearingMod + reductionValue)
            
            -- Store base value and reduction in modData for Java patch
            -- The Java patch will read itemHearingImpairmentReduction from modData and apply it to getHearingModifier()
            modData.itemHearingImpairmentBase = baseHearingMod
            modData.itemHearingImpairmentReduction = reductionValue
        end
    end
end

-- Vision impairment reduction module
-- Applies tier-based vision impairment reduction to Clothing items

require "ZItemTiers/core"

-- Apply vision impairment reduction to a Clothing item
-- reductionValue: The vision impairment reduction (e.g., 0.05 for -0.05)
-- modData: The item's modData table (required for storing the reduction)
function ZItemTiers.ApplyVisionImpairmentReduction(item, reductionValue, modData)
    if not item or not reductionValue or not modData then
        return
    end
    
    if not instanceof(item, "Clothing") then
        return
    end
    
    -- Get base vision modifier from script item
    -- Vision modifier: 1.0 = no impairment, < 1.0 = impairment (lower = worse)
    -- We want to increase the modifier (make it closer to 1.0) by adding the reduction
    local baseVisionMod = 1.0
    local successGetBase, baseValue = pcall(function()
        if item.getScriptItem then
            local scriptItem = item:getScriptItem()
            if scriptItem then
                -- Try getVisionModifier method first
                if scriptItem.getVisionModifier then
                    return scriptItem:getVisionModifier()
                end
                -- Fallback: try visionModifier property
                if scriptItem.visionModifier then
                    return scriptItem.visionModifier
                end
            end
        end
        -- Also try instance method
        if item.getVisionModifier then
            return item:getVisionModifier()
        end
        return 1.0
    end)
    if successGetBase and baseValue then
        baseVisionMod = baseValue
    end
    
    -- Only apply if the item has vision impairment (modifier < 1.0)
    if baseVisionMod < 1.0 then
        -- Get current vision modifier from the instance
        local successGet, currentVisionMod = pcall(function()
            if item.getVisionModifier then
                return item:getVisionModifier()
            end
            -- Fallback: try to get from script item
            if item.getScriptItem then
                local scriptItem = item:getScriptItem()
                if scriptItem then
                    if scriptItem.getVisionModifier then
                        return scriptItem:getVisionModifier()
                    end
                    if scriptItem.visionModifier then
                        return scriptItem.visionModifier
                    end
                end
            end
            return baseVisionMod
        end)
        
        if successGet then
            -- Calculate expected new value: base + reduction (additive, but don't go above 1.0)
            -- The modifier represents impairment when < 1.0, so increasing it means less impairment
            local newVisionMod = math.min(1.0, baseVisionMod + reductionValue)
            
            -- Store base value and reduction in modData for Java patch
            -- The Java patch will read itemVisionImpairmentReduction from modData and apply it to getVisionModifier()
            modData.itemVisionImpairmentBase = baseVisionMod
            modData.itemVisionImpairmentReduction = reductionValue
        end
    end
end

-- Battery consumption reduction for flashlights
-- Reduces battery drain rate for tiered flashlights (ElectricLight/Torch items)

require "ZItemTiers/core"

-- Apply battery consumption reduction to DrainableComboItem flashlights
function ZItemTiers.ApplyBatteryConsumptionReduction(item, reduction, modData)
    if not item then return end
    
    -- Check if this is a DrainableComboItem (flashlights are DrainableComboItem)
    local isDrainableCombo = false
    local successCheck, resultCheck = pcall(function()
        return instanceof(item, "DrainableComboItem")
    end)
    if successCheck and resultCheck then
        isDrainableCombo = true
    end
    
    if not isDrainableCombo then
        return
    end
    
    -- Check if this is a flashlight (Torch or ElectricLight items)
    local itemType = nil
    local successType, typeValue = pcall(function() return item:getFullType() end)
    if successType and typeValue then
        itemType = typeValue
    end
    
    -- Check if it's a flashlight by type name
    local isFlashlight = false
    if itemType then
        if string.find(itemType, "Torch") or string.find(itemType, "Flashlight") or string.find(itemType, "ElectricLight") then
            isFlashlight = true
        end
    end
    
    if not isFlashlight then
        return
    end
    
    -- Get original useDelta from script item if not stored
    local originalUseDelta = nil
    if modData and modData.itemBatteryUseDeltaOriginal then
        originalUseDelta = modData.itemBatteryUseDeltaOriginal
    else
        local successGetScript, scriptItem = pcall(function()
            if item.getScriptItem then
                return item:getScriptItem()
            end
            return nil
        end)
        
        if successGetScript and scriptItem and scriptItem.useDelta then
            originalUseDelta = scriptItem.useDelta
        else
            -- Fallback: get current useDelta
            local successGetDelta, currentDelta = pcall(function()
                if item.getUseDelta then
                    return item:getUseDelta()
                end
                return nil
            end)
            if successGetDelta and currentDelta then
                originalUseDelta = currentDelta
            end
        end
        
        -- Store original value
        if modData and originalUseDelta then
            modData.itemBatteryUseDeltaOriginal = originalUseDelta
        end
    end
    
    if originalUseDelta then
        -- Calculate reduced useDelta (lower delta = slower drain = less consumption)
        -- Reduction of 0.1 means 10% less consumption, so multiply delta by (1 - 0.1) = 0.9
        local reducedUseDelta = originalUseDelta * (1.0 - reduction)
        
        -- Apply the reduced useDelta
        local successSet = pcall(function()
            if item.setUseDelta then
                item:setUseDelta(reducedUseDelta)
            end
        end)
        
        if successSet then
            if modData then
                modData.itemBatteryConsumptionReduction = reduction
            end
            print("ZItemTiers: Applied battery consumption reduction " .. (reduction * 100) .. "% to flashlight: " .. tostring(itemType) .. " (useDelta: " .. tostring(originalUseDelta) .. " -> " .. tostring(reducedUseDelta) .. ")")
        end
    end
end

-- Hook into IsoLightSwitch update to reduce battery drain for world lights
if IsoLightSwitch and IsoLightSwitch.update then
    local originalLightSwitchUpdate = IsoLightSwitch.update
    function IsoLightSwitch:update()
        -- Call original update first
        originalLightSwitchUpdate(self)
        
        -- Check if this light uses battery and has a battery
        if self.useBattery and self.hasBattery and self.activated then
            -- Check if there's a flashlight item associated with this light
            -- (This is tricky - world lights don't directly reference items)
            -- For now, we'll hook into the power drain calculation
            -- The delta is set when the battery is added, so we need to modify it there
        end
    end
end

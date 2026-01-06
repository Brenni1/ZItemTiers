-- Damage multiplier module
-- Stores damage multiplier bonus for HandWeapon items (applied via Java patches)

require "ZItemTiers/core"

-- Apply damage multiplier bonus to a HandWeapon item
-- multiplier: The damage multiplier (e.g., 1.1 for +10%)
-- modData: The item's modData table (required for storing the multiplier)
function ZItemTiers.ApplyDamageMultiplier(item, multiplier, modData)
    if not item or not multiplier or not modData then
        return
    end
    
    if not instanceof(item, "HandWeapon") then
        return
    end
    
    -- Store the damage multiplier in modData - the Java patch will read it and apply it
    modData.itemDamageMultiplier = multiplier
end

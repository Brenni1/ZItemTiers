-- Encumbrance reduction bonus module
-- Applies tier-based encumbrance reduction to InventoryContainer items

require "ZItemTiers/core"

-- Key in modData.ZIT for stored original encumbrance reduction (before tier bonus)
ZItemTiers.ModDataKeyEncumbranceReductionBase = "WeightReduction"

-- Apply encumbrance reduction to an InventoryContainer item
-- bonusValue: The flat encumbrance reduction bonus (e.g., 2 for +2)
function ZItemTiers.ApplyEncumbranceReduction(item, bonusValue)
    if not item or not bonusValue then
        return
    end

    if not instanceof(item, "InventoryContainer") then
        return
    end

    local modData = item:getModData()
    if not modData then
        return
    end
    if not modData.ZIT then
        modData.ZIT = {}
    end
    if not modData.ZIT.baseValues then
        modData.ZIT.baseValues = {}
    end

    -- Get original value: use stored base, or current getWeightReduction() on first apply
    local base = modData.ZIT.baseValues[ZItemTiers.ModDataKeyEncumbranceReductionBase]
    if base == nil and item.getWeightReduction then
        base = item:getWeightReduction()
        if type(base) ~= "number" then
            base = 0
        end
        modData.ZIT.baseValues[ZItemTiers.ModDataKeyEncumbranceReductionBase] = base
    end
    base = base or 0

    local newValue = base + bonusValue
    newValue = math.min(newValue, 85)

    local current = 0
    if item.getWeightReduction then
        current = item:getWeightReduction()
        if type(current) ~= "number" then
            return
        end
    end

    if newValue <= current then
        return
    end

    if item.setWeightReduction then
        item:setWeightReduction(newValue)
    end
end

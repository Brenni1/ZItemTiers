-- Bonus definitions: all bonus-specific logic in one place
-- Each bonus type has: displayName, checkApplicable, and applyBonus

ZItemTiers = ZItemTiers or {}

ZItemTiers.Bonuses = {
    -- DurabilityBonus = {
    --     displayName = "Durability",
    --     checkApplicable = function(item)
    --         if item.getConditionMax then
    --             local success, conditionMax = pcall(item.getConditionMax, item)
    --             return success and conditionMax and conditionMax > 0
    --         end
    --         return false
    --     end,
    --     applyBonus = function(item, multiplier)
    --         local conditionMax = item:getConditionMax()
    --         if conditionMax and conditionMax > 0 then
    --             local newConditionMax = math.floor(conditionMax * multiplier)
    --             local currentCondition = item:getCondition()
                
    --             item:setConditionMax(newConditionMax)
                
    --             if currentCondition > 0 then
    --                 local conditionRatio = currentCondition / conditionMax
    --                 local newCondition = math.floor(newConditionMax * conditionRatio)
    --                 item:setCondition(newCondition)
    --             else
    --                 item:setCondition(newConditionMax)
    --             end
    --         end
    --     end,
    -- },
    
    SpeedBonus = {
        displayName = "Speed",
        checkApplicable = function(item)
            if item.getRunSpeedModifier then
                local success, speedMod = pcall(item.getRunSpeedModifier, item)
                return success and speedMod and speedMod ~= 1.0
            end
            return false
        end,
        applyBonus = function(item, multiplier)
            if item.getRunSpeedModifier then
                local currentSpeedMod = item:getRunSpeedModifier()
                if currentSpeedMod and currentSpeedMod ~= 1.0 then
                    local newSpeedMod = currentSpeedMod * multiplier
                    item:setRunSpeedModifier(newSpeedMod)
                end
            end
        end,
    },
    
    CapacityBonus = {
        displayName = "Capacity",
        checkApplicable = function(item)
            if item.getCapacity then
                local success, capacity = pcall(item.getCapacity, item)
                return success and capacity and capacity > 0
            end
            return false
        end,
        applyBonus = function(item, multiplier)
            if item.getCapacity then
                local currentCapacity = item:getCapacity()
                if currentCapacity and currentCapacity > 0 then
                    local newCapacity = math.floor(currentCapacity * multiplier)
                    item:setCapacity(newCapacity)
                end
            end
        end,
    },
    
    EncumbranceReductionBonus = {
        displayName = "Encumbrance Reduction",
        checkApplicable = function(item)
            if item.getWeightReduction then
                local success, weightReduction = pcall(item.getWeightReduction, item)
                return success and weightReduction and weightReduction > 0
            end
            return false
        end,
        applyBonus = function(item, multiplier)
            if item.getWeightReduction then
                local currentWeightReduction = item:getWeightReduction()
                if currentWeightReduction and currentWeightReduction > 0 then
                    local newWeightReduction = math.floor(currentWeightReduction * multiplier)
                    item:setWeightReduction(math.min(newWeightReduction, 100))  -- Cap at 100%
                end
            end
        end,
    },
    
    ProtectionBonus = {
        displayName = "Protection",
        checkApplicable = function(item)
            if item.getBiteDefense then
                local success1, biteDef = pcall(item.getBiteDefense, item)
                local success2, scratchDef = pcall(item.getScratchDefense, item)
                local success3, bulletDef = pcall(item.getBulletDefense, item)
                return (success1 and biteDef and biteDef > 0) or
                       (success2 and scratchDef and scratchDef > 0) or
                       (success3 and bulletDef and bulletDef > 0)
            end
            return false
        end,
        applyBonus = function(item, multiplier)
            if item.getBiteDefense then
                local currentBiteDef = item:getBiteDefense()
                if currentBiteDef and currentBiteDef > 0 then
                    local newBiteDef = currentBiteDef * multiplier
                    item:setBiteDefense(math.min(newBiteDef, 100.0))  -- Cap at 100
                end
                
                if item.getScratchDefense then
                    local currentScratchDef = item:getScratchDefense()
                    if currentScratchDef and currentScratchDef > 0 then
                        local newScratchDef = currentScratchDef * multiplier
                        item:setScratchDefense(math.min(newScratchDef, 100.0))  -- Cap at 100
                    end
                end
                
                if item.getBulletDefense then
                    local currentBulletDef = item:getBulletDefense()
                    if currentBulletDef and currentBulletDef > 0 then
                        local newBulletDef = currentBulletDef * multiplier
                        item:setBulletDefense(math.min(newBulletDef, 100.0))  -- Cap at 100
                    end
                end
            end
        end,
    },
    
    DamageBonus = {
        displayName = "Damage",
        checkApplicable = function(item)
            if item.getMinDamage and item.getMaxDamage then
                local success1, minDmg = pcall(item.getMinDamage, item)
                local success2, maxDmg = pcall(item.getMaxDamage, item)
                return (success1 and minDmg and minDmg > 0) or
                       (success2 and maxDmg and maxDmg > 0)
            end
            return false
        end,
        applyBonus = function(item, multiplier)
            if item.getMinDamage and item.getMaxDamage then
                local currentMinDmg = item:getMinDamage()
                local currentMaxDmg = item:getMaxDamage()
                
                if currentMinDmg and currentMinDmg > 0 then
                    local newMinDmg = currentMinDmg * multiplier
                    item:setMinDamage(newMinDmg)
                end
                
                if currentMaxDmg and currentMaxDmg > 0 then
                    local newMaxDmg = currentMaxDmg * multiplier
                    item:setMaxDamage(newMaxDmg)
                end
            end
        end,
    },
    
    NutritionBonus = {
        displayName = "Nutrition",
        checkApplicable = function(item)
            if item.getBaseHunger then
                local success, baseHunger = pcall(item.getBaseHunger, item)
                return success and baseHunger and baseHunger ~= 0
            end
            return false
        end,
        applyBonus = function(item, multiplier)
            if item.getBaseHunger then
                local currentBaseHunger = item:getBaseHunger()
                if currentBaseHunger and currentBaseHunger ~= 0 then
                    local newBaseHunger = currentBaseHunger * multiplier
                    item:setBaseHunger(newBaseHunger)
                end
                
                if item.getCalories then
                    local currentCalories = item:getCalories()
                    if currentCalories and currentCalories > 0 then
                        local newCalories = currentCalories * multiplier
                        item:setCalories(newCalories)
                    end
                end
                
                if item.getCarbohydrates then
                    local currentCarbs = item:getCarbohydrates()
                    if currentCarbs and currentCarbs > 0 then
                        local newCarbs = currentCarbs * multiplier
                        item:setCarbohydrates(newCarbs)
                    end
                end
                
                if item.getLipids then
                    local currentLipids = item:getLipids()
                    if currentLipids and currentLipids > 0 then
                        local newLipids = currentLipids * multiplier
                        item:setLipids(newLipids)
                    end
                end
                
                if item.getProteins then
                    local currentProteins = item:getProteins()
                    if currentProteins and currentProteins > 0 then
                        local newProteins = currentProteins * multiplier
                        item:setProteins(newProteins)
                    end
                end
            end
        end,
    },
    
    FreshnessBonus = {
        displayName = "Freshness",
        checkApplicable = function(item)
            if item.getDaysFresh then
                local success, daysFresh = pcall(item.getDaysFresh, item)
                return success and daysFresh and daysFresh > 0
            end
            return false
        end,
        applyBonus = function(item, multiplier)
            if item.getDaysFresh then
                local currentDaysFresh = item:getDaysFresh()
                if currentDaysFresh and currentDaysFresh > 0 then
                    local newDaysFresh = math.floor(currentDaysFresh * multiplier)
                    item:setDaysFresh(newDaysFresh)
                end
                
                if item.getDaysTotallyRotten then
                    local currentDaysRotten = item:getDaysTotallyRotten()
                    if currentDaysRotten and currentDaysRotten > 0 then
                        local newDaysRotten = math.floor(currentDaysRotten * multiplier)
                        item:setDaysTotallyRotten(newDaysRotten)
                    end
                end
            end
        end,
    },
}

-- Helper function to get bonus display name
function ZItemTiers.GetBonusDisplayName(bonusType)
    local bonus = ZItemTiers.Bonuses[bonusType]
    return bonus and bonus.displayName or bonusType
end

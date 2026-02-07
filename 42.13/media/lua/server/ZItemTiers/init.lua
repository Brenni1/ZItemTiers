-- Initialize Item Rarity Mod
-- Applies probability-based rarity system to distribution tables after they're loaded

require "ZItemTiers/core"
require "ZItemTiers/bonus_display"
require "ZItemTiers/items"
require "ZItemTiers/spawn_hooks"
require "ZItemTiers/crafting"
require "ZItemTiers/reading_speed"
require "ZItemTiers/vhs_skill_xp"
require "ZItemTiers/mood_bonus"
require "ZItemTiers/weight_reduction"
require "ZItemTiers/encumbrance_reduction"
require "ZItemTiers/run_speed"
require "ZItemTiers/defense_bonuses"
require "ZItemTiers/capacity_bonus"
require "ZItemTiers/max_encumbrance_bonus"
require "ZItemTiers/drainable_capacity"
require "ZItemTiers/vision_impairment"
require "ZItemTiers/hearing_impairment"
require "ZItemTiers/damage_multiplier"
require "ZItemTiers/hunger_reduction"
require "ZItemTiers/battery_consumption"
require "ZItemTiers/washing"
require "ZItemTiers/moveable_break_chance"

-- Apply rarities after distributions are merged
local function applyLootRarities()
    if not ZItemTiers or not ZItemTiers.Rarities then
        print("ZItemTiers: Failed to load core module")
        return
    end
    
    print("ZItemTiers: Applying probability-based rarity system to distributions...")
    print("ZItemTiers: Rarity probabilities - Common: 60%, Uncommon: 25%, Rare: 10%, Epic: 4%, Legendary: 1%")
    
    -- Apply to ProceduralDistributions
    if ProceduralDistributions and ProceduralDistributions.list then
        local totalTables = 0
        local totalNonTables = 0
        local totalApplied = 0
        local totalNonApplied = 0
        for distName, distTable in pairs(ProceduralDistributions.list) do
            if type(distTable) == "table" then
                totalTables = totalTables + 1
                local applied, nonApplied = ZItemTiers.ApplyRaritiesToDistribution(distTable)
                totalApplied = totalApplied + (applied or 0)
                totalNonApplied = totalNonApplied + (nonApplied or 0)
            else
                totalNonTables = totalNonTables + 1
            end
        end
        print("ZItemTiers: Applied rarities to ProceduralDistributions (tables: " .. totalTables .. ", non-tables: " .. totalNonTables .. ", applied: " .. totalApplied .. ", non-applied: " .. totalNonApplied .. ")")
    end
    
        -- Apply to main Distributions table (room-based)
        if Distributions then
            -- Distributions is an array, process each entry
            local totalTables = 0
            local totalNonTables = 0
            local totalApplied = 0
            local totalNonApplied = 0
            for i = 1, #Distributions do
                local distTable = Distributions[i]
                if distTable then
                    for roomName, roomData in pairs(distTable) do
                        if type(roomData) == "table" then
                            totalTables = totalTables + 1
                            local applied, nonApplied = ZItemTiers.ApplyRaritiesToDistribution(roomData)
                            totalApplied = totalApplied + (applied or 0)
                            totalNonApplied = totalNonApplied + (nonApplied or 0)
                        else
                            totalNonTables = totalNonTables + 1
                        end
                    end
                end
            end
            print("ZItemTiers: Applied rarities to Distributions (tables: " .. totalTables .. ", non-tables: " .. totalNonTables .. ", applied: " .. totalApplied .. ", non-applied: " .. totalNonApplied .. ")")
        end
    
    -- Apply to SuburbsDistributions (final merged table)
    if SuburbsDistributions then
        local totalTables = 0
        local totalNonTables = 0
        local totalApplied = 0
        local totalNonApplied = 0
        for roomName, roomData in pairs(SuburbsDistributions) do
            if type(roomData) == "table" then
                totalTables = totalTables + 1
                local applied, nonApplied = ZItemTiers.ApplyRaritiesToDistribution(roomData)
                totalApplied = totalApplied + (applied or 0)
                totalNonApplied = totalNonApplied + (nonApplied or 0)
            else
                totalNonTables = totalNonTables + 1
            end
        end
        print("ZItemTiers: Applied rarities to SuburbsDistributions (tables: " .. totalTables .. ", non-tables: " .. totalNonTables .. ", applied: " .. totalApplied .. ", non-applied: " .. totalNonApplied .. ")")
    end
    
    -- Apply to VehicleDistributions
    if VehicleDistributions then
        local totalTables = 0
        local totalNonTables = 0
        local totalApplied = 0
        local totalNonApplied = 0
        for vehicleName, vehicleData in pairs(VehicleDistributions) do
            if type(vehicleData) == "table" then
                totalTables = totalTables + 1
                local applied, nonApplied = ZItemTiers.ApplyRaritiesToDistribution(vehicleData)
                totalApplied = totalApplied + (applied or 0)
                totalNonApplied = totalNonApplied + (nonApplied or 0)
            else
                totalNonTables = totalNonTables + 1
            end
        end
        print("ZItemTiers: Applied rarities to VehicleDistributions (tables: " .. totalTables .. ", non-tables: " .. totalNonTables .. ", applied: " .. totalApplied .. ", non-applied: " .. totalNonApplied .. ")")
    end
    
    print("ZItemTiers: Rarity application complete!")
end

-- Hook into distribution merge events
Events.OnPostDistributionMerge.Add(applyLootRarities)

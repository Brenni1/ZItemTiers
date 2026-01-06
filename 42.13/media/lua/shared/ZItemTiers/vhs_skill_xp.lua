-- VHS skill XP bonus hook
-- Applies bonus skill XP when VHS finishes playing

require "ZItemTiers/core"

-- Track VHS playback state per player+device
local vhsPlaybackState = {}

-- Track which functions have been hooked
local hookedFunctions = {}

-- Get non-skill codes that should be excluded when detecting skill codes in VHS tapes
function ZItemTiers.GetNonSkillCodes()
    return {
        RCP = true,  -- Recipe
        BOR = true,  -- Boredom
        UHP = true,  -- Unhappiness
        STS = true,  -- Stress
        ANG = true,  -- Anger
        END = true,  -- Endurance
        FAT = true,  -- Fatigue
        FIT = true,  -- Fitness
        HUN = true,  -- Hunger
        MOR = true,  -- Morale
        FEA = true,  -- Fear
        PAN = true,  -- Panic
        SAN = true,  -- Sanity
        SIC = true,  -- Sickness
        PAI = true,  -- Pain
        DRU = true,  -- Drunkenness
        THI = true,  -- Thirst
    }
end

-- Parse skill codes from a codes string (e.g., "CRP+1,FOR+1")
local function parseSkillCodes(codes)
    if not codes or codes == "" then
        return {}
    end
    
    local skillCodes = {}
    local nonSkillCodes = ZItemTiers.GetNonSkillCodes()
    
    -- Parse codes like "CRP+1", "FOR+1", etc.
    for code in string.gmatch(codes, "([A-Z]+)[+-]?[0-9]*") do
        if not nonSkillCodes[code] then
            -- Check if it's a valid skill code
            local perk = PerkFactory.getPerk(code)
            if perk then
                skillCodes[code] = true
            end
        end
    end
    
    return skillCodes
end

-- Hook into ISRadioAction:performTogglePlayMedia to detect when VHS starts playing
local function setupHooks()
    if not ISRadioAction then
        return false
    end
    
    if not ISRadioAction.performTogglePlayMedia then
        return false
    end
    
    -- Only hook once
    if hookedFunctions.performTogglePlayMedia then
        return true
    end
    
    local originalPerformTogglePlayMedia = ISRadioAction.performTogglePlayMedia
    function ISRadioAction:performTogglePlayMedia()
        -- Call original function first
        originalPerformTogglePlayMedia(self)
        
        -- Check if media is now playing (not stopped)
        if not self.deviceData or not self.deviceData:isPlayingMedia() then
            return
        end
        
        -- Get MediaData
        local mediaData = self.deviceData:getMediaData()
        if not mediaData then
            return
        end
        
        -- Check if this is a VHS
        local itemDisplayName = mediaData:getItemDisplayName()
        if not itemDisplayName or not string.find(itemDisplayName, "VHS") then
            return
        end
        
        -- Get the VHS item (device parent for inventory devices)
        local vhsItem = nil
        if self.deviceData:isInventoryDevice() then
            local parent = self.deviceData:getParent()
            if parent and instanceof(parent, "Radio") then
                vhsItem = parent
            end
        end
        
        if not vhsItem then
            return
        end
        
        -- Check if this VHS has rarity bonus
        local modData = vhsItem:getModData()
        if not modData or not modData.itemVhsSkillXpBonus then
            return
        end
        
        local player = self.character
        if not player then
            return
        end
        
        local mediaId = mediaData:getId()
        local stateKey = tostring(self.deviceData) .. "_" .. mediaId
        
        -- Initialize playback state
        local successGetCount, lineCount = pcall(function()
            if mediaData and mediaData.getLineCount then
                return mediaData:getLineCount()
            end
            return 0
        end)
        
        vhsPlaybackState[stateKey] = {
            vhsItem = vhsItem,
            bonusXp = modData.itemVhsSkillXpBonus,
            mediaId = mediaId,
            skillCodes = {},
            processedGuids = {},
            totalLines = successGetCount and lineCount or 0,
            processedLines = 0,
            player = player
        }
        
        print("ZItemTiers: [VHS] Started playing tiered VHS: " .. itemDisplayName .. ", total lines: " .. tostring(vhsPlaybackState[stateKey].totalLines))
    end
    
    hookedFunctions.performTogglePlayMedia = true
    return true
end

-- Hook into ISRadioInteractions:checkPlayer to detect when last line is processed
local function setupCheckPlayerHook()
    local radioInteractions = ISRadioInteractions:getInstance()
    if not radioInteractions or not radioInteractions.checkPlayer or hookedFunctions.checkPlayer then
        return
    end
    
    local originalCheckPlayer = radioInteractions.checkPlayer
    function radioInteractions:checkPlayer(player, _guid, _interactCodes, _x, _y, _z, _line, _source)
        originalCheckPlayer(self, player, _guid, _interactCodes, _x, _y, _z, _line, _source)
        
        if not _guid or _guid == "" then
            return
        end
        
        -- Find active VHS playback state for this player
        for stateKey, state in pairs(vhsPlaybackState) do
            if state.player == player and not state.processedGuids[_guid] then
                state.processedGuids[_guid] = true
                state.processedLines = state.processedLines + 1
                
                -- Parse skill codes from this line
                if _interactCodes and _interactCodes ~= "" then
                    for skillCode, _ in pairs(parseSkillCodes(_interactCodes)) do
                        state.skillCodes[skillCode] = true
                    end
                end
                
                -- Check if VHS finished
                if state.processedLines >= state.totalLines then
                    -- Apply bonus XP N times, where N = bonusXP / 50
                    local n = math.floor(state.bonusXp / 50)
                    local xpPerApplication = 50
                    
                    print("ZItemTiers: [VHS] VHS finished playing, applying bonus XP " .. tostring(n) .. " times (" .. tostring(xpPerApplication) .. " XP each)")
                    
                    for i = 1, n do
                        local bonusGuid = state.mediaId .. "_" .. tostring(i)
                        
                        -- Only apply if not already applied
                        if not player:isKnownMediaLine(bonusGuid) then
                            player:addKnownMediaLine(bonusGuid)
                            
                            for skillCode, _ in pairs(state.skillCodes) do
                                local perk = PerkFactory.getPerk(skillCode)
                                if perk then
                                    pcall(function()
                                        player:getXp():AddXP(perk, xpPerApplication, false, false, false)
                                        print("ZItemTiers: [VHS] Added " .. tostring(xpPerApplication) .. " XP to " .. skillCode .. " (application " .. tostring(i) .. "/" .. tostring(n) .. ")")
                                    end)
                                end
                            end
                        end
                    end
                    
                    vhsPlaybackState[stateKey] = nil
                end
                break
            end
        end
    end
    
    hookedFunctions.checkPlayer = true
end

-- Set up hooks when game boots (after all modules are loaded)
Events.OnGameBoot.Add(function()
    setupHooks()
    setupCheckPlayerHook()
end)
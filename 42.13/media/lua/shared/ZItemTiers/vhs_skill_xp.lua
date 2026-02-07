-- VHS skill XP bonus hook
-- Applies bonus skill XP when VHS finishes playing

require "ZItemTiers/core"

-- Track VHS playback state per player+device
local vhsPlaybackState = {}

-- Track which functions have been hooked
local hookedFunctions = {}

-- No longer needed - we store rarity in device modData instead

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

-- Get device modData (from deviceData, parent Radio, or IsoObject)
local function getDeviceModData(deviceData)
    if not deviceData then return nil end
    
    -- Try deviceData first
    local successGetDeviceModData, modData = pcall(function()
        if deviceData.getModData then
            return deviceData:getModData()
        end
        return nil
    end)
    if successGetDeviceModData and modData then
        return modData
    end
    
    -- Try parent Radio for inventory devices
    local successIsInventory, isInventory = pcall(function()
        if deviceData.isInventoryDevice then
            return deviceData:isInventoryDevice()
        end
        return false
    end)
    if successIsInventory and isInventory then
        local parent = deviceData:getParent()
        if parent and instanceof(parent, "Radio") then
            local successGetParentModData, parentModData = pcall(function()
                if parent.getModData then
                    return parent:getModData()
                end
                return nil
            end)
            if successGetParentModData and parentModData then
                return parentModData
            end
        end
    else
        -- Try IsoObject for world devices
        local successGetIsoObject, isoObject = pcall(function()
            if deviceData.getIsoObject then
                return deviceData:getIsoObject()
            end
            return nil
        end)
        if successGetIsoObject and isoObject then
            local successGetIsoModData, isoModData = pcall(function()
                if isoObject.getModData then
                    return isoObject:getModData()
                end
                return nil
            end)
            if successGetIsoModData and isoModData then
                return isoModData
            end
        end
    end
    
    return nil
end

-- Check if VHS playback is finished
local function isVhsFinished(state)
    if state.totalLines > 0 then
        return state.processedLines >= state.totalLines
    else
        -- If we don't know totalLines, check if device is still playing
        if state.deviceData then
            local successCheck, isPlaying = pcall(function()
                if state.deviceData.isPlayingMedia then
                    return state.deviceData:isPlayingMedia()
                end
                return false
            end)
            if successCheck and not isPlaying then
                return true
            end
        end
    end
    return false
end

-- Apply bonus XP to player
local function applyBonusXp(state, xpPlayer)
    local n = math.floor(state.bonusXp / 50)
    local xpPerApplication = 50
    
    print("ZItemTiers: [VHS XP] DEBUG: Will apply " .. tostring(n) .. " times, " .. tostring(xpPerApplication) .. " XP each")
    
    local skillCodeCount = 0
    for _ in pairs(state.skillCodes) do
        skillCodeCount = skillCodeCount + 1
    end
    print("ZItemTiers: [VHS XP] DEBUG: Found " .. tostring(skillCodeCount) .. " skill codes")
    
    for i = 1, n do
        local bonusGuid = state.mediaId .. "_" .. tostring(i)
        
        local isKnown = xpPlayer:isKnownMediaLine(bonusGuid)
        print("ZItemTiers: [VHS XP] DEBUG: Checking GUID: " .. bonusGuid .. " - isKnown: " .. tostring(isKnown))
        
        if not isKnown then
            xpPlayer:addKnownMediaLine(bonusGuid)
            print("ZItemTiers: [VHS XP] DEBUG: Added GUID to known list: " .. bonusGuid)
            
            for skillCode, _ in pairs(state.skillCodes) do
                local perk = PerkFactory.getPerk(skillCode)
                if perk then
                    pcall(function()
                        xpPlayer:getXp():AddXP(perk, xpPerApplication, false, false, false)
                        print("ZItemTiers: [VHS XP] DEBUG: Added " .. tostring(xpPerApplication) .. " XP to " .. skillCode .. " (application " .. tostring(i) .. "/" .. tostring(n) .. ")")
                    end)
                else
                    print("ZItemTiers: [VHS XP] DEBUG: WARNING: Could not get perk for skill code: " .. skillCode)
                end
            end
        else
            print("ZItemTiers: [VHS XP] DEBUG: Skipping GUID (already known): " .. bonusGuid)
        end
    end
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
        -- Check if media was playing before toggle (to detect stop)
        local wasPlaying = false
        if self.deviceData then
            local successCheck, playing = pcall(function()
                if self.deviceData.isPlayingMedia then
                    return self.deviceData:isPlayingMedia()
                end
                return false
            end)
            if successCheck then
                wasPlaying = playing
            end
        end
        
        -- Call original function first
        originalPerformTogglePlayMedia(self)
        
        -- Check if media stopped playing (VHS finished)
        if wasPlaying and self.deviceData then
            local successCheck, isPlaying = pcall(function()
                if self.deviceData.isPlayingMedia then
                    return self.deviceData:isPlayingMedia()
                end
                return false
            end)
            
            if successCheck and not isPlaying then
                -- Media stopped, check if we have an active VHS playback state
                local player = self.character
                if player then
                    for stateKey, state in pairs(vhsPlaybackState) do
                        if state.player == player and state.deviceData == self.deviceData then
                            -- VHS stopped playing, apply bonus XP
                            applyBonusXp(state, player)
                            vhsPlaybackState[stateKey] = nil
                            return
                        end
                    end
                end
            end
        end
        
        -- Check if media is now playing (not stopped)
        if not self.deviceData then
            print("ZItemTiers: [VHS XP] DEBUG: No deviceData")
            return
        end
        
        local successCheckPlaying, isPlaying = pcall(function()
            if self.deviceData.isPlayingMedia then
                return self.deviceData:isPlayingMedia()
            end
            return false
        end)
        if not successCheckPlaying or not isPlaying then
            print("ZItemTiers: [VHS XP] DEBUG: Media not playing (successCheck: " .. tostring(successCheckPlaying) .. ", isPlaying: " .. tostring(isPlaying) .. ")")
            return
        end
        
        -- Get MediaData
        local mediaData = self.deviceData:getMediaData()
        if not mediaData then
            print("ZItemTiers: [VHS XP] DEBUG: No mediaData")
            return
        end
        
        -- Check if this is a VHS by checking the device's mediaItem string
        local mediaItemType = nil
        local successGetMediaItem, mediaItem = pcall(function()
            if self.deviceData.getMediaItem then
                return self.deviceData:getMediaItem()
            end
            if self.deviceData.mediaItem then
                return self.deviceData.mediaItem
            end
            return nil
        end)
        if successGetMediaItem and mediaItem then
            mediaItemType = mediaItem
        end
        
        print("ZItemTiers: [VHS XP] DEBUG: mediaItemType: " .. tostring(mediaItemType))
        
        -- Also try to get from MediaData category or type
        if not mediaItemType then
            local successGetCategory, category = pcall(function()
                if mediaData.getCategory then
                    return mediaData:getCategory()
                end
                return nil
            end)
            if successGetCategory and category then
                print("ZItemTiers: [VHS XP] DEBUG: MediaData category: " .. tostring(category))
                if string.find(category, "VHS") then
                    mediaItemType = "VHS" -- Mark as VHS if category contains VHS
                end
            end
        end
        
        if not mediaItemType or not string.find(mediaItemType, "VHS") then
            print("ZItemTiers: [VHS XP] DEBUG: Not a VHS (mediaItemType: " .. tostring(mediaItemType) .. ")")
            return
        end
        
        print("ZItemTiers: [VHS XP] DEBUG: Detected VHS: " .. tostring(mediaItemType))
        
        -- Get VHS modData: inventory devices use item modData, world devices use device modData
        local vhsItem = nil
        local vhsModData = nil
        
        local successIsInventory, isInventory = pcall(function()
            if self.deviceData.isInventoryDevice then
                return self.deviceData:isInventoryDevice()
            end
            return false
        end)
        
        if successIsInventory and isInventory then
            local parent = self.deviceData:getParent()
            if parent and instanceof(parent, "Radio") then
                vhsItem = parent
                vhsModData = vhsItem:getModData()
                print("ZItemTiers: [VHS XP] DEBUG: Found inventory device VHS item")
            end
        else
            vhsModData = getDeviceModData(self.deviceData)
            if vhsModData and vhsModData.vhsSkillXpBonus then
                print("ZItemTiers: [VHS XP] DEBUG: Found world device VHS modData")
            end
        end
        
        -- Check for bonus: inventory devices use itemVhsSkillXpBonus, world devices use vhsSkillXpBonus
        local bonusXp = nil
        if vhsModData then
            bonusXp = vhsModData.itemVhsSkillXpBonus or vhsModData.vhsSkillXpBonus
            if bonusXp then
                print("ZItemTiers: [VHS XP] DEBUG: Found VHS bonus: " .. tostring(bonusXp))
            end
        end
        
        if not bonusXp then
            print("ZItemTiers: [VHS XP] DEBUG: No VHS modData or no bonus (hasModData: " .. tostring(vhsModData ~= nil) .. ", itemBonus: " .. tostring(vhsModData and vhsModData.itemVhsSkillXpBonus) .. ", deviceBonus: " .. tostring(vhsModData and vhsModData.vhsSkillXpBonus) .. ")")
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
        
        local totalLines = successGetCount and lineCount or 0
        
        print("ZItemTiers: [VHS XP] DEBUG: Initializing playback state - bonusXp: " .. tostring(bonusXp) .. ", totalLines: " .. tostring(totalLines) .. ", mediaId: " .. tostring(mediaId))
        
        vhsPlaybackState[stateKey] = {
            vhsItem = vhsItem,
            bonusXp = bonusXp,
            mediaId = mediaId,
            skillCodes = {},
            processedGuids = {},
            totalLines = totalLines,
            processedLines = 0,
            player = player,
            deviceData = self.deviceData  -- Store deviceData to check if still playing
        }
        
        print("ZItemTiers: [VHS XP] DEBUG: Playback state initialized with key: " .. stateKey)
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
        
        print("ZItemTiers: [VHS XP] DEBUG: checkPlayer called - guid: " .. tostring(_guid))
        
        if not _guid or _guid == "" then
            print("ZItemTiers: [VHS XP] DEBUG: checkPlayer - no guid, returning")
            return
        end
        
        -- Find active VHS playback state
        -- Since VHS playback is device-specific and only one can play at a time per device,
        -- we can match any active state (the player check was causing issues)
        local foundState = false
        local stateCount = 0
        for _ in pairs(vhsPlaybackState) do
            stateCount = stateCount + 1
        end
        
        print("ZItemTiers: [VHS XP] DEBUG: checkPlayer - guid: " .. tostring(_guid) .. ", states: " .. tostring(stateCount))
        
        if stateCount == 0 then
            print("ZItemTiers: [VHS XP] DEBUG: checkPlayer - WARNING: No states in vhsPlaybackState table!")
        end
        
        -- Just use the first (and likely only) active state
        -- In practice, there should only be one active VHS playback at a time per device
        for stateKey, state in pairs(vhsPlaybackState) do
            foundState = true
            print("ZItemTiers: [VHS XP] DEBUG: checkPlayer - found state " .. stateKey .. ", guid: " .. tostring(_guid) .. ", already processed: " .. tostring(state.processedGuids[_guid] ~= nil))
                
                if not state.processedGuids[_guid] then
                    state.processedGuids[_guid] = true
                    state.processedLines = state.processedLines + 1
                    
                    -- Parse skill codes from this line
                    if _interactCodes and _interactCodes ~= "" then
                        for skillCode, _ in pairs(parseSkillCodes(_interactCodes)) do
                            state.skillCodes[skillCode] = true
                            print("ZItemTiers: [VHS XP] DEBUG: Found skill code: " .. skillCode)
                        end
                    end
                    
                    print("ZItemTiers: [VHS XP] DEBUG: Progress - " .. state.processedLines .. "/" .. state.totalLines .. " lines processed, " .. tostring(state.bonusXp) .. " bonus XP")
                    
                    if isVhsFinished(state) then
                        print("ZItemTiers: [VHS XP] DEBUG: VHS finished! Applying bonus XP")
                        
                        local xpPlayer = state.player or player
                        applyBonusXp(state, xpPlayer)
                        
                        vhsPlaybackState[stateKey] = nil
                        print("ZItemTiers: [VHS XP] DEBUG: Cleared playback state")
                    end
                    break
                end
        end
        
        if not foundState then
            print("ZItemTiers: [VHS XP] DEBUG: checkPlayer - no active state found for player")
        end
    end
    
    hookedFunctions.checkPlayer = true
end

-- Hook into ISRadioAction:performAddMedia to store VHS rarity when inserted
local function setupAddMediaHook()
    if not ISRadioAction then
        return false
    end
    
    if not ISRadioAction.performAddMedia then
        return false
    end
    
    -- Only hook once
    if hookedFunctions.performAddMedia then
        return true
    end
    
    local originalPerformAddMedia = ISRadioAction.performAddMedia
    function ISRadioAction:performAddMedia()
        -- Get the VHS item being inserted
        if self.secondaryItem and self.deviceData then
            local successType, itemType = pcall(function()
                return self.secondaryItem:getFullType()
            end)
            
            if successType and itemType and string.find(itemType, "VHS") then
                local itemModData = self.secondaryItem:getModData()
                if itemModData and itemModData.itemRarity then
                    local deviceModData = getDeviceModData(self.deviceData)
                    if deviceModData then
                        deviceModData.vhsRarity = itemModData.itemRarity
                        deviceModData.vhsSkillXpBonus = itemModData.itemVhsSkillXpBonus
                        deviceModData.vhsItemType = itemType
                    else
                        print("ZItemTiers: [VHS] WARNING: Could not get device modData to store rarity for: " .. itemType)
                    end
                end
            end
        end
        
        -- Call original function
        return originalPerformAddMedia(self)
    end
    
    hookedFunctions.performAddMedia = true
    return true
end

-- Hook into ISRadioAction:performRemoveMedia to preserve VHS rarity when ejected
local function setupRemoveMediaHook()
    if not ISRadioAction then
        return false
    end
    
    if not ISRadioAction.performRemoveMedia then
        return false
    end
    
    -- Only hook once
    if hookedFunctions.performRemoveMedia then
        return true
    end
    
    local originalPerformRemoveMedia = ISRadioAction.performRemoveMedia
    function ISRadioAction:performRemoveMedia()
        -- Get rarity from device modData before removal
        local storedRarity = nil
        local storedBonus = nil
        local itemType = nil
        local deviceModData = nil
        
        if self.deviceData then
            deviceModData = getDeviceModData(self.deviceData)
            
            if deviceModData and deviceModData.vhsRarity then
                storedRarity = deviceModData.vhsRarity
                storedBonus = deviceModData.vhsSkillXpBonus
                itemType = deviceModData.vhsItemType
            end
            
            -- Get item type from DeviceData as fallback
            if not itemType and self.deviceData:hasMedia() then
                local successGetType, typeValue = pcall(function()
                    if self.deviceData.getMediaItem then
                        return self.deviceData:getMediaItem()
                    end
                    if self.deviceData.mediaItem then
                        return self.deviceData.mediaItem
                    end
                    return nil
                end)
                if successGetType and typeValue then
                    itemType = typeValue
                end
            end
        end
        
        -- Get character and inventory
        local character = self.character
        local inventory = nil
        if character then
            local successGetInv, inv = pcall(function()
                if character.getInventory then
                    return character:getInventory()
                end
                return nil
            end)
            if successGetInv and inv then
                inventory = inv
            end
        end
        
        -- Call original function to remove media (this creates a new item and adds it to inventory)
        -- Try to get the newly created item directly from removeMediaItem
        local newlyCreatedItem = nil
        if self.deviceData and self.deviceData:hasMedia() and inventory then
            local successGetItem, item = pcall(function()
                if self.deviceData.removeMediaItem then
                    return self.deviceData:removeMediaItem(inventory)
                end
                return nil
            end)
            if successGetItem and item then
                newlyCreatedItem = item
            end
        end
        
        -- If we didn't get the item directly, call the original function
        if not newlyCreatedItem then
            originalPerformRemoveMedia(self)
        end
        
        -- Restore rarity to newly created item (do this BEFORE clearing device modData)
        if storedRarity and itemType and string.find(itemType, "VHS") then
            -- If we got the item directly, restore to it immediately (BEFORE spawn_hooks can process it)
            if newlyCreatedItem then
                local modData = newlyCreatedItem:getModData()
                if modData then
                    -- Set flag FIRST to prevent spawn_hooks from processing this item
                    modData._vhsRestoring = true
                    
                    -- Set rarity in modData (override any Common rarity that spawn_hooks might have set)
                    modData.itemRarity = storedRarity
                    if storedBonus then
                        modData.itemVhsSkillXpBonus = storedBonus
                    end
                    
                    -- Re-apply bonuses
                    if ZItemTiers and ZItemTiers.ApplyRarityBonuses then
                        ZItemTiers.ApplyRarityBonuses(newlyCreatedItem, storedRarity)
                    end
                    
                    -- Mark as restored and remove restoring flag
                    modData._vhsRestored = true
                    modData._vhsRestoring = nil
                    
                    -- Clear stored rarity from device modData
                    if deviceModData then
                        deviceModData.vhsRarity = nil
                        deviceModData.vhsSkillXpBonus = nil
                        deviceModData.vhsItemType = nil
                    end
                    return
                end
            end
            
            -- Fallback: search inventory if we didn't get the item directly
            if inventory then
                local successGetItems, items = pcall(function()
                    if inventory.getItems then
                        return inventory:getItems()
                    end
                    return nil
                end)
                
                local restored = false
                if successGetItems and items then
                    for i = 0, items:size() - 1 do
                        local item = items:get(i)
                        if item then
                            local successType, foundType = pcall(function()
                                return item:getFullType()
                            end)
                            
                            if successType and foundType == itemType then
                                local modData = item:getModData()
                                if modData and (not modData.itemRarity or modData.itemRarity == "Common") and not modData._vhsRestored then
                                    -- Set flag FIRST to prevent spawn_hooks from processing this item
                                    modData._vhsRestoring = true
                                    
                                    -- Set rarity in modData
                                    modData.itemRarity = storedRarity
                                    if storedBonus then
                                        modData.itemVhsSkillXpBonus = storedBonus
                                    end
                                    
                                    -- Re-apply bonuses
                                    if ZItemTiers and ZItemTiers.ApplyRarityBonuses then
                                        ZItemTiers.ApplyRarityBonuses(item, storedRarity)
                                    end
                                    
                                    -- Mark as restored and remove restoring flag
                                    modData._vhsRestored = true
                                    modData._vhsRestoring = nil
                                    
                                    -- Clear stored rarity from device modData only after successful restore
                                    if deviceModData then
                                        deviceModData.vhsRarity = nil
                                        deviceModData.vhsSkillXpBonus = nil
                                        deviceModData.vhsItemType = nil
                                    end
                                    
                                    restored = true
                                    break
                                end
                            end
                        end
                    end
                end
                
                -- Fallback: Use OnTick if immediate restore failed
                if not restored then
                local ticksWaited = 0
                Events.OnTick.Add(function()
                    ticksWaited = ticksWaited + 1
                    
                    local successGetItems2, items2 = pcall(function()
                        if inventory.getItems then
                            return inventory:getItems()
                        end
                        return nil
                    end)
                    
                    if successGetItems2 and items2 then
                        for i = 0, items2:size() - 1 do
                            local item = items2:get(i)
                            if item then
                                local successType, foundType = pcall(function()
                                    return item:getFullType()
                                end)
                                
                                if successType and foundType == itemType then
                                    local modData = item:getModData()
                                    if modData and (not modData.itemRarity or modData.itemRarity == "Common") and not modData._vhsRestored then
                                        modData._vhsRestoring = true
                                        modData.itemRarity = storedRarity
                                        if storedBonus then
                                            modData.itemVhsSkillXpBonus = storedBonus
                                        end
                                        
                                        if ZItemTiers and ZItemTiers.ApplyRarityBonuses then
                                            ZItemTiers.ApplyRarityBonuses(item, storedRarity)
                                        end
                                        
                                        modData._vhsRestored = true
                                        modData._vhsRestoring = nil
                                        
                                        -- Clear stored rarity from device modData
                                        if deviceModData then
                                            deviceModData.vhsRarity = nil
                                            deviceModData.vhsSkillXpBonus = nil
                                            deviceModData.vhsItemType = nil
                                        end
                                        
                                        return false
                                    end
                                end
                            end
                        end
                    end
                    
                    if ticksWaited >= 10 then
                        return false
                    end
                    return true
                end)
            end
            end
        end
    end
    
    hookedFunctions.performRemoveMedia = true
    return true
end

-- Set up hooks when game boots (after all modules are loaded)
Events.OnGameBoot.Add(function()
    print("ZItemTiers: [VHS XP] Setting up hooks...")
    local hooksResult = setupHooks()
    print("ZItemTiers: [VHS XP] setupHooks result: " .. tostring(hooksResult))
    setupCheckPlayerHook()
    local addMediaResult = setupAddMediaHook()
    print("ZItemTiers: [VHS XP] setupAddMediaHook result: " .. tostring(addMediaResult))
    local removeMediaResult = setupRemoveMediaHook()
    print("ZItemTiers: [VHS XP] setupRemoveMediaHook result: " .. tostring(removeMediaResult))
    print("ZItemTiers: [VHS XP] Hooks setup complete")
end)
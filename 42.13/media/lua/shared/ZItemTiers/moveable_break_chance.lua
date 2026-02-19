-- Reduce break chance when picking up moveables with higher tier instruments
-- Reduces break chance by 5% per tier (Uncommon: -5%, Rare: -10%, Epic: -15%, Legendary: -20%)

require "ZItemTiers/core"

-- Track if hook is already set up
local hookSetup = false

-- Hook into ISMoveableSpriteProps:getBreakChance to reduce break chance based on tool rarity
local function setupMoveableBreakChanceHook()
    if hookSetup then
        return  -- Already set up
    end
    
    local ISMoveableSpriteProps = ISMoveableSpriteProps
    if not ISMoveableSpriteProps then
        return
    end
    
    local originalGetBreakChance = ISMoveableSpriteProps.getBreakChance
    if not originalGetBreakChance then
        return
    end
    
    function ISMoveableSpriteProps:getBreakChance(_player)
        -- Call original function to get base break chance
        local breakChance = originalGetBreakChance(self, _player)
        
--        print("ZItemTiers: [Moveable] getBreakChance called - base: " .. tostring(breakChance) .. ", isMoveable: " .. tostring(self.isMoveable) .. ", canBreak: " .. tostring(self.canBreak) .. ", pickUpTool: " .. tostring(self.pickUpTool))
        
        -- If no break chance or no player, return original value
        if not breakChance or breakChance <= 0 or not _player then
--            print("ZItemTiers: [Moveable] Early return - breakChance: " .. tostring(breakChance) .. ", player: " .. tostring(_player ~= nil))
            return breakChance
        end
        
        -- Only apply if this is a moveable that can break and requires a tool
        if not self.isMoveable or not self.canBreak or not self.pickUpTool then
--            print("ZItemTiers: [Moveable] Early return - conditions not met")
            return breakChance
        end
        
        -- Get tool definition to find all possible tool item types (exact same as hasTool)
        local toolDef = nil
        local successGetToolDef, result = pcall(function()
            -- Copy exact line from hasTool: local toolDef = ISMoveableDefinitions:getInstance().getToolDefinition(tool);
            if ISMoveableDefinitions and ISMoveableDefinitions.getInstance then
                local instance = ISMoveableDefinitions:getInstance()
                if instance then
                    -- This is the exact syntax from hasTool
                    return instance.getToolDefinition(self.pickUpTool)
                end
            end
            return nil
        end)
        
--        print("ZItemTiers: [Moveable] getToolDefinition - success: " .. tostring(successGetToolDef) .. ", result: " .. tostring(result) .. ", result type: " .. type(result) .. ", pickUpTool: " .. tostring(self.pickUpTool))
        
        if successGetToolDef and result then
            toolDef = result
            -- Try to access items in different ways
            local hasItems = false
            local itemsValue = nil
            
            -- Try direct access
            local successDirect, directItems = pcall(function()
                return toolDef.items
            end)
            if successDirect and directItems then
                hasItems = true
                itemsValue = directItems
                print("ZItemTiers: [Moveable] Found items via direct access, type: " .. type(itemsValue))
            else
                -- Try method call
                local successMethod, methodItems = pcall(function()
                    if toolDef.getItems then
                        return toolDef:getItems()
                    end
                    return nil
                end)
                if successMethod and methodItems then
                    hasItems = true
                    itemsValue = methodItems
                    print("ZItemTiers: [Moveable] Found items via method call, type: " .. type(itemsValue))
                else
                    -- Try to inspect the toolDef
                    print("ZItemTiers: [Moveable] ToolDef keys: " .. tostring(toolDef))
                    for k, v in pairs(toolDef) do
                        print("ZItemTiers: [Moveable] ToolDef key: " .. tostring(k) .. ", value type: " .. type(v))
                    end
                end
            end
            
            if not hasItems or not itemsValue then
                print("ZItemTiers: [Moveable] No items found in toolDef")
                return breakChance
            end
            
            toolDef.items = itemsValue
        else
            -- Fallback: use hasTool to get a sample tool, then find all tools of that type
            print("ZItemTiers: [Moveable] getToolDefinition returned nil, using hasTool fallback")
            
            local inventory = nil
            local successGetInventory, inv = pcall(function()
                if _player.getInventory then
                    return _player:getInventory()
                end
                return nil
            end)
            if successGetInventory and inv then
                inventory = inv
            end
            
            if not inventory then
                print("ZItemTiers: [Moveable] No inventory found")
                return breakChance
            end
            
            -- Use hasTool to get one tool
            local sampleTool = nil
            local successHasTool, result = pcall(function()
                if self.hasTool then
                    return self:hasTool(_player, "pickup")
                end
                return nil
            end)
            
            if successHasTool and result then
                sampleTool = result
            end
            
            if not sampleTool then
                print("ZItemTiers: [Moveable] No tool found via hasTool")
                return breakChance
            end
            
            -- Get the type of the tool we found
            local toolType = nil
            local successGetType, typeResult = pcall(function()
                if sampleTool.getFullType then
                    return sampleTool:getFullType()
                end
                return nil
            end)
            if successGetType and typeResult then
                toolType = typeResult
            end
            
            if not toolType then
                print("ZItemTiers: [Moveable] Could not get tool type")
                return breakChance
            end
            
            print("ZItemTiers: [Moveable] Sample tool type: " .. toolType)
            
            -- Find all tools of this type and pick the one with highest rarity
            local bestTool = nil
            local bestTierIndex = 0
            
            local successGetAll, allTools = pcall(function()
                if inventory.getAllTypeRecurse then
                    return inventory:getAllTypeRecurse(toolType)
                elseif inventory.getAllType then
                    return inventory:getAllType(toolType)
                end
                return nil
            end)
            
            if successGetAll and allTools then
                local successSize, size = pcall(function()
                    if allTools.size then
                        return allTools:size()
                    end
                    return 0
                end)
                
                if successSize and size then
                    for i = 0, size - 1 do
                        local successGet, item = pcall(function()
                            if allTools.get then
                                return allTools:get(i)
                            end
                            return nil
                        end)
                        
                        if successGet and item then
                            local rarity = ZItemTiers.GetItemRarity(item)
                            if rarity then
                                local rarityData = ZItemTiers.Rarities[rarity]
                                if rarityData then
                                    local tierIndex = rarityData.index
                                    if tierIndex > bestTierIndex then
                                        bestTool = item
                                        bestTierIndex = tierIndex
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            -- Apply reduction if we found a tool with rarity
            if bestTool and bestTierIndex > 1 then
                local rarity = ZItemTiers.GetItemRarity(bestTool)
                print("ZItemTiers: [Moveable] Best tool found: " .. tostring(bestTool:getFullType()) .. " (rarity: " .. tostring(rarity) .. ", tier: " .. bestTierIndex .. ")")
                
                local reduction = (bestTierIndex - 1) * 5
                local newBreakChance = math.max(0, breakChance - reduction)
                print("ZItemTiers: [Moveable] Reducing break chance from " .. breakChance .. "% to " .. newBreakChance .. "% (reduction: " .. reduction .. "%)")
                return newBreakChance
            else
                print("ZItemTiers: [Moveable] No tool with rarity found (bestTierIndex: " .. bestTierIndex .. ")")
            end
            
            return breakChance
        end
        
        -- Get inventory and find all tools of the required types
        local inventory = nil
        local successGetInventory, inv = pcall(function()
            if _player.getInventory then
                return _player:getInventory()
            end
            return nil
        end)
        if successGetInventory and inv then
            inventory = inv
        end
        
        if not inventory then
            print("ZItemTiers: [Moveable] No inventory found")
            return breakChance
        end
        
        -- Find all tools of the required types and pick the one with highest rarity
        local bestTool = nil
        local bestTierIndex = 0
        
        for _, itemType in ipairs(toolDef.items) do
            local successGetAll, allItems = pcall(function()
                if inventory.getAllTypeRecurse then
                    return inventory:getAllTypeRecurse(itemType)
                elseif inventory.getAllType then
                    return inventory:getAllType(itemType)
                end
                return nil
            end)
            
            if successGetAll and allItems then
                local successSize, size = pcall(function()
                    if allItems.size then
                        return allItems:size()
                    end
                    return 0
                end)
                
                if successSize and size then
                    for i = 0, size - 1 do
                        local successGet, item = pcall(function()
                            if allItems.get then
                                return allItems:get(i)
                            end
                            return nil
                        end)
                        
                        if successGet and item then
                            local rarity = ZItemTiers.GetItemRarity(item)
                            if rarity then
                                local rarityData = ZItemTiers.Rarities[rarity]
                                if rarityData then
                                    local tierIndex = rarityData.index
                                    if tierIndex > bestTierIndex then
                                        bestTool = item
                                        bestTierIndex = tierIndex
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- If we found a tool with rarity, apply the reduction
        if bestTool and bestTierIndex > 1 then
            local rarity = ZItemTiers.GetItemRarity(bestTool)
            print("ZItemTiers: [Moveable] Best tool found: " .. tostring(bestTool:getFullType()) .. " (rarity: " .. tostring(rarity) .. ", tier: " .. bestTierIndex .. ")")
            
            -- Reduce break chance by 5% per tier (tier 2 = -5%, tier 3 = -10%, etc.)
            local reduction = (bestTierIndex - 1) * 5
            local newBreakChance = math.max(0, breakChance - reduction)
            print("ZItemTiers: [Moveable] Reducing break chance from " .. breakChance .. "% to " .. newBreakChance .. "% (reduction: " .. reduction .. "%)")
            return newBreakChance
        else
            print("ZItemTiers: [Moveable] No tool with rarity found (bestTierIndex: " .. bestTierIndex .. ")")
        end
        
        return breakChance
    end
    
    hookSetup = true
    print("ZItemTiers: [Moveable] Break chance hook set up successfully")
end

-- Initialize the hook
Events.OnGameBoot.Add(function()
    -- Try to set up immediately
    setupMoveableBreakChanceHook()
    
    -- Also try after a short delay in case ISMoveableSpriteProps loads later
    if not hookSetup then
        Events.OnTick.Add(function()
            if hookSetup then
                return false  -- Already set up, remove handler
            end
            if ISMoveableSpriteProps and ISMoveableSpriteProps.getBreakChance then
                setupMoveableBreakChanceHook()
                return false  -- Remove this event handler
            end
            return true
        end)
    end
end)

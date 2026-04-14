-- inherit source item tier when cutting down rags in the sewing machine
-- TODO: respect the machine's tier as well

--ZItemTiers = ZItemTiers or {}
--
--function ZItemTiers.DrawTierBadge(x, y, tierIndex0)
--    local badge = ZItemTiers.Badges[tierIndex0]
--    if badge then
--        badge:draw(x, y)
--    end
--end

Events.OnGameBoot.Add(function()
--    if not ISSewingMachineCutDownRagsPanel then return end
--
--    zdk.hook({
--        ISSewingMachineCutDownRagsPanel = {
--            onActionComplete = function(orig, self, metadata, ...)
--                metadata = metadata or self.metadata -- future-proof
--
--                -- sanity check
--                if not metadata or not metadata.selectedItem or not self.player then return orig(self, metadata, ...) end
--
--                return ZItemTiers.AutoTierCraftedItems({
--                    src    = { metadata.selectedItem },
--                    tools  = { zdk.dig(self, "ogrimMachineUI", "machine") },
--                    player = self.player,
--                    perk   = Perks.Tailoring,
--                }, orig, self, metadata, ...)
--            end
--        }
--    })

    if not ISOgrimMachinesUseAction then return end

    -- selected item title
    local function patchedDrawTitleControls(orig, self, ...)
        local selectedItem = self.getSelectedData and self:getSelectedData()
        while selectedItem do
            local t0 = ZItemTiers.GetItemTierIndex0(selectedItem)
            if t0 <= 0 then break end

            return zdk.scoped_hook({
                [self] = {
                    drawText = function(origDrawText, self2, text, x, y, r, g, b, a, font, ...)
                        if font == UIFont.Large and text == selectedItem:getDisplayName() then
                            local c = ZItemTiers.GetTierColor(t0)
                            r, g, b = c.r, c.g, c.b
                        end
                        return origDrawText(self2, text, x, y, r, g, b, a, font, ...)
                    end
                }
            }, orig, self, ...)
        end
        return orig(self, ...)
    end

    -- items list
    local function patchedCreateRecipeListPanel(orig, self, ...)
        local result = orig(self, ...)
        zdk.hook({
            [self.recipeListPanel] = {
                doDrawItem = function(orig, _self, _y, _item, ...)
                    local inventoryItem = _item and _item.item
                    while inventoryItem do
                        if not inventoryItem.getDisplayName or not inventoryItem:getDisplayName() then break end

                        local t0 = ZItemTiers.GetItemTierIndex0(inventoryItem)
                        if t0 <= 0 then break end

                        return zdk.scoped_hook({
                            [_self] = {
                                drawText = function(origDrawText, self2, text, x, y, r, g, b, a, font, ...)
                                    if font == UIFont.Small and luautils.stringStarts(text, inventoryItem:getDisplayName()) then -- TODO: handle WrapText
                                        local c = ZItemTiers.GetTierColor(t0)
                                        r, g, b = c.r, c.g, c.b
                                    end
                                    return origDrawText(self2, text, x, y, r, g, b, a, font, ...)
                                end
                            }
                        }, orig, _self, _y, _item, ...)
                    end
                    return orig(_self, _y, _item, ...)
                end
            }
        })
        return result
    end

    zdk.hook({
        ISOgrimMachinesUseAction = {
            perform = function(orig, self, ...)
                local metadata = self.metadata
                if not metadata or not metadata.selectedItem or not self.character then return orig(self, ...) end

                zdk.logger:debug("metadata = %s", metadata)
                zdk.logger:debug("machine  = %s", metadata.machine)

                return ZItemTiers.AutoTierCraftedItems({
                    src    = { metadata.selectedItem },
                    tools  = { metadata.machine },
                    player = self.character,
                    perk   = Perks.Tailoring,
                }, orig, self, ...)
            end
        },

        -- draw item tier in the sewing UI
        ISSewingMachineRepairPanel = {
            drawTitleControls     = patchedDrawTitleControls,
            createRecipeListPanel = patchedCreateRecipeListPanel,
        },
        ISSewingMachineCutDownRagsPanel = {
            drawTitleControls     = patchedDrawTitleControls,
            createRecipeListPanel = patchedCreateRecipeListPanel,
        },
    })
end)

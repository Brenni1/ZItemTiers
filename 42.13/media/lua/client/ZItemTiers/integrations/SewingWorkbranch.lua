-- inherit source item tier when cutting down rags in the sewing machine
-- TODO: respect the machine's tier as well
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

    zdk.hook({
        ISOgrimMachinesUseAction = {
            perform = function(orig, self, ...)
                local metadata = self.metadata
                if not metadata or not metadata.selectedItem or not self.player then return orig(self, ...) end

                return ZItemTiers.AutoTierCraftedItems({
                    src    = { metadata.selectedItem },
                    -- tools  = { zdk.dig(self, "ogrimMachineUI", "machine") },
                    player = self.character,
                    perk   = Perks.Tailoring,
                }, orig, self, ...)
            end
        }
    })
end)

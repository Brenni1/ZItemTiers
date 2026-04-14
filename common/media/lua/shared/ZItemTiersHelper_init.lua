if not ZItemTiersHelper then
    print("ZItemTiersHelper not found, ZombieBuddy not installed? skipping java patches")
    return
end

Events.OnGameBoot.Add(function()
    ZItemTiersHelper.Reset();
end)

zdk.augment_metatable( Clothing.class, {
    setCorpseSicknessDefense = function(self, value) ZItemTiersHelper.SetCustomAttribute(self, "CorpseSicknessDefense", value) end,
    setDiscomfortModifier    = function(self, value) ZItemTiersHelper.SetCustomAttribute(self, "DiscomfortModifier", value) end,
    setHearingModifier       = function(self, value) ZItemTiersHelper.SetCustomAttribute(self, "HearingModifier", value) end,
    setVisionModifier        = function(self, value) ZItemTiersHelper.SetCustomAttribute(self, "VisionModifier", value) end,
})

zdk.augment_metatable( InventoryContainer.class, {
    setMaxItemSize           = function(self, value) ZItemTiersHelper.SetCustomAttribute(self, "MaxItemSize", value) end,
})

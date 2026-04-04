if not ZItemTiersHelper then
    print("ZItemTiersHelper not found, ZombieBuddy not installed? skipping java patches")
    return
end

Events.OnGameBoot.Add(function()
    ZItemTiersHelper.Reset();
end)

local item = instanceItem("Base.Belt2")
zdk.patch_metatable(item, {
    setDiscomfortModifier = function(self, value) ZItemTiersHelper.SetCustomAttribute(self, "DiscomfortModifier", value) end,
    setHearingModifier    = function(self, value) ZItemTiersHelper.SetCustomAttribute(self, "HearingModifier", value) end,
    setVisionModifier     = function(self, value) ZItemTiersHelper.SetCustomAttribute(self, "VisionModifier", value) end,
})

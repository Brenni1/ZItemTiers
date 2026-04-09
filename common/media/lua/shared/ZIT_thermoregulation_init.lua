zdk.augment_metatable( Clothing.class, {
    getThermoregulation = function(self)
        local zit = ZItemTiers.GetZIT(self)
        return zit and zit.thermoregulation or 0
    end,

    setThermoregulation = function(self, value)
        local zit = ZItemTiers.GetOrCreateZIT(self)
        zit.thermoregulation = value
    end,
})

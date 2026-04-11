ZItemTiers = ZItemTiers or {}

-- Blacklist of items that should never have tier assigned
-- Items in this list will never receive tier bonuses
ZItemTiers.NoTierItems = {
    getDisplayCategory = {
        ["Ammo"] = true,
    },
    getFullType = {
        ["Base.Brochure"]           = true,
        ["Base.CarKey"]             = true,
        ["Base.CombinationPadlock"] = true,
        ["Base.Flier"]              = true,
        ["Base.GolfTee"]            = true,
        ["Base.IDcard"]             = true,
        ["Base.IDcard_Female"]      = true,
        ["Base.IDcard_Male"]        = true,
        ["Base.Key_Blank"]          = true,
        ["Base.Key1"]               = true,
        ["Base.KeyPadlock"]         = true,
        ["Base.Map"]                = true,
        ["Base.Money"]              = true,
        ["Base.Padlock"]            = true,
        ["Base.Splinters"]          = true,
        ["Base.UnusableWood"]       = true,
        ["Base.VHS_Retail"]         = true,
    }
}

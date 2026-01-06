-- Reading speed bonus hook for Literature items
-- Hooks into ISReadABook:getDuration() to apply rarity-based reading speed bonuses

require "ZItemTiers/core"

-- Hook into ISReadABook:getDuration() to apply reading speed bonus
if ISReadABook and ISReadABook.getDuration then
    local originalGetDuration = ISReadABook.getDuration
    
    function ISReadABook:getDuration()
        -- Call original function to get base duration
        local duration = originalGetDuration(self)
        
        -- Apply reading speed bonus if item has one
        if self.item then
            local modData = self.item:getModData()
            if modData and modData.itemReadingSpeedBonus then
                local bonus = modData.itemReadingSpeedBonus
                -- Reading speed bonus reduces reading time
                -- +10% reading speed = 10% faster = time * (1 - 0.1) = time * 0.9
                duration = duration * (1.0 - bonus)
            end
        end
        
        return duration
    end
    
    print("ZItemTiers: Hooked into ISReadABook:getDuration() for reading speed bonus")
end

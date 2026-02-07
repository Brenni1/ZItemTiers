package me.zed_0xff.itemtiers;

import me.zed_0xff.zombie_buddy.Patch;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.inventory.types.InventoryContainer;

/**
 * Optional Java patches for InventoryContainer items.
 * This patch applies rarity-based max item encumbrance bonus to InventoryContainer.getMaxItemSize().
 * 
 * Note: maxItemSize is read from script item, so we need to patch getMaxItemSize() to apply the bonus.
 * 
 * If this patch is not loaded, max item encumbrance bonus will be disabled.
 */
public class Patch_InventoryContainer {
    
    // Helper function to get max encumbrance bonus (flat additive value) from Lua modData
    public static float getMaxEncumbranceBonus(InventoryContainer container) {
        try {
            // Get modData from the container
            Object modDataObj = container.getModData();
            if (modDataObj instanceof KahluaTable) {
                KahluaTable modData = (KahluaTable) modDataObj;
                Object bonusObj = modData.rawget("itemMaxEncumbranceBonus");
                if (bonusObj != null) {
                    float bonus = ((Number) bonusObj).floatValue();
                    return bonus;
                }
            }
        } catch (Exception e) {
            // Silently ignore exceptions
        }
        return 0.0f;
    }
    
    /**
     * Patch InventoryContainer.getMaxItemSize() to apply rarity-based max encumbrance bonus.
     * Uses OnExit to modify the return value without duplicating the original method logic.
     */
    @Patch(className = "zombie.inventory.types.InventoryContainer", methodName = "getMaxItemSize")
    public static class Patch_getMaxItemSize {
        @Patch.OnExit
        public static void onExit(@Patch.This InventoryContainer self, @Patch.Return(readOnly = false) float returnValue) {
            // Only apply bonus if maxItemSize > 0 (some containers don't have this restriction)
            if (returnValue > 0.0f) {
                // Apply rarity-based max encumbrance bonus (flat additive)
                float bonus = getMaxEncumbranceBonus(self);
                if (bonus > 0.0f) {
                    returnValue = returnValue + bonus;
                }
            }
        }
    }
}

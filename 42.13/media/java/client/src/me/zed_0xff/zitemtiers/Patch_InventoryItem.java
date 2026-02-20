package me.zed_0xff.itemtiers;

import me.zed_0xff.zombie_buddy.Patch;
import zombie.inventory.InventoryItem;
import zombie.inventory.types.Clothing;
import se.krka.kahlua.vm.KahluaTable;

/**
 * Optional Java patches for InventoryItem.
 * This patch applies tier-based vision impairment reduction to InventoryItem.getVisionModifier().
 * 
 * If this patch is not loaded, vision impairment reduction will be disabled.
 */
public class Patch_InventoryItem {
    
    /**
     * Patch InventoryItem.getVisionModifier() to apply tier-based vision impairment reduction.
     * Vision modifier < 1.0 means impairment, so we increase it (make it closer to 1.0) based on tier.
     * Uses OnExit to modify the return value without duplicating the original method logic.
     */
    @Patch(className = "zombie.inventory.InventoryItem", methodName = "getVisionModifier")
    public static class Patch_getVisionModifier {
        @Patch.OnExit
        public static void onExit(@Patch.This InventoryItem self, @Patch.Return(readOnly = false) float returnValue) {
            // Only apply to Clothing items
            if (!(self instanceof Clothing)) {
                return;
            }
            
            // Get vision impairment reduction from modData
            try {
                Object modDataObj = self.getModData();
                if (modDataObj instanceof KahluaTable) {
                    KahluaTable modData = (KahluaTable) modDataObj;
                    Object reductionObj = modData.rawget("itemVisionImpairmentReduction");
                    if (reductionObj != null) {
                        float reduction = ((Number) reductionObj).floatValue();
                        // Vision modifier < 1.0 means impairment, so we increase it (make it closer to 1.0)
                        // Cap at 1.0 (no impairment)
                        if (returnValue < 1.0f) {
                            returnValue = Math.min(1.0f, returnValue + reduction);
                        }
                    }
                }
            } catch (Exception e) {
                // Silently fail, return original value
            }
        }
    }
}

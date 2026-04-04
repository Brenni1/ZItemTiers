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
    @Patch(className = "zombie.inventory.InventoryItem", methodName = "getDiscomfortModifier")
    public static class Patch_getDiscomfortModifier {
        @Patch.OnExit
        public static void onExit(@Patch.This InventoryItem self, @Patch.Return(readOnly = false) float returnValue) {
            returnValue = CustomAttributeStorage.getOrDefault(self.getID(), "DiscomfortModifier", returnValue);
        }
    }

    @Patch(className = "zombie.inventory.InventoryItem", methodName = "getHearingModifier")
    public static class Patch_getHearingModifier {
        @Patch.OnExit
        public static void onExit(@Patch.This InventoryItem self, @Patch.Return(readOnly = false) float returnValue) {
            returnValue = CustomAttributeStorage.getOrDefault(self.getID(), "HearingModifier", returnValue);
        }
    }

    @Patch(className = "zombie.inventory.InventoryItem", methodName = "getVisionModifier")
    public static class Patch_getVisionModifier {
        @Patch.OnExit
        public static void onExit(@Patch.This InventoryItem self, @Patch.Return(readOnly = false) float returnValue) {
            returnValue = CustomAttributeStorage.getOrDefault(self.getID(), "VisionModifier", returnValue);
        }
    }

}

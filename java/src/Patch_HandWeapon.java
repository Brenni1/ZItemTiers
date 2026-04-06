package me.zed_0xff.itemtiers;

import me.zed_0xff.zombie_buddy.Accessor;
import me.zed_0xff.zombie_buddy.Patch;

import zombie.inventory.InventoryItem;
import zombie.inventory.types.HandWeapon;

/**
 * Optional Java patches for HandWeapon items.
 * This patch applies tier-based weight reduction to HandWeapon.getActualWeight().
 * 
 * Note: Damage can be modified directly from Lua using setMinDamage()/setMaxDamage(),
 * so only weight needs to be patched here (since getActualWeight() reads from script item).
 * 
 * If this patch is not loaded, HandWeapon weight reduction will be disabled
 * (damage bonuses will still work via Lua).
 */
public class Patch_HandWeapon {

    // InventoryItem:
    //     public float getActualWeight() {
    //         if (getDisplayName().equals(getFullType())) {
    //             return 0.0f;
    //         }
    //         return Math.max(this.actualWeight, 0.0f);
    //     }
    //
    // HandWeapon:
    //     public float getActualWeight() {
    //         float weight = getScriptItem().getActualWeight();
    //         for (WeaponPart part : this.attachments.values()) {
    //             weight += getWeaponPartWeightModifier(part);
    //         }
    //         return weight;
    //     }

    @Patch(className = "zombie.inventory.types.HandWeapon", methodName = "getActualWeight")
    public static class Patch_getActualWeight {
        @Patch.OnExit
        public static void onExit(@Patch.This HandWeapon self, @Patch.Return(readOnly = false) float result) {
            float scriptWeight = self.getScriptItem().getActualWeight();
            float itemWeight   = Accessor.tryGet(self, "actualWeight", 0.0f);
            if (itemWeight > 0.0f && itemWeight < scriptWeight) {
                result = result - (scriptWeight - itemWeight);
            }
        }
    }
}

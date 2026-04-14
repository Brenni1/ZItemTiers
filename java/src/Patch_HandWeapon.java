package me.zed_0xff.itemtiers;

import me.zed_0xff.zombie_buddy.Accessor;
import me.zed_0xff.zombie_buddy.Patch;

import zombie.inventory.types.HandWeapon;

public class Patch_HandWeapon {
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

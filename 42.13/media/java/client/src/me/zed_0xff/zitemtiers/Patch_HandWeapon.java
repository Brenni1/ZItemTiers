package me.zed_0xff.itemtiers;

import me.zed_0xff.zombie_buddy.Patch;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.inventory.types.HandWeapon;
import zombie.inventory.types.WeaponPart;
import java.util.HashMap;

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
    
    // Helper function to get tier bonus multiplier from Lua
    public static float getWeightReductionMultiplier(HandWeapon weapon) {
        try {
            Object zItemTiers = LuaManager.env.rawget("ZItemTiers");
            if (zItemTiers instanceof KahluaTable) {
                Object getItemTier = ((KahluaTable) zItemTiers).rawget("GetItemTier");
                if (getItemTier != null) {
                    Object tierName = LuaManager.caller.protectedCall(LuaManager.thread, getItemTier, weapon);
                    if (tierName == null) {
                        return 1.0f;  // No tier, no reduction
                    }
                    
                    Object tierBonuses = ((KahluaTable) zItemTiers).rawget("TierBonuses");
                    if (tierBonuses instanceof KahluaTable) {
                        Object bonuses = ((KahluaTable) tierBonuses).rawget(tierName.toString());
                        if (bonuses instanceof KahluaTable) {
                            KahluaTable bonusesTable = (KahluaTable) bonuses;
                            Object weightReduction = bonusesTable.rawget("weightReduction");
                            if (weightReduction != null) {
                                float reduction = ((Number) weightReduction).floatValue();
                                return 1.0f - (reduction / 100.0f);  // Convert percentage to multiplier
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            // Silently fail, return no reduction
        }
        return 1.0f;
    }
    
    /**
     * Patch HandWeapon.getActualWeight() to apply tier-based weight reduction.
     * Uses OnExit to modify the return value without duplicating the original method logic.
     * 
     * Note: Damage can be modified directly from Lua using setMinDamage()/setMaxDamage(),
     * so we only need to patch weight here.
     */
    @Patch(className = "zombie.inventory.types.HandWeapon", methodName = "getActualWeight")
    public static class Patch_getActualWeight {
        @Patch.OnExit
        public static void onExit(@Patch.This HandWeapon self, @Patch.Return(readOnly = false) float returnValue) {
            // Apply tier-based weight reduction
            float multiplier = getWeightReductionMultiplier(self);
            if (multiplier < 1.0f) {
                returnValue = returnValue * multiplier;
                // Ensure weight doesn't go below 0.01
                if (returnValue < 0.01f) {
                    returnValue = 0.01f;
                }
            }
        }
    }
}

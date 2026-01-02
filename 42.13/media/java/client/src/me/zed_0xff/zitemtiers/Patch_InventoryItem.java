package me.zed_0xff.itemtiers;

import me.zed_0xff.zombie_buddy.Patch;

import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.inventory.InventoryItem;
import zombie.ui.ObjectTooltip;
import zombie.core.Translator;

/**
 * Patch to add rarity information to item tooltips.
 * Hooks into InventoryItem.DoTooltipEmbedded to call Lua function that adds rarity display.
 */
public class Patch_InventoryItem {
    public static InventoryItem currentItem = null;
    public static String strItemReport = null;
    public static ObjectTooltip.LayoutItem curLayoutItem = null;

    // Helper function to get rarity data from Lua
    // Returns Common rarity data if item has no rarity
    public static Object[] getRarityData(InventoryItem item) {
        try {
            Object zItemTiers = LuaManager.env.rawget("ZItemTiers");
            if (zItemTiers instanceof KahluaTable) {
                Object getItemRarity = ((KahluaTable) zItemTiers).rawget("GetItemRarity");
                if (getItemRarity != null) {
                    Object rarityName = LuaManager.caller.protectedCall(LuaManager.thread, getItemRarity, item);
                    if (rarityName == null) {
                        rarityName = "Common";  // Default to Common if no rarity
                    }
                    
                    Object rarities = ((KahluaTable) zItemTiers).rawget("Rarities");
                    if (rarities instanceof KahluaTable) {
                        Object rarityData = ((KahluaTable) rarities).rawget(rarityName.toString());
                        if (rarityData instanceof KahluaTable) {
                            KahluaTable rarityTable = (KahluaTable) rarityData;
                            Object name = rarityTable.rawget("name");
                            Object color = rarityTable.rawget("color");
                            if (color instanceof KahluaTable) {
                                KahluaTable colorTable = (KahluaTable) color;
                                Object colorR = colorTable.rawget("r");
                                Object colorG = colorTable.rawget("g");
                                Object colorB = colorTable.rawget("b");
                                if (colorR != null && colorG != null && colorB != null && name != null) {
                                    return new Object[]{
                                        name.toString(),
                                        ((Number) colorR).floatValue(),
                                        ((Number) colorG).floatValue(),
                                        ((Number) colorB).floatValue()
                                    };
                                }
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            // Silently fail
        }
        
        // Fallback to Common if everything fails
        return new Object[]{
            "Common",
            1.0f,  // White color
            1.0f,
            1.0f
        };
    }

    @Patch(className = "zombie.ui.ObjectTooltip$LayoutItem", methodName = "setLabel")
    public static class Patch_LayoutItem_setLabel {
        @Patch.OnEnter
        @Patch.RuntimeType
        public static void enter(
            @Patch.Argument(value = 0, readOnly = false) String label,
            @Patch.Argument(value = 1, readOnly = false) float r,
            @Patch.Argument(value = 2, readOnly = false) float g,
            @Patch.Argument(value = 3, readOnly = false) float b,
            @Patch.Argument(value = 4, readOnly = false) float a,
            @Patch.This Object self
        ) {
            if (currentItem == null) {
                return;
            }
            
            if (strItemReport == null) {
                strItemReport = Translator.getText("Item Report") + ":";
            }
            
            // Check if this is the "Item Report" label and replace it with "Rarity"
            if (label.equals(strItemReport)) {
                label = Translator.getText("Rarity") + ":";
                curLayoutItem = (ObjectTooltip.LayoutItem) self;
                
                // Set label color to item's rarity color
                Object[] rarityData = getRarityData(currentItem);
                if (rarityData != null) {
                    r = (Float) rarityData[1];
                    g = (Float) rarityData[2];
                    b = (Float) rarityData[3];
                }
            }
        }
    }

    @Patch(className = "zombie.ui.ObjectTooltip$LayoutItem", methodName = "setValue")
    public static class Patch_LayoutItem_setValue {
        @Patch.OnEnter
        @Patch.RuntimeType
        public static void enter(
            @Patch.Argument(value = 0, readOnly = false) String value,
            @Patch.Argument(value = 1, readOnly = false) float r,
            @Patch.Argument(value = 2, readOnly = false) float g,
            @Patch.Argument(value = 3, readOnly = false) float b,
            @Patch.Argument(value = 4, readOnly = false) float a,
            @Patch.This Object self
        ) {
            if (curLayoutItem == null || currentItem == null || self != curLayoutItem) {
                return;
            }

            // Set value text to rarity name and color to rarity color
            Object[] rarityData = getRarityData(currentItem);
            if (rarityData != null) {
                value = (String) rarityData[0];
                r = (Float) rarityData[1];
                g = (Float) rarityData[2];
                b = (Float) rarityData[3];
            }
        }
    }
    
    // Patch ObjectTooltip.render() to track current item from this.item field
    // This works for both regular items and Clothing items
    @Patch(className = "zombie.ui.ObjectTooltip", methodName = "render")
    public static class Patch_ObjectTooltip_render {
        @Patch.OnEnter
        public static void enter(@Patch.This Object self) {
            try {
                ObjectTooltip tooltip = (ObjectTooltip) self;
                if (tooltip.isItem && tooltip.item != null) {
                    currentItem = tooltip.item;
                }
            } catch (Exception e) {
                // Silently fail
            }
        }
        
        @Patch.OnExit
        public static void exit() {
            currentItem = null;
        }
    }
    
    // Patch ObjectTooltip.hide() to clear current item
    @Patch(className = "zombie.ui.ObjectTooltip", methodName = "hide")
    public static class Patch_ObjectTooltip_hide {
        @Patch.OnEnter
        public static void enter(@Patch.This Object self) {
            currentItem = null;
        }
    }
    
    @Patch(className = "zombie.inventory.InventoryItem", methodName = "DoTooltipEmbedded")
    public static class Patch_DoTooltipEmbedded {
        
        @Patch.OnEnter
        @Patch.RuntimeType
        public static void enter( @Patch.This Object self ) {
            currentItem = (InventoryItem) self;
        }
    }
}

// package me.zed_0xff.itemtiers;

// import me.zed_0xff.zombie_buddy.Patch;

// import zombie.core.Translator;

// @Patch(className = "zombie.ui.ObjectTooltip$LayoutItem", methodName = "setLabel")
// public class Patch_LayoutItem {
//     public static String strItemReport = null;

//     @Patch.OnEnter
//     public static void enter(
//         @Patch.Argument(value = 0, readOnly = false) String label,
//         @Patch.Argument(value = 1, readOnly = false) float r,
//         @Patch.Argument(value = 2, readOnly = false) float g,
//         @Patch.Argument(value = 3, readOnly = false) float b,
//         @Patch.Argument(value = 4, readOnly = false) float a
//     ) {
//         if (strItemReport == null) {
//             strItemReport = Translator.getText("Item Report") + ":";
//         } else if (label.equals(strItemReport)) {
//             label = Translator.getText("Tier") + ":";
//         }
//     }
// }

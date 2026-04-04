package me.zed_0xff.itemtiers;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * CustomAttributeStorage is a utility class that provides a thread-safe way to store custom attributes for InventoryItem instances.
 * It uses a ConcurrentHashMap to associate InventoryItem objects with their custom attributes, which are stored as key-value pairs.
 * This allows us to add new attributes to items without modifying the original class definitions or using Lua modData, and it works even for items that don't have modData.
 * Note: This storage is not persistent and will be lost when the game is closed. It is intended for temporary runtime use.
 */
public class CustomAttributeStorage {
    // Map to store custom attributes for each InventoryItem instance
    private static final Map<Integer, Map<String, Float>> itemAttributes = new ConcurrentHashMap<>();

    public static void clear() {
        itemAttributes.clear();
    }

    public static float getOrDefault(int itemId, String attributeName, float defaultValue) {
        Map<String, Float> attributes = itemAttributes.get(itemId);
        if (attributes != null) {
            return attributes.getOrDefault(attributeName, defaultValue);
        }
        return defaultValue;
    }

    public static void set(int itemId, String attributeName, float value) {
        itemAttributes.computeIfAbsent(itemId, k -> new ConcurrentHashMap<>()).put(attributeName, value);
    }
}

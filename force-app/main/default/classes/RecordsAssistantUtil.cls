/**
 * Shared helpers for the Records Assistant agent actions.
 * Dynamic, object-agnostic DML so a single set of actions works across native objects
 * (Account, Contact, Lead, Opportunity, Case, Task, Event, ...).
 */
public with sharing class RecordsAssistantUtil {

    public class RecordsAssistantException extends Exception {}

    /** Resolve an object API name to its describe, case-insensitively. */
    public static Schema.DescribeSObjectResult describeObject(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            throw new RecordsAssistantException('No object name was provided.');
        }
        Schema.SObjectType t = Schema.getGlobalDescribe().get(objectApiName);
        if (t == null) {
            // Try a case-insensitive match.
            for (String key : Schema.getGlobalDescribe().keySet()) {
                if (key.equalsIgnoreCase(objectApiName)) {
                    t = Schema.getGlobalDescribe().get(key);
                    break;
                }
            }
        }
        if (t == null) {
            throw new RecordsAssistantException('Unknown object: "' + objectApiName + '".');
        }
        return t.getDescribe();
    }

    /** Apply a JSON field map (fieldApiName -> value) onto an SObject with type coercion. */
    public static void applyFields(SObject record, Schema.DescribeSObjectResult dsr, String fieldsJson) {
        if (String.isBlank(fieldsJson)) {
            return;
        }
        Map<String, Object> raw;
        try {
            raw = (Map<String, Object>) JSON.deserializeUntyped(fieldsJson);
        } catch (Exception e) {
            throw new RecordsAssistantException('Could not parse the fields. Provide a JSON object of fieldApiName:value pairs. ' + e.getMessage());
        }
        Map<String, Schema.SObjectField> fieldMap = dsr.fields.getMap();
        for (String rawKey : raw.keySet()) {
            Schema.SObjectField sf = resolveField(fieldMap, rawKey);
            if (sf == null) {
                continue; // skip unknown fields rather than fail the whole write
            }
            Schema.DescribeFieldResult dfr = sf.getDescribe();
            if (!dfr.isCreateable() && !dfr.isUpdateable()) {
                continue;
            }
            Object val = raw.get(rawKey);
            record.put(dfr.getName(), coerce(val, dfr.getType()));
        }
    }

    private static Schema.SObjectField resolveField(Map<String, Schema.SObjectField> fieldMap, String key) {
        if (fieldMap.containsKey(key)) {
            return fieldMap.get(key);
        }
        String lower = key.toLowerCase();
        if (fieldMap.containsKey(lower)) {
            return fieldMap.get(lower);
        }
        for (String k : fieldMap.keySet()) {
            if (k.equalsIgnoreCase(key)) {
                return fieldMap.get(k);
            }
        }
        return null;
    }

    private static Object coerce(Object val, Schema.DisplayType type) {
        if (val == null) {
            return null;
        }
        String s = String.valueOf(val);
        if (String.isBlank(s)) {
            return null;
        }
        switch on type {
            when DATE {
                return Date.valueOf(s.length() > 10 ? s.substring(0, 10) : s);
            }
            when DATETIME {
                // Accept "yyyy-MM-dd" or "yyyy-MM-dd HH:mm:ss".
                if (s.length() <= 10) {
                    return Datetime.newInstance(Date.valueOf(s), Time.newInstance(0, 0, 0, 0));
                }
                return Datetime.valueOf(s.replace('T', ' ').replace('Z', '').trim());
            }
            when CURRENCY, DOUBLE, PERCENT {
                return Double.valueOf(s);
            }
            when INTEGER, LONG {
                return Integer.valueOf(Decimal.valueOf(s).round());
            }
            when BOOLEAN {
                return Boolean.valueOf(s);
            }
            when else {
                return s;
            }
        }
    }

    /** The label-style Name value for a record, or its Id as a fallback. */
    public static String nameOf(SObject record, Schema.DescribeSObjectResult dsr) {
        if (dsr.fields.getMap().containsKey('Name')) {
            Object n = record.get('Name');
            if (n != null) {
                return String.valueOf(n);
            }
        }
        return String.valueOf(record.get('Id'));
    }
}

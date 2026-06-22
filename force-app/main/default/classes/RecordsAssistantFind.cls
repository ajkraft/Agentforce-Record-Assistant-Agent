/**
 * Records Assistant action: resolve a record by name to its Id (for wiring up lookups
 * such as AccountId, ContactId, WhoId, WhatId before creating a child record).
 * Uses SOQL LIKE on the Name field for immediate results (no search-index lag).
 */
public with sharing class RecordsAssistantFind {

    public class Request {
        @InvocableVariable(required=true label='Object API Name'
            description='API name of the object to search (any standard or custom object with a Name field).')
        public String objectApiName;

        @InvocableVariable(required=true label='Search Text'
            description='Name (or partial name) of the record to find.')
        public String searchText;
    }

    public class Result {
        @InvocableVariable(label='Found') public Boolean found;
        @InvocableVariable(label='Record Id') public String recordId;
        @InvocableVariable(label='Record Name') public String recordName;
        @InvocableVariable(label='Match Count') public Integer matchCount;
        @InvocableVariable(label='Message') public String message;
    }

    @InvocableMethod(label='Find Record'
        description='Finds a record by name and returns its Id. Use before creating a child record to resolve lookups like the Account or Contact.')
    public static List<Result> findRecords(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            res.found = false;
            res.matchCount = 0;
            try {
                Schema.DescribeSObjectResult dsr = RecordsAssistantUtil.describeObject(req.objectApiName);
                if (!dsr.fields.getMap().containsKey('Name')) {
                    res.message = dsr.getLabel() + ' has no Name field to search; provide the record Id directly.';
                    results.add(res);
                    continue;
                }
                if (String.isBlank(req.searchText)) {
                    res.message = 'No search text was provided.';
                    results.add(res);
                    continue;
                }
                String searchLike = '%' + String.escapeSingleQuotes(req.searchText.trim()) + '%';
                String soql = 'SELECT Id, Name FROM ' + dsr.getName()
                    + ' WHERE Name LIKE :searchLike ORDER BY Name LIMIT 5';
                List<SObject> rows = Database.queryWithBinds(
                    soql, new Map<String, Object>{ 'searchLike' => searchLike }, AccessLevel.USER_MODE);

                res.matchCount = rows.size();
                if (rows.isEmpty()) {
                    res.message = 'No ' + dsr.getLabel() + ' found matching "' + req.searchText + '".';
                } else {
                    SObject top = rows[0];
                    res.found = true;
                    res.recordId = String.valueOf(top.get('Id'));
                    res.recordName = String.valueOf(top.get('Name'));
                    if (rows.size() == 1) {
                        res.message = 'Found ' + dsr.getLabel() + ' "' + res.recordName + '".';
                    } else {
                        List<String> names = new List<String>();
                        for (SObject r : rows) {
                            names.add(String.valueOf(r.get('Name')));
                        }
                        res.message = 'Found ' + rows.size() + ' matches: ' + String.join(names, '; ')
                            + '. Returning the first; confirm with the user if ambiguous.';
                    }
                }
            } catch (Exception e) {
                res.message = 'Could not search: ' + e.getMessage();
            }
            results.add(res);
        }
        return results;
    }
}

/**
 * Records Assistant action: create a record of any native object from a JSON field map.
 * Runs in user mode so it honors the running user's CRUD/FLS.
 */
public with sharing class RecordsAssistantCreate {

    public class Request {
        @InvocableVariable(required=true label='Object API Name'
            description='API name of the object to create (any standard or custom object the running user is allowed to create).')
        public String objectApiName;

        @InvocableVariable(required=true label='Fields JSON'
            description='JSON object of fieldApiName:value pairs to set. Resolve lookup fields to record Ids with Find Record before calling this. Format dates as yyyy-MM-dd.')
        public String fieldsJson;
    }

    public class Result {
        @InvocableVariable(label='Success') public Boolean success;
        @InvocableVariable(label='Record Id') public String recordId;
        @InvocableVariable(label='Record Name') public String recordName;
        @InvocableVariable(label='Record URL') public String recordUrl;
        @InvocableVariable(label='Message') public String message;
    }

    @InvocableMethod(label='Create Record'
        description='Creates a new record of the specified object using a JSON map of fields. Returns the new record Id and a link.')
    public static List<Result> createRecords(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                Schema.DescribeSObjectResult dsr = RecordsAssistantUtil.describeObject(req.objectApiName);
                if (!dsr.isCreateable()) {
                    throw new RecordsAssistantUtil.RecordsAssistantException(
                        'You do not have permission to create ' + dsr.getLabel() + ' records.');
                }
                SObject record = dsr.getSObjectType().newSObject();
                RecordsAssistantUtil.applyFields(record, dsr, req.fieldsJson);
                Database.insert(record, true, AccessLevel.USER_MODE);

                res.success = true;
                res.recordId = String.valueOf(record.get('Id'));
                res.recordName = RecordsAssistantUtil.nameOf(record, dsr);
                res.recordUrl = '/' + res.recordId;
                res.message = 'Created ' + dsr.getLabel() + ' "' + res.recordName + '".';
            } catch (Exception e) {
                res.success = false;
                res.message = 'Could not create the record: ' + e.getMessage();
            }
            results.add(res);
        }
        return results;
    }
}

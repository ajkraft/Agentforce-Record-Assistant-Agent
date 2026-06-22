/**
 * Records Assistant action: update an existing record of any native object from a JSON field map.
 * Runs in user mode so it honors the running user's CRUD/FLS.
 */
public with sharing class RecordsAssistantUpdate {

    public class Request {
        @InvocableVariable(required=true label='Object API Name'
            description='API name of the object to update (any standard or custom object the running user is allowed to update).')
        public String objectApiName;

        @InvocableVariable(required=true label='Record Id'
            description='Id of the record to update. Use Find Record first if you only have a name.')
        public String recordId;

        @InvocableVariable(required=true label='Fields JSON'
            description='JSON object of fieldApiName:value pairs to change. Format dates as yyyy-MM-dd.')
        public String fieldsJson;
    }

    public class Result {
        @InvocableVariable(label='Success') public Boolean success;
        @InvocableVariable(label='Record Id') public String recordId;
        @InvocableVariable(label='Record URL') public String recordUrl;
        @InvocableVariable(label='Message') public String message;
    }

    @InvocableMethod(label='Update Record'
        description='Updates an existing record of the specified object using a JSON map of fields. Returns a link to the record.')
    public static List<Result> updateRecords(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                Schema.DescribeSObjectResult dsr = RecordsAssistantUtil.describeObject(req.objectApiName);
                if (!dsr.isUpdateable()) {
                    throw new RecordsAssistantUtil.RecordsAssistantException(
                        'You do not have permission to update ' + dsr.getLabel() + ' records.');
                }
                if (String.isBlank(req.recordId)) {
                    throw new RecordsAssistantUtil.RecordsAssistantException('No record Id was provided to update.');
                }
                SObject record = dsr.getSObjectType().newSObject((Id) req.recordId);
                RecordsAssistantUtil.applyFields(record, dsr, req.fieldsJson);
                Database.update(record, true, AccessLevel.USER_MODE);

                res.success = true;
                res.recordId = req.recordId;
                res.recordUrl = '/' + req.recordId;
                res.message = 'Updated ' + dsr.getLabel() + ' record.';
            } catch (Exception e) {
                res.success = false;
                res.message = 'Could not update the record: ' + e.getMessage();
            }
            results.add(res);
        }
        return results;
    }
}

/**
 * Tests for the Records Assistant actions (Find / Create / Update) and shared util.
 * Uses only transient, in-memory test records on standard objects; nothing persists
 * to the org. Exercises the success paths plus the main error and type-coercion branches.
 */
@isTest
private class RecordsAssistantTest {

    @isTest
    static void createsFindsAndUpdatesARecord() {
        // Create an Account, exercising String, Integer, and Double coercion.
        RecordsAssistantCreate.Request createReq = new RecordsAssistantCreate.Request();
        createReq.objectApiName = 'Account';
        createReq.fieldsJson =
            '{"Name":"Records Assistant Test Account",' +
            '"Description":"created by test",' +
            '"NumberOfEmployees":"100",' +
            '"AnnualRevenue":"50000.50"}';

        Test.startTest();
        RecordsAssistantCreate.Result createRes =
            RecordsAssistantCreate.createRecords(
                new List<RecordsAssistantCreate.Request>{ createReq })[0];
        Test.stopTest();

        System.assertEquals(true, createRes.success, createRes.message);
        System.assertNotEquals(null, createRes.recordId, 'Expected a new record Id.');
        System.assertEquals('Records Assistant Test Account', createRes.recordName);

        // Find it by name.
        RecordsAssistantFind.Request findReq = new RecordsAssistantFind.Request();
        findReq.objectApiName = 'Account';
        findReq.searchText = 'Records Assistant Test';
        RecordsAssistantFind.Result findRes =
            RecordsAssistantFind.findRecords(
                new List<RecordsAssistantFind.Request>{ findReq })[0];
        System.assertEquals(true, findRes.found, findRes.message);
        System.assertEquals(createRes.recordId, findRes.recordId);

        // Update it.
        RecordsAssistantUpdate.Request updateReq = new RecordsAssistantUpdate.Request();
        updateReq.objectApiName = 'Account';
        updateReq.recordId = createRes.recordId;
        updateReq.fieldsJson = '{"Description":"updated by test"}';
        RecordsAssistantUpdate.Result updateRes =
            RecordsAssistantUpdate.updateRecords(
                new List<RecordsAssistantUpdate.Request>{ updateReq })[0];
        System.assertEquals(true, updateRes.success, updateRes.message);

        Account saved = [SELECT Description FROM Account WHERE Id = :createRes.recordId];
        System.assertEquals('updated by test', saved.Description);
    }

    @isTest
    static void coercesDateDatetimeAndBoolean() {
        RecordsAssistantCreate.Request req = new RecordsAssistantCreate.Request();
        req.objectApiName = 'Task';
        req.fieldsJson =
            '{"Subject":"Follow up",' +
            '"ActivityDate":"2999-01-01",' +
            '"Status":"Not Started",' +
            '"Priority":"Normal",' +
            '"IsReminderSet":"true",' +
            '"ReminderDateTime":"2999-01-01 09:00:00"}';

        RecordsAssistantCreate.Result res =
            RecordsAssistantCreate.createRecords(
                new List<RecordsAssistantCreate.Request>{ req })[0];

        System.assertEquals(true, res.success, res.message);
        Task t = [
            SELECT ActivityDate, IsReminderSet, ReminderDateTime
            FROM Task
            WHERE Id = :res.recordId
        ];
        System.assertEquals(Date.newInstance(2999, 1, 1), t.ActivityDate);
        System.assertEquals(true, t.IsReminderSet);
        System.assertNotEquals(null, t.ReminderDateTime);
    }

    @isTest
    static void reportsUnknownObject() {
        RecordsAssistantCreate.Request req = new RecordsAssistantCreate.Request();
        req.objectApiName = 'NotARealObject__x';
        req.fieldsJson = '{"Name":"x"}';
        RecordsAssistantCreate.Result res =
            RecordsAssistantCreate.createRecords(
                new List<RecordsAssistantCreate.Request>{ req })[0];
        System.assertEquals(false, res.success);
        System.assert(res.message != null && res.message.length() > 0);
    }

    @isTest
    static void reportsInvalidFieldsJson() {
        RecordsAssistantCreate.Request req = new RecordsAssistantCreate.Request();
        req.objectApiName = 'Account';
        req.fieldsJson = 'not-json';
        RecordsAssistantCreate.Result res =
            RecordsAssistantCreate.createRecords(
                new List<RecordsAssistantCreate.Request>{ req })[0];
        System.assertEquals(false, res.success);
    }

    @isTest
    static void updateRequiresRecordId() {
        RecordsAssistantUpdate.Request req = new RecordsAssistantUpdate.Request();
        req.objectApiName = 'Account';
        req.recordId = null;
        req.fieldsJson = '{"Description":"x"}';
        RecordsAssistantUpdate.Result res =
            RecordsAssistantUpdate.updateRecords(
                new List<RecordsAssistantUpdate.Request>{ req })[0];
        System.assertEquals(false, res.success);
    }

    @isTest
    static void findHandlesBlankAndNoMatch() {
        RecordsAssistantFind.Request blank = new RecordsAssistantFind.Request();
        blank.objectApiName = 'Account';
        blank.searchText = '';
        RecordsAssistantFind.Result blankRes =
            RecordsAssistantFind.findRecords(
                new List<RecordsAssistantFind.Request>{ blank })[0];
        System.assertEquals(false, blankRes.found);

        RecordsAssistantFind.Request noMatch = new RecordsAssistantFind.Request();
        noMatch.objectApiName = 'Account';
        noMatch.searchText = 'zzz-no-such-record-zzz';
        RecordsAssistantFind.Result noMatchRes =
            RecordsAssistantFind.findRecords(
                new List<RecordsAssistantFind.Request>{ noMatch })[0];
        System.assertEquals(false, noMatchRes.found);
        System.assertEquals(0, noMatchRes.matchCount);
    }
}

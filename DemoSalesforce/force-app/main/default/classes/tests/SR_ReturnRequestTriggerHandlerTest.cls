@IsTest(SeeAllData=false)
private class SR_ReturnRequestTriggerHandlerTest {

    private static final String STATUS_NEW = 'NEW';
    private static final String STATUS_PENDING_APPROVAL = 'PENDING_APPROVAL';

    private static final String CHANNEL_COUNTER = 'COUNTER';
    private static final String STORE_REGION_NORTH = 'NORTH';
    private static final String PAYMENT_METHOD_CASH = 'CASH';

    private static final Integer BULK_RECORD_COUNT = 200;

    /**
     * Test data dùng chung trong một test method.
     */
    private class TestData {
        Account customer;
        Store__c store;
        Order orderRecord;
    }

    /**
     * Tạo Account, Store và Order tối thiểu để tạo Return Request.
     */
    private static TestData createBaseData() {
        TestData data = new TestData();

        data.customer = new Account(
            Name = 'SmartReturn Test Customer'
        );
        insert data.customer;

        data.store = new Store__c(
            Store_Code__c = 'STORE-TEST',
            Region__c = STORE_REGION_NORTH
        );

        /*
         * Hỗ trợ cả hai trường hợp:
         * - Name là Text và có thể nhập.
         * - Name là Auto Number và không thể nhập.
         */
        Map<String, Schema.SObjectField> storeFields =
            Store__c.SObjectType.getDescribe().fields.getMap();

        if (
            storeFields.containsKey('Name') &&
            storeFields.get('Name').getDescribe().isCreateable()
        ) {
            data.store.put('Name', 'SmartReturn Test Store');
        }

        insert data.store;

        data.orderRecord = new Order(
            AccountId = data.customer.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Store__c = data.store.Id,
            Delivery_Date__c = Date.today(),
            Payment_Method__c = PAYMENT_METHOD_CASH
        );
        insert data.orderRecord;

        return data;
    }

    /**
     * Build Return Request nhưng chưa insert.
     */
    private static Return_Request__c buildReturnRequest(
        TestData data
    ) {
        return new Return_Request__c(
            Account__c = data.customer.Id,
            Order__c = data.orderRecord.Id,
            Store__c = data.store.Id,
            Channel__c = CHANNEL_COUNTER,
            Status__c = STATUS_NEW
        );
    }

    /**
     * Tạo và insert một Return Request.
     */
    private static Return_Request__c createReturnRequest() {
        TestData data = createBaseData();
        Return_Request__c requestRecord = buildReturnRequest(data);

        insert requestRecord;

        return requestRecord;
    }

    /**
     * Lấy một lỗi DML duy nhất và kiểm tra operation thất bại.
     */
    private static Database.Error assertSingleDmlError(
        Database.SaveResult saveResult
    ) {
        Assert.isFalse(
            saveResult.isSuccess(),
            'DML phải thất bại.'
        );

        Assert.areEqual(
            1,
            saveResult.getErrors().size(),
            'Phải có đúng một lỗi DML.'
        );

        return saveResult.getErrors()[0];
    }

    @IsTest
    static void afterInsert_createsInitialHistory() {
        TestData data = createBaseData();
        Return_Request__c requestRecord = buildReturnRequest(data);

        Test.startTest();
        insert requestRecord;
        Test.stopTest();

        List<Return_Request_History__c> histories = [
            SELECT
                Id,
                Return_Request__c,
                From_Status__c,
                To_Status__c,
                Changed_By__c,
                Changed_At__c,
                Note__c
            FROM Return_Request_History__c
            WHERE Return_Request__c =:requestRecord.Id
        ];

        Assert.areEqual(
            1,
            histories.size(),
            'Mỗi Return Request mới phải có đúng một history ban đầu.'
        );

        Return_Request_History__c initialHistory = histories[0];

        Assert.areEqual(
            requestRecord.Id,
            initialHistory.Return_Request__c,
            'History phải liên kết với đúng Return Request.'
        );

        Assert.isNull(
            initialHistory.From_Status__c,
            'From Status của history đầu tiên phải là null.'
        );

        Assert.areEqual(
            STATUS_NEW,
            initialHistory.To_Status__c,
            'To Status phải bằng trạng thái ban đầu của request.'
        );

        Assert.areEqual(
            UserInfo.getUserId(),
            initialHistory.Changed_By__c,
            'Changed By phải là user đang thực thi.'
        );

        Assert.isNotNull(
            initialHistory.Changed_At__c,
            'Changed At phải được ghi nhận.'
        );

        Assert.areEqual(
            'Initial status',
            initialHistory.Note__c,
            'History ban đầu phải có đúng system note.'
        );

        Assert.areEqual(
            0,
            SR_Logger.getInstance().getPendingCount(),
            'Logger phải push hết log sau khi handler hoàn tất.'
        );
    }

    @IsTest
    static void beforeUpdate_blocksUnauthorizedStatusChange() {
        Return_Request__c requestRecord = createReturnRequest();

        requestRecord.Status__c = STATUS_PENDING_APPROVAL;

        SR_ReturnRequestTriggerHandler.resetAuthorization();

        Test.startTest();
        Database.SaveResult result = Database.update(
            requestRecord,
            false
        );
        Test.stopTest();

        Database.Error updateError = assertSingleDmlError(result);

        String expectedMessage = String.format(
            System.Label.SR_MSG_20,
            new List<String>{
                STATUS_NEW,
                STATUS_PENDING_APPROVAL
            }
        );

        Assert.isTrue(
            updateError.getMessage().contains(expectedMessage),
            'Thông báo lỗi phải sử dụng label SR_MSG_20.'
        );

        Return_Request__c persistedRequest = [
            SELECT Status__c
            FROM Return_Request__c
            WHERE Id =:requestRecord.Id
        ];

        Assert.areEqual(
            STATUS_NEW,
            persistedRequest.Status__c,
            'Trạng thái không được thay đổi khi chưa authorize.'
        );

        Assert.areEqual(
            0,
            SR_Logger.getInstance().getPendingCount(),
            'WARN log phải được push sau khi update bị chặn.'
        );
    }

    @IsTest
    static void beforeUpdate_allowsAuthorizedStatusChange() {
        Return_Request__c requestRecord = createReturnRequest();
        Set<Id> authorizedIds = new Set<Id>{ requestRecord.Id };

        requestRecord.Status__c = STATUS_PENDING_APPROVAL;

        Test.startTest();

        try {
            SR_ReturnRequestTriggerHandler.authorizeStatusUpdates(
                authorizedIds
            );

            update requestRecord;
        } finally {
            SR_ReturnRequestTriggerHandler.revokeStatusUpdates(
                authorizedIds
            );
        }

        Test.stopTest();

        Return_Request__c persistedRequest = [
            SELECT Status__c
            FROM Return_Request__c
            WHERE Id =:requestRecord.Id
        ];

        Assert.areEqual(
            STATUS_PENDING_APPROVAL,
            persistedRequest.Status__c,
            'Status update đã authorize phải được lưu.'
        );

        Assert.areEqual(
            0,
            SR_Logger.getInstance().getPendingCount(),
            'INFO log phải được push sau khi update thành công.'
        );
    }

    @IsTest
    static void beforeUpdate_allowsUpdateWhenStatusIsUnchanged() {
        Return_Request__c requestRecord = createReturnRequest();

        requestRecord.Internal_Note__c =
            'Update field không liên quan đến status';

        SR_ReturnRequestTriggerHandler.resetAuthorization();

        Test.startTest();
        Database.SaveResult result = Database.update(
            requestRecord,
            false
        );
        Test.stopTest();

        Assert.isTrue(
            result.isSuccess(),
            'Update không đổi Status__c không cần authorize.'
        );

        Return_Request__c persistedRequest = [
            SELECT Status__c, Internal_Note__c
            FROM Return_Request__c
            WHERE Id =:requestRecord.Id
        ];

        Assert.areEqual(
            STATUS_NEW,
            persistedRequest.Status__c,
            'Status phải giữ nguyên.'
        );

        Assert.areEqual(
            'Update field không liên quan đến status',
            persistedRequest.Internal_Note__c,
            'Field không liên quan đến status phải được cập nhật.'
        );

        Assert.areEqual(
            0,
            SR_Logger.getInstance().getPendingCount(),
            'Không được còn log chờ sau khi handler hoàn tất.'
        );
    }

    @IsTest
    static void revokeStatusUpdates_blocksPreviouslyAuthorizedRecord() {
        Return_Request__c requestRecord = createReturnRequest();
        Set<Id> requestIds = new Set<Id>{ requestRecord.Id };

        SR_ReturnRequestTriggerHandler.authorizeStatusUpdates(requestIds);
        SR_ReturnRequestTriggerHandler.revokeStatusUpdates(requestIds);

        requestRecord.Status__c = STATUS_PENDING_APPROVAL;

        Test.startTest();
        Database.SaveResult result = Database.update(
            requestRecord,
            false
        );
        Test.stopTest();

        assertSingleDmlError(result);

        Return_Request__c persistedRequest = [
            SELECT Status__c
            FROM Return_Request__c
            WHERE Id =:requestRecord.Id
        ];

        Assert.areEqual(
            STATUS_NEW,
            persistedRequest.Status__c,
            'Record đã revoke không được phép thay đổi status.'
        );

        Assert.areEqual(
            0,
            SR_Logger.getInstance().getPendingCount(),
            'Logger phải được push sau khi update bị chặn.'
        );
    }

    @IsTest
    static void resetAuthorization_clearsAllAuthorizedRecords() {
        Return_Request__c requestRecord = createReturnRequest();

        SR_ReturnRequestTriggerHandler.authorizeStatusUpdates(
            new Set<Id>{ requestRecord.Id }
        );

        SR_ReturnRequestTriggerHandler.resetAuthorization();

        requestRecord.Status__c = STATUS_PENDING_APPROVAL;

        Test.startTest();
        Database.SaveResult result = Database.update(
            requestRecord,
            false
        );
        Test.stopTest();

        assertSingleDmlError(result);

        Return_Request__c persistedRequest = [
            SELECT Status__c
            FROM Return_Request__c
            WHERE Id =:requestRecord.Id
        ];

        Assert.areEqual(
            STATUS_NEW,
            persistedRequest.Status__c,
            'resetAuthorization phải xóa toàn bộ authorization.'
        );
    }

    @IsTest
    static void authorizationMethods_handleNullAndEmptySets() {
        Test.startTest();

        SR_ReturnRequestTriggerHandler.authorizeStatusUpdates(null);
        SR_ReturnRequestTriggerHandler.authorizeStatusUpdates(
            new Set<Id>()
        );

        SR_ReturnRequestTriggerHandler.revokeStatusUpdates(null);
        SR_ReturnRequestTriggerHandler.revokeStatusUpdates(
            new Set<Id>()
        );

        Test.stopTest();

        Assert.areEqual(
            0,
            SR_Logger.getInstance().getPendingCount(),
            'Các operation rỗng không được tạo log chờ.'
        );
    }

    @IsTest
    static void bulkInsert_createsOneHistoryPerRequest() {
        TestData data = createBaseData();

        List<Return_Request__c> requests =
            new List<Return_Request__c>();

        for (Integer i = 0; i < BULK_RECORD_COUNT; i++) {
            requests.add(buildReturnRequest(data));
        }

        Test.startTest();
        insert requests;
        Test.stopTest();

        Set<Id> requestIds = new Map<Id, Return_Request__c>(
            requests
        ).keySet();

        Integer historyCount = [
            SELECT COUNT()
            FROM Return_Request_History__c
            WHERE Return_Request__c IN:requestIds
        ];

        Assert.areEqual(
            BULK_RECORD_COUNT,
            historyCount,
            'Mỗi Return Request phải có đúng một history ban đầu.'
        );

        Assert.areEqual(
            0,
            SR_Logger.getInstance().getPendingCount(),
            'Bulk insert không được để lại log chưa push.'
        );
    }

    @IsTest
    static void bulkUpdate_blocksAllUnauthorizedStatusChanges() {
        TestData data = createBaseData();

        List<Return_Request__c> requests =
            new List<Return_Request__c>();

        for (Integer i = 0; i < BULK_RECORD_COUNT; i++) {
            requests.add(buildReturnRequest(data));
        }

        insert requests;

        for (Return_Request__c requestRecord: requests) {
            requestRecord.Status__c = STATUS_PENDING_APPROVAL;
        }

        SR_ReturnRequestTriggerHandler.resetAuthorization();

        Test.startTest();
        List<Database.SaveResult> results = Database.update(
            requests,
            false
        );
        Test.stopTest();

        Integer failureCount = 0;

        for (Database.SaveResult result: results) {
            if (!result.isSuccess()) {
                failureCount++;
            }
        }

        Assert.areEqual(
            BULK_RECORD_COUNT,
            failureCount,
            'Toàn bộ status update chưa authorize phải bị chặn.'
        );

        Set<Id> requestIds = new Map<Id, Return_Request__c>(
            requests
        ).keySet();

        for (Return_Request__c persistedRequest: [
            SELECT Id, Status__c
            FROM Return_Request__c
            WHERE Id IN:requestIds
        ]) {
            Assert.areEqual(
                STATUS_NEW,
                persistedRequest.Status__c,
                'Status phải giữ nguyên sau bulk update bị chặn.'
            );
        }

        Assert.areEqual(
            0,
            SR_Logger.getInstance().getPendingCount(),
            'Bulk WARN log phải được push sau khi handler hoàn tất.'
        );
    }

    @IsTest
    static void bulkUpdate_allowsAllAuthorizedStatusChanges() {
        TestData data = createBaseData();

        List<Return_Request__c> requests =
            new List<Return_Request__c>();

        for (Integer i = 0; i < BULK_RECORD_COUNT; i++) {
            requests.add(buildReturnRequest(data));
        }

        insert requests;

        Set<Id> requestIds = new Map<Id, Return_Request__c>(
            requests
        ).keySet();

        for (Return_Request__c requestRecord: requests) {
            requestRecord.Status__c = STATUS_PENDING_APPROVAL;
        }

        Test.startTest();

        try {
            SR_ReturnRequestTriggerHandler.authorizeStatusUpdates(
                requestIds
            );

            update requests;
        } finally {
            SR_ReturnRequestTriggerHandler.revokeStatusUpdates(
                requestIds
            );
        }

        Test.stopTest();

        Integer updatedCount = [
            SELECT COUNT()
            FROM Return_Request__c
            WHERE Id IN:requestIds
            AND Status__c =:STATUS_PENDING_APPROVAL
        ];

        Assert.areEqual(
            BULK_RECORD_COUNT,
            updatedCount,
            'Toàn bộ status update đã authorize phải thành công.'
        );

        Assert.areEqual(
            0,
            SR_Logger.getInstance().getPendingCount(),
            'Bulk INFO log phải được push sau khi handler hoàn tất.'
        );
    }
}
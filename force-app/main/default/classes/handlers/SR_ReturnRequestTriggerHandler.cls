public with sharing class SR_ReturnRequestTriggerHandler {
    private static Set<Id> authorizedStatusUpdateIds = new Set<Id>();

    public static void beforeUpdate(
        List<Return_Request__c> newRecords,
        Map<Id, Return_Request__c> oldMap
    ) {
        for (Return_Request__c currentRecord : newRecords) {
            Return_Request__c oldRecord = oldMap.get(currentRecord.Id);
            if (
                currentRecord.Status__c != oldRecord.Status__c &&
                !authorizedStatusUpdateIds.contains(currentRecord.Id)
            ) {
                currentRecord.Status__c.addError(
                    String.format(
                        System.Label.SR_MSG_20,
                        new List<String>{ oldRecord.Status__c, currentRecord.Status__c }
                    )
                );
            }
        }
    }

    public static void afterInsert(List<Return_Request__c> newRecords) {
        List<Return_Request_History__c> histories = new List<Return_Request_History__c>();
        for (Return_Request__c requestRecord : newRecords) {
            histories.add(new Return_Request_History__c(
                Request__c = requestRecord.Id,
                From_Status__c = null,
                To_Status__c = requestRecord.Status__c,
                Changed_By__c = UserInfo.getUserId(),
                Changed_At__c = System.now(),
                Note__c = 'Initial status'
            ));
        }
        if (!histories.isEmpty()) {
            insert histories;
        }
    }

    public static void authorizeStatusUpdates(Set<Id> requestIds) {
        authorizedStatusUpdateIds.addAll(requestIds);
    }

    public static void revokeStatusUpdates(Set<Id> requestIds) {
        authorizedStatusUpdateIds.removeAll(requestIds);
    }

    @TestVisible
    static void resetAuthorization() {
        authorizedStatusUpdateIds.clear();
    }
}

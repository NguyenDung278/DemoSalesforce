public class SR_ApprovalPreviewResultDTO {
    @AuraEnabled public Boolean success;
    @AuraEnabled public String approvalLevel;
    @AuraEnabled public Id assignedApproverId;
    @AuraEnabled public String targetStatus;
    @AuraEnabled public String errorCode;
    @AuraEnabled public String message;
}

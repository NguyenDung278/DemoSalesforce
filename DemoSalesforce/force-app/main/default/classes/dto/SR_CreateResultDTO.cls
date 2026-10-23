public class SR_CreateResultDTO {
    @AuraEnabled public Boolean success;
    @AuraEnabled public Boolean isDuplicate;
    @AuraEnabled public Id requestId;
    @AuraEnabled public String requestNumber;
    @AuraEnabled public String status;
    @AuraEnabled public String approvalLevel;
    @AuraEnabled public Decimal estimatedRefund;
    @AuraEnabled public List<SR_LineRefundDTO> lines;
    @AuraEnabled public String errorCode;
    @AuraEnabled public String message;
}

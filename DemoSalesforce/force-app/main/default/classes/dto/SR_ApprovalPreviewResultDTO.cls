public class SR_ApprovalPreviewResultDTO {
    @AuraEnabled public Boolean success;
    @AuraEnabled public List<SR_LineRefundDTO> lines;
    @AuraEnabled public Decimal totalRefund;
    @AuraEnabled public String approvalLevel;
    @AuraEnabled public String errorCode;
    @AuraEnabled public String message;
}

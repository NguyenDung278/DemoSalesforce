public class SR_LineRefundDTO {
    @AuraEnabled public Boolean success;
    @AuraEnabled public Id orderItemId;
    @AuraEnabled public String sku;
    @AuraEnabled public Decimal quantity;
    @AuraEnabled public Decimal unitPrice;
    @AuraEnabled public String reason;
    @AuraEnabled public String condition;
    @AuraEnabled public Decimal refundRate;
    @AuraEnabled public Decimal refundAmount;
    @AuraEnabled public String errorCode;
    @AuraEnabled public String message;
}

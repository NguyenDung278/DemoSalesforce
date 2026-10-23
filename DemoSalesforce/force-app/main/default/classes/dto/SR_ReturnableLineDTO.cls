public class SR_ReturnableLineDTO {
    @AuraEnabled public Id orderId;
    @AuraEnabled public Id orderItemId;
    @AuraEnabled public String orderNumber;
    @AuraEnabled public String productName;
    @AuraEnabled public String sku;
    @AuraEnabled public String family;
    @AuraEnabled public Decimal unitPrice;
    @AuraEnabled public Decimal purchasedQuantity;
    @AuraEnabled public Decimal returnedQuantity;
    @AuraEnabled public Decimal returnableQuantity;
    @AuraEnabled public Date returnWindowEnd;
    @AuraEnabled public Boolean eligible;
    @AuraEnabled public String lockReason;
}

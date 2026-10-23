/**
 * Calculated line returned after create/duplicate request processing.
 * Monetary values are VND; refundRate is stored as a decimal ratio (0..1).
 */
public with sharing class SR_CreateLineResultDTO {
    @AuraEnabled public Id lineId;
    @AuraEnabled public Id orderItemId;
    @AuraEnabled public String sku;
    @AuraEnabled public Decimal quantity;
    @AuraEnabled public Decimal unitPrice;
    @AuraEnabled public Decimal refundRate;
    @AuraEnabled public Decimal refundAmount;

    public SR_CreateLineResultDTO() {
    }
}

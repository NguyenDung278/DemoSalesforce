/**
 * Eligibility projection for one OrderItem.
 * errorCode and params explain why a line is locked when eligible is false.
 */
public with sharing class SR_ReturnableLineDTO {
    @AuraEnabled public Id orderItemId;
    @AuraEnabled public String sku;
    @AuraEnabled public String productName;
    @AuraEnabled public String family;
    @AuraEnabled public Decimal unitPrice;
    @AuraEnabled public Decimal purchasedQuantity;
    @AuraEnabled public Decimal returnedQuantity;
    @AuraEnabled public Decimal returnableQuantity;
    @AuraEnabled public Date deliveryDate;
    @AuraEnabled public Date returnDeadline;
    @AuraEnabled public Boolean eligible;
    @AuraEnabled public String errorCode;
    @AuraEnabled public List<String> params;

    public SR_ReturnableLineDTO() {
        purchasedQuantity = 0;
        returnedQuantity = 0;
        returnableQuantity = 0;
        eligible = false;
        params = new List<String>();
    }
}

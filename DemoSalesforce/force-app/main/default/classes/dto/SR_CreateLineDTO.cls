/**
 * Input for one product line in a SmartReturn create request.
 * The caller may identify the line by orderItemId or sku.
 */
public with sharing class SR_CreateLineDTO {
    @AuraEnabled public Id orderItemId;
    @AuraEnabled public String sku;
    @AuraEnabled public Decimal quantity;
    @AuraEnabled public String reason;
    @AuraEnabled public String condition;

    public SR_CreateLineDTO() {
    }

    public SR_CreateLineDTO(
        Id orderItemId,
        String sku,
        Decimal quantity,
        String reason,
        String condition
    ) {
        this.orderItemId = orderItemId;
        this.sku = sku;
        this.quantity = quantity;
        this.reason = reason;
        this.condition = condition;
    }
}

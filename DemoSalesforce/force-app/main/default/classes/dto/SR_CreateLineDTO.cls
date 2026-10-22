public inherited sharing class SR_CreateLineDTO {
    @AuraEnabled
    public Id orderItemId { get; set; }

    @AuraEnabled
    public String sku { get; set; }

    @AuraEnabled
    public Decimal quantity { get; set; }

    @AuraEnabled
    public String reason { get; set; }

    @AuraEnabled
    public String condition { get; set; }

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
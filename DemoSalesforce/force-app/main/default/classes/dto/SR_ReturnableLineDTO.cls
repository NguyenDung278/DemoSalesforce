public inherited sharing class SR_ReturnableLineDTO {
    @AuraEnabled
    public Id orderItemId { get; set; }

    @AuraEnabled
    public String sku { get; set; }

    @AuraEnabled
    public String productName { get; set; }

    @AuraEnabled
    public String productFamily { get; set; }

    @AuraEnabled
    public Decimal unitPrice { get; set; }

    @AuraEnabled
    public Decimal purchasedQuantity { get; set; }

    @AuraEnabled
    public Decimal previouslyReturnedQuantity { get; set; }

    @AuraEnabled
    public Decimal returnableQuantity { get; set; }

    @AuraEnabled
    public Date returnDeadline { get; set; }

    @AuraEnabled
    public Boolean returnable { get; set; }

    @AuraEnabled
    public String errorCode { get; set; }

    @AuraEnabled
    public String message { get; set; }

    @AuraEnabled
    public List<String> messageParams { get; set; }

    public SR_ReturnableLineDTO() {
        this.purchasedQuantity = 0;
        this.previouslyReturnedQuantity = 0;
        this.returnableQuantity = 0;
        this.returnable = false;
        this.messageParams = new List<String>();
    }
}
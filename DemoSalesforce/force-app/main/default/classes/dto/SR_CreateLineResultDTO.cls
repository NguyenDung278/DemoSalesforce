public inherited sharing class SR_CreateLineResultDTO {
    @AuraEnabled
    public Id orderItemId { get; set; }

    @AuraEnabled
    public Id lineId { get; set; }

    @AuraEnabled
    public String sku { get; set; }

    @AuraEnabled
    public Decimal quantity { get; set; }

    @AuraEnabled
    public Decimal unitPrice { get; set; }

    @AuraEnabled
    public Decimal refundRate { get; set; }

    @AuraEnabled
    public Decimal refundAmount { get; set; }

    @AuraEnabled
    public Boolean success { get; set; }

    @AuraEnabled
    public List<SR_ErrorDetailDTO> errors { get; set; }

    public SR_CreateLineResultDTO() {
        this.success = false;
        this.errors = new List<SR_ErrorDetailDTO>();
    }
}
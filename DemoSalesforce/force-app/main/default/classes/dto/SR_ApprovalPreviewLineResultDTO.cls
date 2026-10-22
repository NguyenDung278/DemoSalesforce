public inherited sharing class SR_ApprovalPreviewLineResultDTO {
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

    public SR_ApprovalPreviewLineResultDTO() {
        this.success = false;
        this.refundAmount = 0;
        this.errors = new List<SR_ErrorDetailDTO>();
    }
}
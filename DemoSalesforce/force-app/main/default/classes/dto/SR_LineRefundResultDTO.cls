public inherited sharing class SR_LineRefundResultDTO {
    @AuraEnabled
    public Boolean success { get; set; }

    @AuraEnabled
    public Id lineId { get; set; }

    @AuraEnabled
    public String sku { get; set; }

    @AuraEnabled
    public String inspectionResult { get; set; }

    @AuraEnabled
    public String actualCondition { get; set; }

    @AuraEnabled
    public Decimal quantity { get; set; }

    @AuraEnabled
    public Decimal unitPrice { get; set; }

    @AuraEnabled
    public Decimal refundRate { get; set; }

    @AuraEnabled
    public Decimal refundAmount { get; set; }

    @AuraEnabled
    public String errorCode { get; set; }

    @AuraEnabled
    public String message { get; set; }

    @AuraEnabled
    public List<SR_ErrorDetailDTO> details { get; set; }

    @AuraEnabled
    public String correlationId { get; set; }

    public SR_LineRefundResultDTO() {
        this.success = false;
        this.refundAmount = 0;
        this.details = new List<SR_ErrorDetailDTO>();
    }
}
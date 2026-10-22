public inherited sharing class SR_ApprovalPreviewResultDTO {
    @AuraEnabled
    public Boolean success { get; set; }

    @AuraEnabled
    public List<SR_ApprovalPreviewLineResultDTO> lines { get; set; }

    @AuraEnabled
    public Decimal estimatedRefund { get; set; }

    @AuraEnabled
    public String approvalLevel { get; set; }

    @AuraEnabled
    public List<SR_ErrorDetailDTO> errors { get; set; }

    @AuraEnabled
    public String correlationId { get; set; }

    public SR_ApprovalPreviewResultDTO() {
        this.success = false;
        this.estimatedRefund = 0;
        this.lines = new List<SR_ApprovalPreviewLineResultDTO>();
        this.errors = new List<SR_ErrorDetailDTO>();
    }
}
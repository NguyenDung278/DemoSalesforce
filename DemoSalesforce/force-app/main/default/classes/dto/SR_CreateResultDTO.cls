public inherited sharing class SR_CreateResultDTO {
    @AuraEnabled
    public Boolean success { get; set; }

    @AuraEnabled
    public Boolean isDuplicate { get; set; }

    @AuraEnabled
    public Id requestId { get; set; }

    @AuraEnabled
    public String requestNumber { get; set; }

    @AuraEnabled
    public String status { get; set; }

    @AuraEnabled
    public String approvalLevel { get; set; }

    @AuraEnabled
    public Decimal estimatedRefund { get; set; }

    @AuraEnabled
    public List<SR_CreateLineResultDTO> lines { get; set; }

    @AuraEnabled
    public List<SR_ErrorDetailDTO> errors { get; set; }

    @AuraEnabled
    public String correlationId { get; set; }

    @AuraEnabled
    public String versionToken { get; set; }

    public SR_CreateResultDTO() {
        this.success = false;
        this.isDuplicate = false;
        this.estimatedRefund = 0;
        this.lines = new List<SR_CreateLineResultDTO>();
        this.errors = new List<SR_ErrorDetailDTO>();
    }
}
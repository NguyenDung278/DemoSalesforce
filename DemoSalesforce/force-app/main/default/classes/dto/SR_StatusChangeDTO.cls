public inherited sharing class SR_StatusChangeDTO {
    @AuraEnabled
    public Id requestId { get; set; }

    @AuraEnabled
    public String targetStatus { get; set; }

    @AuraEnabled
    public String reason { get; set; }

    @AuraEnabled
    public String versionToken { get; set; }

    public SR_StatusChangeDTO() {
    }

    public SR_StatusChangeDTO(
        Id requestId,
        String targetStatus,
        String reason,
        String versionToken
    ) {
        this.requestId = requestId;
        this.targetStatus = targetStatus;
        this.reason = reason;
        this.versionToken = versionToken;
    }
}
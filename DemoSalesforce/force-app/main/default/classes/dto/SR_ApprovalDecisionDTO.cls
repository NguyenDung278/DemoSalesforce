public inherited sharing class SR_ApprovalDecisionDTO {
    @AuraEnabled
    public Id requestId { get; set; }

    @AuraEnabled
    public Boolean approve { get; set; }

    @AuraEnabled
    public String reason { get; set; }

    @AuraEnabled
    public String versionToken { get; set; }

    public SR_ApprovalDecisionDTO() {
    }

    public SR_ApprovalDecisionDTO(
        Id requestId,
        Boolean approve,
        String reason,
        String versionToken
    ) {
        this.requestId = requestId;
        this.approve = approve;
        this.reason = reason;
        this.versionToken = versionToken;
    }
}
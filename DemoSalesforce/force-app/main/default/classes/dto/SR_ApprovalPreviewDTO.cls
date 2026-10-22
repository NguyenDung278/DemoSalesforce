public inherited sharing class SR_ApprovalPreviewDTO {
    @AuraEnabled
    public Id accountId { get; set; }

    @AuraEnabled
    public Id orderId { get; set; }

    @AuraEnabled
    public String orderNumber { get; set; }

    @AuraEnabled
    public String channel { get; set; }

    @AuraEnabled
    public List<SR_CreateLineDTO> lines { get; set; }

    public SR_ApprovalPreviewDTO() {
        this.lines = new List<SR_CreateLineDTO>();
    }
}
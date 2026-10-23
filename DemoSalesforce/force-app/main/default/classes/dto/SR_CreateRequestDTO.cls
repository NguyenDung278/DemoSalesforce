public inherited sharing class SR_CreateRequestDTO {
    @AuraEnabled
    public String externalRequestId { get; set; }

    @AuraEnabled
    public String channel { get; set; }

    @AuraEnabled
    public Id orderId { get; set; }

    @AuraEnabled
    public String orderNumber { get; set; }

    @AuraEnabled
    public String customerPhone { get; set; }

    @AuraEnabled
    public String storeCode { get; set; }

    @AuraEnabled
    public List<SR_CreateLineDTO> lines { get; set; }

    @AuraEnabled
    public Boolean atomicMode { get; set; }

    public SR_CreateRequestDTO() {
        this.lines = new List<SR_CreateLineDTO>();
        this.atomicMode = false;
    }
}
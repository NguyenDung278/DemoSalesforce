/**
 * Shared request contract for LWC, REST and import adapters.
 * Business validation belongs to SR_ReturnRequestService.
 */
public with sharing class SR_CreateRequestDTO {
    @AuraEnabled public String externalRequestId;
    @AuraEnabled public String channel;
    @AuraEnabled public Id orderId;
    @AuraEnabled public String orderNumber;
    @AuraEnabled public String customerPhone;
    @AuraEnabled public String storeCode;
    @AuraEnabled public List<SR_CreateLineDTO> lines;
    @AuraEnabled public Boolean atomicMode;

    public SR_CreateRequestDTO() {
        lines = new List<SR_CreateLineDTO>();
        atomicMode = false;
    }
}

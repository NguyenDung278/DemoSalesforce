/**
 * Per-item result for bulk createRequests processing.
 * Partial success is supported unless the caller explicitly requests atomicMode.
 */
public with sharing class SR_CreateResultDTO {
    @AuraEnabled public Boolean success;
    @AuraEnabled public Boolean isDuplicate;
    @AuraEnabled public Id requestId;
    @AuraEnabled public String requestNumber;
    @AuraEnabled public String status;
    @AuraEnabled public String approvalLevel;
    @AuraEnabled public Decimal estimatedRefund;
    @AuraEnabled public List<SR_CreateLineResultDTO> lines;
    @AuraEnabled public List<SR_ErrorDetailDTO> errors;
    @AuraEnabled public String correlationId;

    public SR_CreateResultDTO() {
        success = false;
        isDuplicate = false;
        estimatedRefund = 0;
        lines = new List<SR_CreateLineResultDTO>();
        errors = new List<SR_ErrorDetailDTO>();
    }
}

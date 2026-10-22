public class SR_ActionResultDTO {
    @AuraEnabled public Boolean success;
    @AuraEnabled public Id recordId;
    @AuraEnabled public String requestNumber;
    @AuraEnabled public String status;
    @AuraEnabled public String errorCode;
    @AuraEnabled public String message;
    @AuraEnabled public List<SR_ErrorDetailDTO> details;
    @AuraEnabled public String correlationId;
    @AuraEnabled public String versionToken;
}

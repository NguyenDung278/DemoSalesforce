/**
 * Inspection input/result for one Return_Request_Line__c record.
 */
public with sharing class SR_LineResultDTO {
    @AuraEnabled public Id lineId;
    @AuraEnabled public String result;
    @AuraEnabled public String actualCondition;
    @AuraEnabled public String note;

    public SR_LineResultDTO() {
    }

    public SR_LineResultDTO(
        Id lineId,
        String result,
        String actualCondition,
        String note
    ) {
        this.lineId = lineId;
        this.result = result;
        this.actualCondition = actualCondition;
        this.note = note;
    }
}

public inherited sharing class SR_InspectionLineDTO {
    @AuraEnabled
    public Id lineId { get; set; }

    @AuraEnabled
    public String result { get; set; }

    @AuraEnabled
    public String actualCondition { get; set; }

    @AuraEnabled
    public String note { get; set; }

    public SR_InspectionLineDTO() {
    }

    public SR_InspectionLineDTO(
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
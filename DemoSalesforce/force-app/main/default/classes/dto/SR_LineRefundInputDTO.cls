public inherited sharing class SR_LineRefundInputDTO {
    @AuraEnabled
    public Id lineId { get; set; }

    @AuraEnabled
    public String inspectionResult { get; set; }

    @AuraEnabled
    public String actualCondition { get; set; }

    @AuraEnabled
    public String note { get; set; }

    public SR_LineRefundInputDTO() {
    }

    public SR_LineRefundInputDTO(
        Id lineId,
        String inspectionResult,
        String actualCondition,
        String note
    ) {
        this.lineId = lineId;
        this.inspectionResult = inspectionResult;
        this.actualCondition = actualCondition;
        this.note = note;
    }
}
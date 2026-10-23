public inherited sharing class SR_InspectionDTO {
    @AuraEnabled
    public Id requestId { get; set; }

    @AuraEnabled
    public String versionToken { get; set; }

    @AuraEnabled
    public List<SR_InspectionLineDTO> lines { get; set; }

    public SR_InspectionDTO() {
        this.lines = new List<SR_InspectionLineDTO>();
    }
}
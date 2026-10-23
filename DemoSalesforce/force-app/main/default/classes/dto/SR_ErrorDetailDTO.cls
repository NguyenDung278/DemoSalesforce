public inherited sharing class SR_ErrorDetailDTO {
    @AuraEnabled
    public String reference { get; set; }

    @AuraEnabled
    public String sku { get; set; }

    @AuraEnabled
    public String code { get; set; }

    @AuraEnabled
    public String message { get; set; }

    @AuraEnabled
    public List<String> params { get; set; }

    public SR_ErrorDetailDTO() {
        this.params = new List<String>();
    }

    public SR_ErrorDetailDTO(
        String reference,
        String code,
        String message
    ) {
        this();
        this.reference = reference;
        this.code = code;
        this.message = message;
    }

    public SR_ErrorDetailDTO(
        String reference,
        String sku,
        String code,
        String message,
        List<String> params
    ) {
        this.reference = reference;
        this.sku = sku;
        this.code = code;
        this.message = message;
        this.params = params == null
            ? new List<String>()
            : params;
    }
}
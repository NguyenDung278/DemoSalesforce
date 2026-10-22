/**
 * Shared data-transfer objects for SmartReturn.
 *
 * Rules:
 * - Do not expose Salesforce sObjects directly.
 * - Do not put business logic or SOQL/DML in this class.
 * - Portal/API services must populate only fields allowed for that channel.
 */
public class SR_DTO {

    /*
     * ============================================================
     * CREATE RETURN REQUEST
     * ============================================================
     */

    public class CreateRequest {
        @AuraEnabled
        public String externalRequestId { get; set; }

        @AuraEnabled
        public String channel { get; set; }

        @AuraEnabled
        public String orderNumber { get; set; }

        @AuraEnabled
        public String customerPhone { get; set; }

        @AuraEnabled
        public String storeCode { get; set; }

        @AuraEnabled
        public List<CreateLineDTO> lines { get; set; }

        @AuraEnabled
        public Boolean atomicMode { get; set; }

        public CreateRequest() {
            lines = new List<CreateLineDTO>();
            atomicMode = false;
        }
    }

    public class CreateLineDTO {
        @AuraEnabled
        public String sku { get; set; }

        @AuraEnabled
        public Decimal quantity { get; set; }

        @AuraEnabled
        public String reason { get; set; }

        @AuraEnabled
        public String condition { get; set; }
    }

    public class CreateResult {
        @AuraEnabled
        public Boolean success { get; set; }

        @AuraEnabled
        public Boolean duplicate { get; set; }

        @AuraEnabled
        public Id recordId { get; set; }

        @AuraEnabled
        public String requestNumber { get; set; }

        @AuraEnabled
        public String status { get; set; }

        @AuraEnabled
        public String statusLabel { get; set; }

        @AuraEnabled
        public String approvalLevel { get; set; }

        @AuraEnabled
        public Decimal estimatedRefundAmount { get; set; }

        @AuraEnabled
        public List<LineResultDTO> lines { get; set; }

        @AuraEnabled
        public String errorCode { get; set; }

        @AuraEnabled
        public String message { get; set; }

        @AuraEnabled
        public List<ErrorDetailDTO> details { get; set; }

        @AuraEnabled
        public String correlationId { get; set; }

        @AuraEnabled
        public String versionToken { get; set; }

        public CreateResult() {
            success = false;
            duplicate = false;
            lines = new List<LineResultDTO>();
            details = new List<ErrorDetailDTO>();
        }
    }

    public class LineResultDTO {
        @AuraEnabled
        public Boolean success { get; set; }

        @AuraEnabled
        public Id recordId { get; set; }

        @AuraEnabled
        public Id orderItemId { get; set; }

        @AuraEnabled
        public String sku { get; set; }

        @AuraEnabled
        public String productName { get; set; }

        @AuraEnabled
        public Decimal quantity { get; set; }

        @AuraEnabled
        public Decimal unitPrice { get; set; }

        @AuraEnabled
        public Decimal refundRate { get; set; }

        @AuraEnabled
        public Decimal refundAmount { get; set; }

        @AuraEnabled
        public String inspectionResult { get; set; }

        @AuraEnabled
        public String errorCode { get; set; }

        @AuraEnabled
        public String message { get; set; }

        public LineResultDTO() {
            success = false;
        }
    }

    public class ReturnableInfo {
        @AuraEnabled
        public Boolean success { get; set; }

        @AuraEnabled
        public Id orderId { get; set; }

        @AuraEnabled
        public String orderNumber { get; set; }

        @AuraEnabled
        public Id accountId { get; set; }

        @AuraEnabled
        public String customerName { get; set; }

        @AuraEnabled
        public String customerPhone { get; set; }

        @AuraEnabled
        public Date orderDate { get; set; }

        @AuraEnabled
        public Date deliveryDate { get; set; }

        @AuraEnabled
        public Id storeId { get; set; }

        @AuraEnabled
        public String storeCode { get; set; }

        @AuraEnabled
        public String storeName { get; set; }

        @AuraEnabled
        public List<ReturnableLineDTO> lines { get; set; }

        @AuraEnabled
        public String errorCode { get; set; }

        @AuraEnabled
        public String message { get; set; }

        @AuraEnabled
        public List<ErrorDetailDTO> details { get; set; }

        @AuraEnabled
        public String correlationId { get; set; }

        public ReturnableInfo() {
            success = false;
            lines = new List<ReturnableLineDTO>();
            details = new List<ErrorDetailDTO>();
        }
    }

    /*
     * ============================================================
     * RETURNABLE ORDER LINES
     * ============================================================
     */

    public class ReturnableLineDTO {
        @AuraEnabled
        public Id orderItemId { get; set; }

        @AuraEnabled
        public Id productId { get; set; }

        @AuraEnabled
        public String sku { get; set; }

        @AuraEnabled
        public String productName { get; set; }

        @AuraEnabled
        public String productFamily { get; set; }

        @AuraEnabled
        public Decimal purchasedQuantity { get; set; }

        /*
        * Quantity on requests already COMPLETED.
        */
        @AuraEnabled
        public Decimal returnedQuantity { get; set; }

        /*
        * Quantity on active requests:
        * NEW, PENDING_APPROVAL, AWAITING_GOODS,
        * INSPECTING, REFUND_PROCESSING, REFUND_FAILED.
        */
        @AuraEnabled
        public Decimal pendingQuantity { get; set; }

        /*
        * returnedQuantity + pendingQuantity.
        */
        @AuraEnabled
        public Decimal consumedQuantity { get; set; }

        /*
        * purchasedQuantity - consumedQuantity.
        */
        @AuraEnabled
        public Decimal returnableQuantity { get; set; }

        @AuraEnabled
        public Decimal unitPrice { get; set; }

        /*
        * Delivery_Date__c, falling back to EffectiveDate.
        */
        @AuraEnabled
        public Date returnBaseDate { get; set; }

        @AuraEnabled
        public Date returnDeadline { get; set; }

        @AuraEnabled
        public Boolean eligible { get; set; }

        @AuraEnabled
        public String ineligibleCode { get; set; }

        @AuraEnabled
        public String ineligibleReason { get; set; }

        public ReturnableLineDTO() {
            purchasedQuantity = 0;
            returnedQuantity = 0;
            pendingQuantity = 0;
            consumedQuantity = 0;
            returnableQuantity = 0;
            eligible = false;
        }
    }

    /*
     * ============================================================
     * APPROVAL
     * ============================================================
     */

    public class ApprovalPreviewDTO {
        @AuraEnabled
        public Decimal estimatedRefundAmount { get; set; }

        @AuraEnabled
        public Boolean customerRiskFlag { get; set; }

        @AuraEnabled
        public String channel { get; set; }

        @AuraEnabled
        public String storeCode { get; set; }
    }

    public class PreviewResult {
        @AuraEnabled
        public Boolean success { get; set; }

        @AuraEnabled
        public String approvalLevel { get; set; }

        @AuraEnabled
        public Boolean autoApproved { get; set; }

        @AuraEnabled
        public Id assignedApproverId { get; set; }

        @AuraEnabled
        public String assignedApproverName { get; set; }

        @AuraEnabled
        public String initialStatus { get; set; }

        @AuraEnabled
        public String errorCode { get; set; }

        @AuraEnabled
        public String message { get; set; }

        @AuraEnabled
        public List<ErrorDetailDTO> details { get; set; }

        @AuraEnabled
        public String correlationId { get; set; }

        public PreviewResult() {
            success = false;
            autoApproved = false;
            details = new List<ErrorDetailDTO>();
        }
    }

    public class ApprovalDecisionDTO {
        @AuraEnabled
        public Id requestId { get; set; }

        @AuraEnabled
        public Boolean approve { get; set; }

        @AuraEnabled
        public String reason { get; set; }

        @AuraEnabled
        public String versionToken { get; set; }
    }

    /*
     * ============================================================
     * INSPECTION
     * ============================================================
     */

    public class InspectionDTO {
        @AuraEnabled
        public Id requestId { get; set; }

        @AuraEnabled
        public String versionToken { get; set; }

        @AuraEnabled
        public List<InspectionLineDTO> lines { get; set; }

        public InspectionDTO() {
            lines = new List<InspectionLineDTO>();
        }
    }

    public class InspectionLineDTO {
        @AuraEnabled
        public Id lineId { get; set; }

        @AuraEnabled
        public String sku { get; set; }

        @AuraEnabled
        public String inspectionResult { get; set; }

        @AuraEnabled
        public String actualCondition { get; set; }

        @AuraEnabled
        public String note { get; set; }
    }

    /*
     * ============================================================
     * STATUS MACHINE
     * ============================================================
     */

    public class StatusChangeDTO {
        @AuraEnabled
        public Id requestId { get; set; }

        @AuraEnabled
        public String toStatus { get; set; }

        @AuraEnabled
        public String note { get; set; }

        @AuraEnabled
        public String correlationId { get; set; }

        @AuraEnabled
        public String versionToken { get; set; }
    }

    public class ActionResultDTO {
        @AuraEnabled
        public Boolean success { get; set; }

        @AuraEnabled
        public Id recordId { get; set; }

        @AuraEnabled
        public String requestNumber { get; set; }

        @AuraEnabled
        public String status { get; set; }

        @AuraEnabled
        public String statusLabel { get; set; }

        @AuraEnabled
        public Decimal estimatedRefundAmount { get; set; }

        @AuraEnabled
        public Decimal actualRefundAmount { get; set; }

        @AuraEnabled
        public String errorCode { get; set; }

        @AuraEnabled
        public String message { get; set; }

        @AuraEnabled
        public List<ErrorDetailDTO> details { get; set; }

        @AuraEnabled
        public String correlationId { get; set; }

        @AuraEnabled
        public String versionToken { get; set; }

        public ActionResultDTO() {
            success = false;
            details = new List<ErrorDetailDTO>();
        }
    }

    /*
     * ============================================================
     * REQUEST DETAIL FOR INTERNAL API / POS / APP
     * ============================================================
     */

    public class RequestDetailDTO {
        @AuraEnabled
        public Id recordId { get; set; }

        @AuraEnabled
        public String requestNumber { get; set; }

        @AuraEnabled
        public String externalRequestId { get; set; }

        @AuraEnabled
        public String orderNumber { get; set; }

        @AuraEnabled
        public String storeCode { get; set; }

        @AuraEnabled
        public String channel { get; set; }

        @AuraEnabled
        public String status { get; set; }

        @AuraEnabled
        public String statusLabel { get; set; }

        @AuraEnabled
        public String approvalLevel { get; set; }

        @AuraEnabled
        public Decimal estimatedRefundAmount { get; set; }

        @AuraEnabled
        public Decimal actualRefundAmount { get; set; }

        @AuraEnabled
        public Date goodsDueDate { get; set; }

        @AuraEnabled
        public Datetime createdAt { get; set; }

        @AuraEnabled
        public Datetime submittedAt { get; set; }

        @AuraEnabled
        public Datetime approvalDueAt { get; set; }

        @AuraEnabled
        public String rejectionReason { get; set; }

        @AuraEnabled
        public String versionToken { get; set; }

        @AuraEnabled
        public List<RequestLineDTO> lines { get; set; }

        @AuraEnabled
        public List<HistoryDTO> history { get; set; }

        public RequestDetailDTO() {
            lines = new List<RequestLineDTO>();
            history = new List<HistoryDTO>();
        }
    }

    public class RequestLineDTO {
        @AuraEnabled
        public Id lineId { get; set; }

        @AuraEnabled
        public String sku { get; set; }

        @AuraEnabled
        public String productName { get; set; }

        @AuraEnabled
        public Decimal quantity { get; set; }

        @AuraEnabled
        public Decimal unitPrice { get; set; }

        @AuraEnabled
        public String reason { get; set; }

        @AuraEnabled
        public String declaredCondition { get; set; }

        @AuraEnabled
        public String actualCondition { get; set; }

        @AuraEnabled
        public Decimal estimatedRefundAmount { get; set; }

        @AuraEnabled
        public Decimal actualRefundAmount { get; set; }

        @AuraEnabled
        public String inspectionResult { get; set; }

        @AuraEnabled
        public String inspectionNote { get; set; }
    }

    public class HistoryDTO {
        @AuraEnabled
        public String fromStatus { get; set; }

        @AuraEnabled
        public String fromStatusLabel { get; set; }

        @AuraEnabled
        public String toStatus { get; set; }

        @AuraEnabled
        public String toStatusLabel { get; set; }

        @AuraEnabled
        public Datetime changedAt { get; set; }

        @AuraEnabled
        public String changedByName { get; set; }

        @AuraEnabled
        public String note { get; set; }
    }

    /*
     * ============================================================
     * CUSTOMER PORTAL
     *
     * Deliberately excludes:
     * - Customer full name
     * - Customer full phone number
     * - Internal note
     * - PayHub operational information
     * ============================================================
     */

    public class PortalRequestDTO {
        @AuraEnabled
        public String requestNumber { get; set; }

        @AuraEnabled
        public String orderNumber { get; set; }

        @AuraEnabled
        public String status { get; set; }

        @AuraEnabled
        public String statusLabel { get; set; }

        @AuraEnabled
        public Decimal refundAmount { get; set; }

        @AuraEnabled
        public Datetime createdAt { get; set; }

        @AuraEnabled
        public List<PortalLineDTO> lines { get; set; }

        @AuraEnabled
        public List<PortalHistoryDTO> history { get; set; }

        public PortalRequestDTO() {
            lines = new List<PortalLineDTO>();
            history = new List<PortalHistoryDTO>();
        }
    }

    public class PortalLineDTO {
        @AuraEnabled
        public String sku { get; set; }

        @AuraEnabled
        public String productName { get; set; }

        @AuraEnabled
        public Decimal quantity { get; set; }

        @AuraEnabled
        public String inspectionResult { get; set; }
    }

    public class PortalHistoryDTO {
        @AuraEnabled
        public String status { get; set; }

        @AuraEnabled
        public String statusLabel { get; set; }

        @AuraEnabled
        public Datetime changedAt { get; set; }
    }

    /*
     * ============================================================
     * REFUND / EVENT
     * ============================================================
     */

    public class RefundResultDTO {
        @AuraEnabled
        public String requestNumber { get; set; }

        @AuraEnabled
        public String result { get; set; }

        @AuraEnabled
        public Decimal amount { get; set; }

        @AuraEnabled
        public String storeCode { get; set; }

        @AuraEnabled
        public Datetime eventTime { get; set; }

        @AuraEnabled
        public String correlationId { get; set; }
    }

    public class RefundCallbackDTO {
        @AuraEnabled
        public String refundId { get; set; }

        @AuraEnabled
        public String merchantRef { get; set; }

        @AuraEnabled
        public String status { get; set; }

        @AuraEnabled
        public String failureReason { get; set; }

        @AuraEnabled
        public Datetime processedAt { get; set; }
    }

    /*
     * ============================================================
     * STANDARD ERROR RESPONSE
     * ============================================================
     */

    public class ErrorResponseDTO {
        @AuraEnabled
        public String errorCode { get; set; }

        @AuraEnabled
        public String message { get; set; }

        @AuraEnabled
        public List<ErrorDetailDTO> details { get; set; }

        @AuraEnabled
        public String correlationId { get; set; }

        public ErrorResponseDTO() {
            details = new List<ErrorDetailDTO>();
        }
    }

    public class ErrorDetailDTO {
        @AuraEnabled
        public String reference { get; set; }

        @AuraEnabled
        public String sku { get; set; }

        @AuraEnabled
        public String fieldName { get; set; }

        @AuraEnabled
        public String code { get; set; }

        @AuraEnabled
        public String message { get; set; }

        public ErrorDetailDTO() {
        }

        public ErrorDetailDTO(
            String reference,
            String code,
            String message
        ) {
            this.reference = reference;
            this.code = code;
            this.message = message;
        }
    }
}
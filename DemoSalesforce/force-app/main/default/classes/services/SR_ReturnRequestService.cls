public with sharing class SR_ReturnRequestService {
    @AuraEnabled(cacheable=true)
    public static List<SR_ReturnableLineDTO> getReturnableLines(Id orderId) {
        List<SR_ReturnableLineDTO> results = new List<SR_ReturnableLineDTO>();
        if (orderId == null) {
            return results;
        }

        SR_ReturnableLineDTO line = new SR_ReturnableLineDTO();
        line.orderId = orderId;
        line.orderNumber = 'STUB-ORDER';
        line.productName = 'STUB Product';
        line.sku = 'STUB-SKU';
        line.family = 'Điện thoại';
        line.unitPrice = 1000000;
        line.purchasedQuantity = 1;
        line.returnedQuantity = 0;
        line.returnableQuantity = 1;
        line.returnWindowEnd = Date.today().addDays(7);
        line.eligible = true;
        results.add(line);
        return results;
    }

    @AuraEnabled
    public static List<SR_CreateResultDTO> createRequests(
        List<SR_CreateRequestDTO> requests
    ) {
        List<SR_CreateResultDTO> results = new List<SR_CreateResultDTO>();
        if (requests == null) {
            return results;
        }

        Integer sequence = 1;
        for (SR_CreateRequestDTO request : requests) {
            SR_CreateResultDTO item = new SR_CreateResultDTO();
            item.success = request != null && request.lines != null && !request.lines.isEmpty();
            item.isDuplicate = false;
            item.requestNumber = 'STUB-' + String.valueOf(sequence).leftPad(5, '0');
            item.status = 'NEW';
            item.lines = new List<SR_LineRefundDTO>();
            item.estimatedRefund = 0;

            if (item.success) {
                SR_ApprovalPreviewDTO previewInput = new SR_ApprovalPreviewDTO();
                previewInput.riskFlag = request.riskFlag;
                previewInput.lines = new List<SR_ApprovalPreviewLineDTO>();

                for (SR_CreateLineDTO sourceLine : request.lines) {
                    SR_ApprovalPreviewLineDTO previewLine = new SR_ApprovalPreviewLineDTO();
                    previewLine.orderItemId = sourceLine.orderItemId;
                    previewLine.sku = sourceLine.sku;
                    previewLine.quantity = sourceLine.quantity;
                    previewLine.unitPrice = sourceLine.unitPrice;
                    previewLine.reason = sourceLine.reason;
                    previewLine.condition = sourceLine.condition;
                    previewInput.lines.add(previewLine);
                }

                SR_ApprovalPreviewResultDTO preview = SR_ApprovalService.previewLevel(previewInput);
                item.success = preview.success;
                item.lines = preview.lines;
                item.estimatedRefund = preview.totalRefund;
                item.approvalLevel = preview.approvalLevel;
                item.errorCode = preview.errorCode;
                item.message = preview.success
                    ? 'STUB: yêu cầu giả đã được tạo.'
                    : preview.message;
            } else {
                item.errorCode = 'MISSING_FIELD';
                item.message = 'STUB: cần ít nhất một dòng yêu cầu.';
            }
            results.add(item);
            sequence++;
        }
        return results;
    }
}

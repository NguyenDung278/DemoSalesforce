public with sharing class SR_ApprovalService {
    private static final Decimal ROUNDING_UNIT = 1000;
    private static final String LEVEL_AUTO = 'AUTO';
    private static final String LEVEL_CHT = 'CHT';
    private static final String LEVEL_QLV = 'QLV';

    @TestVisible private static Map<String, Decimal> refundRateOverrides;
    @TestVisible private static Decimal autoThresholdOverride;
    @TestVisible private static Decimal chtMaxThresholdOverride;
    @TestVisible private static Boolean autoApprovalEnabledOverride;

    @AuraEnabled(cacheable=true)
    public static SR_LineRefundDTO calcLineRefund(SR_ApprovalPreviewLineDTO line) {
        SR_LineRefundDTO result = new SR_LineRefundDTO();
        result.success = false;
        result.refundAmount = 0;

        if (line == null || line.quantity == null || line.quantity <= 0 ||
            line.unitPrice == null || line.unitPrice < 0 ||
            String.isBlank(line.reason) || String.isBlank(line.condition)) {
            result.errorCode = 'INVALID_VALUE';
            result.message = 'Thiếu hoặc sai dữ liệu tính tiền hoàn.';
            return result;
        }

        result.orderItemId = line.orderItemId;
        result.sku = line.sku;
        result.quantity = line.quantity;
        result.unitPrice = line.unitPrice;
        result.reason = line.reason;
        result.condition = line.condition;

        Decimal rate = getRefundRate(line.reason, line.condition);
        if (rate == null) {
            result.errorCode = 'CONFIGURATION_ERROR';
            result.message = 'Không tìm thấy tỷ lệ hoàn phù hợp.';
            return result;
        }

        Decimal rawAmount = line.unitPrice * line.quantity * rate / 100;
        result.refundRate = rate;
        result.refundAmount = (rawAmount / ROUNDING_UNIT)
            .setScale(0, RoundingMode.FLOOR) * ROUNDING_UNIT;
        result.success = true;
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static SR_ApprovalPreviewResultDTO previewLevel(SR_ApprovalPreviewDTO input) {
        SR_ApprovalPreviewResultDTO result = new SR_ApprovalPreviewResultDTO();
        result.success = false;
        result.lines = new List<SR_LineRefundDTO>();
        result.totalRefund = 0;

        if (input == null || input.lines == null || input.lines.isEmpty()) {
            result.errorCode = 'MISSING_FIELD';
            result.message = 'Cần ít nhất một dòng nháp để xem trước cấp duyệt.';
            return result;
        }

        for (SR_ApprovalPreviewLineDTO line : input.lines) {
            SR_LineRefundDTO lineResult = calcLineRefund(line);
            result.lines.add(lineResult);
            if (!lineResult.success) {
                result.errorCode = lineResult.errorCode;
                result.message = lineResult.message;
                return result;
            }
            result.totalRefund += lineResult.refundAmount;
        }

        result.approvalLevel = resolveApprovalLevel(
            result.totalRefund,
            input.riskFlag == true
        );
        if (result.approvalLevel == null) {
            result.errorCode = 'CONFIGURATION_ERROR';
            result.message = 'Thiếu cấu hình ngưỡng duyệt.';
            return result;
        }

        result.success = true;
        return result;
    }

    @AuraEnabled
    public static List<SR_ActionResultDTO> decide(
        List<SR_ApprovalDecisionDTO> decisions
    ) {
        List<SR_ActionResultDTO> results = new List<SR_ActionResultDTO>();
        if (decisions == null) {
            return results;
        }

        for (SR_ApprovalDecisionDTO decision : decisions) {
            SR_ActionResultDTO item = new SR_ActionResultDTO();
            item.success = decision != null && decision.requestId != null;
            item.recordId = decision == null ? null : decision.requestId;
            item.status = decision != null && decision.approve == true
                ? 'AWAITING_GOODS'
                : 'REJECTED';
            item.versionToken = decision == null ? null : decision.versionToken;
            item.message = item.success
                ? 'STUB: quyết định đã được tiếp nhận.'
                : 'STUB: requestId là bắt buộc.';
            item.errorCode = item.success ? null : 'MISSING_FIELD';
            results.add(item);
        }
        return results;
    }

    private static Decimal getRefundRate(String reason, String condition) {
        String key = reason + '_' + condition;
        if (refundRateOverrides != null && refundRateOverrides.containsKey(key)) {
            return refundRateOverrides.get(key);
        }

        SR_Refund_Rate__mdt config = SR_Refund_Rate__mdt.getInstance(key);
        if (config == null || config.Active__c != true) {
            return null;
        }
        return config.Refund_Rate__c;
    }

    private static String resolveApprovalLevel(Decimal total, Boolean riskFlag) {
        if (riskFlag) {
            return LEVEL_QLV;
        }

        SR_Setting__mdt setting = SR_Setting__mdt.getInstance('Default');
        Decimal autoThreshold = autoThresholdOverride != null
            ? autoThresholdOverride
            : (setting == null ? null : setting.Auto_Approval_Threshold__c);
        Decimal chtMaxThreshold = chtMaxThresholdOverride != null
            ? chtMaxThresholdOverride
            : (setting == null ? null : setting.Store_Manager_Max_Threshold__c);
        Boolean autoEnabled = autoApprovalEnabledOverride != null
            ? autoApprovalEnabledOverride
            : (setting == null ? null : setting.Enable_Auto_Approval__c);

        if (autoThreshold == null || chtMaxThreshold == null || autoEnabled == null) {
            return null;
        }
        if (autoEnabled && total <= autoThreshold) {
            return LEVEL_AUTO;
        }
        return total <= chtMaxThreshold ? LEVEL_CHT : LEVEL_QLV;
    }
}

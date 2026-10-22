public with sharing class SR_ReturnRequestService {

    private static final Integer MAX_BATCH_SIZE = 200;
    
    private static final Decimal REFUND_ROUNDING_UNIT = 1000;

    private static final Set<String> EXCLUDED_QUANTITY_STATUSES =
        new Set<String>{
            'REJECTED',
            'CANCELLED'
        };

    private static final Set<String> COMPLETED_STATUSES =
        new Set<String>{
            'COMPLETED'
        };

    /**
     * Tính tiền hoàn cho một dòng:
     *
     * unit price × quantity × refund rate
     *
     * Kết quả được làm tròn xuống đến 1.000 VND.
     */
    public static Decimal calcLineRefund(
        Decimal unitPrice,
        Decimal quantity,
        String reason,
        String actualCondition
    ) {
        validateRefundInput(
            unitPrice,
            quantity,
            reason,
            actualCondition
        );

        Decimal refundRate = SR_Config.getRefundRate(
            normalizeValue(reason),
            normalizeValue(actualCondition)
        );

        if (refundRate == null || refundRate < 0 || refundRate > 1) {
            throw new SR_ConfigurationException(
                'Refund rate không hợp lệ cho reason='
                + reason
                + ', condition='
                + actualCondition
            );
        }

        Decimal rawRefund = unitPrice * quantity * refundRate;

        return roundDownToThousand(rawRefund);
    }

    /**
     * Hàm đang được LWC/Aura gọi khi nhân viên đổi tình trạng thực tế.
     */
    @AuraEnabled(cacheable=true)
    public static Decimal calcLineRefund(
        Id lineId,
        String actualCondition
    ) {
        if (lineId == null) {
            throw new IllegalArgumentException(
                'lineId không được để trống.'
            );
        }

        Return_Request_Line__c lineRecord =
            SR_ReturnRequestLineSelector.selectById(lineId);

        return calcLineRefund(
            lineRecord.Unit_Price__c,
            lineRecord.Quantity__c,
            lineRecord.Reason__c,
            actualCondition
        );
    }

    private static void validateRefundInput(
        Decimal unitPrice,
        Decimal quantity,
        String reason,
        String condition
    ) {
        if (unitPrice == null || unitPrice < 0) {
            throw new IllegalArgumentException(
                'unitPrice phải lớn hơn hoặc bằng 0.'
            );
        }

        if (quantity == null || quantity <= 0) {
            throw new IllegalArgumentException(
                'quantity phải lớn hơn 0.'
            );
        }

        if (String.isBlank(reason)) {
            throw new IllegalArgumentException(
                'reason không được để trống.'
            );
        }

        if (String.isBlank(condition)) {
            throw new IllegalArgumentException(
                'actualCondition không được để trống.'
            );
        }
    }

    private static String normalizeValue(String value) {
        return value == null
            ? null
            : value.trim().toUpperCase();
    }

    @TestVisible
    private static Decimal roundDownToThousand(Decimal amount) {
        if (amount == null || amount <= 0) {
            return 0;
        }

        return (
            amount / REFUND_ROUNDING_UNIT
        ).setScale(
            0,
            RoundingMode.FLOOR
        ) * REFUND_ROUNDING_UNIT;
    }

    public class SR_DomainException extends Exception {
        public String errorCode { get; private set; }

        public SR_DomainException(
            String errorCode,
            String message
        ) {
            this.errorCode = errorCode;
            this.setMessage(message);
        }
    }

}
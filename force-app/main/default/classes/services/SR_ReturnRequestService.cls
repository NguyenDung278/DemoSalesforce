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

    /*
     * ============================================================
     * PUBLIC API
     * ============================================================
     */

    @AuraEnabled(cacheable=true)
    public static SR_DTO.ReturnableInfo getReturnableInfo(Id orderId) {
        String correlationId = newCorrelationId();
        SR_DTO.ReturnableInfo result = new SR_DTO.ReturnableInfo();
        result.correlationId = correlationId;

        try {
            validateOrderId(orderId);

            Order orderRecord = queryOrderWithLines(orderId);

            result.orderId = orderRecord.Id;
            result.orderNumber = orderRecord.OrderNumber;
            result.accountId = orderRecord.AccountId;
            result.customerName = orderRecord.Account == null
                ? null
                : orderRecord.Account.Name;
            result.customerPhone = orderRecord.Account == null
                ? null
                : orderRecord.Account.Phone;
            result.orderDate = orderRecord.EffectiveDate;
            result.deliveryDate = orderRecord.Delivery_Date__c;
            result.storeId = orderRecord.Store__c;
            result.storeCode = orderRecord.Store__r == null
                ? null
                : orderRecord.Store__r.Store_Code__c;
            result.storeName = orderRecord.Store__r == null
                ? null
                : orderRecord.Store__r.Name;

            Set<Id> orderItemIds = new Set<Id>();
            for (OrderItem item: orderRecord.OrderItems) {
                orderItemIds.add(item.Id);
            }

            QuantitySummary quantitySummary =
                loadQuantitySummary(orderItemIds);

            for (OrderItem item: orderRecord.OrderItems) {
                result.lines.add(
                    buildReturnableLine(
                        orderRecord,
                        item,
                        quantitySummary
                    )
                );
            }

            result.success = true;
            return result;
        } catch (Exception ex) {
            return buildReturnableError(
                result,
                ex,
                correlationId
            );
        }
    }

    /*
     * Compatibility method for existing LWC/API callers.
     */
    @AuraEnabled(cacheable=true)
    public static List<SR_DTO.ReturnableLineDTO> getReturnableLines(
        Id orderId
    ) {
        SR_DTO.ReturnableInfo info = getReturnableInfo(orderId);

        if (!info.success) {
            throw new AuraHandledException(info.message);
        }

        return info.lines;
    }

    public static List<SR_DTO.CreateResultDTO> createRequests(
        List<SR_DTO.CreateRequestDTO> requests
    ) {
        if (requests == null || requests.isEmpty()) {
            return new List<SR_DTO.CreateResultDTO>();
        }

        if (requests.size() > MAX_BATCH_SIZE) {
            return buildBatchSizeErrors(requests);
        }

        Boolean atomicMode = validateAtomicMode(requests);
        Savepoint batchSavepoint;

        if (atomicMode) {
            batchSavepoint = Database.setSavepoint();
        }

        List<SR_DTO.CreateResultDTO> results =
            initialiseResults(requests);

        try {
            CreationContext context =
                prepareCreationContext(requests, results);

            processDuplicateRequests(context, requests, results);

            validateRequestHeaders(context, requests, results);

            /*
             * Lock only after basic validation and idempotency lookup,
             * reducing the time records remain locked.
             */
            lockOrders(context.orderIds);

            /*
             * Re-query quantity after obtaining the locks.
             */
            loadLockedOrderData(context);
            loadConsumedQuantities(context);

            validateAndPrepareRequests(
                context,
                requests,
                results
            );

            persistPreparedRequests(context, results);

            routeCreatedRequests(context, results);

            if (atomicMode && hasFailure(results)) {
                Database.rollback(batchSavepoint);
                markAtomicRollback(results);
            }

            return results;
        } catch (Exception ex) {
            if (atomicMode && batchSavepoint!= null) {
                Database.rollback(batchSavepoint);
            }

            return applyUnexpectedBatchError(
                requests,
                results,
                ex
            );
        }
    }

    /*
     * ============================================================
     * RETURNABLE INFORMATION
     * ============================================================
     */

    private static Order queryOrderWithLines(Id orderId) {
        List<Order> records = [
            SELECT
                Id,
                OrderNumber,
                AccountId,
                Account.Name,
                Account.Phone,
                EffectiveDate,
                Delivery_Date__c,
                Store__c,
                Store__r.Name,
                Store__r.Store_Code__c,
                (
                    SELECT
                        Id,
                        Quantity,
                        UnitPrice,
                        Product2Id,
                        Product2.Name,
                        Product2.ProductCode,
                        Product2.Family
                    FROM OrderItems
                    ORDER BY CreatedDate ASC
                )
            FROM Order
            WHERE Id =:orderId
            LIMIT 1
        ];

        if (records.isEmpty()) {
            throw new SR_DomainException(
                'ORDER_NOT_FOUND',
                'Không tìm thấy đơn hàng.'
            );
        }

        return records[0];
    }

    private static SR_DTO.ReturnableLineDTO buildReturnableLine(
        Order orderRecord,
        OrderItem item,
        QuantitySummary summary
    ) {
        SR_DTO.ReturnableLineDTO model =
            new SR_DTO.ReturnableLineDTO();

        model.orderItemId = item.Id;
        model.productId = item.Product2Id;
        model.sku = item.Product2 == null
            ? null
            : item.Product2.ProductCode;
        model.productName = item.Product2 == null
            ? null
            : item.Product2.Name;
        model.productFamily = item.Product2 == null
            ? null
            : item.Product2.Family;
        model.unitPrice = item.UnitPrice;
        model.purchasedQuantity = valueOrZero(item.Quantity);

        model.returnedQuantity =
            summary.completedByOrderItem.containsKey(item.Id)
            ? summary.completedByOrderItem.get(item.Id)
            : 0;

        model.pendingQuantity =
            summary.pendingByOrderItem.containsKey(item.Id)
            ? summary.pendingByOrderItem.get(item.Id)
            : 0;

        model.consumedQuantity =
            model.returnedQuantity + model.pendingQuantity;

        model.returnableQuantity = Decimal.max(
            0,
            model.purchasedQuantity - model.consumedQuantity
        );

        model.returnBaseDate =
            orderRecord.Delivery_Date__c == null
            ? orderRecord.EffectiveDate
            : orderRecord.Delivery_Date__c;

        applyEligibility(model);

        return model;
    }

    private static void applyEligibility(
        SR_DTO.ReturnableLineDTO model
    ) {
        /*
         * Exact SR_Config method names should match the real class.
         */
        SR_Config.CategoryPolicy policy =
            SR_Config.categoryPolicy(model.productFamily);

        if (policy == null ||!policy.isReturnable) {
            lockLine(
                model,
                'NOT_RETURNABLE',
                'Ngành hàng không áp dụng đổi trả.'
            );
            return;
        }

        if (model.returnBaseDate == null) {
            lockLine(
                model,
                'INVALID_VALUE',
                'Đơn hàng chưa có ngày giao hoặc ngày hiệu lực.'
            );
            return;
        }

        model.returnDeadline =
            model.returnBaseDate.addDays(policy.returnWindowDays);

        /*
         * Date comparison naturally allows return through the
         * end of returnDeadline.
         */
        if (Date.today() > model.returnDeadline) {
            lockLine(
                model,
                'RETURN_WINDOW_EXPIRED',
                'Sản phẩm đã quá hạn đổi trả.'
            );
            return;
        }

        if (model.returnableQuantity <= 0) {
            lockLine(
                model,
                'QUANTITY_EXCEEDED',
                'Sản phẩm không còn số lượng có thể trả.'
            );
            return;
        }

        model.eligible = true;
        model.ineligibleCode = null;
        model.ineligibleReason = null;
    }

    private static void lockLine(
        SR_DTO.ReturnableLineDTO model,
        String code,
        String reason
    ) {
        model.eligible = false;
        model.ineligibleCode = code;
        model.ineligibleReason = reason;
    }

    /*
     * ============================================================
     * QUANTITY
     * ============================================================
     */

    private static QuantitySummary loadQuantitySummary(
        Set<Id> orderItemIds
    ) {
        QuantitySummary result = new QuantitySummary();

        if (orderItemIds.isEmpty()) {
            return result;
        }

        for (AggregateResult row: [
            SELECT
                Order_Item__c orderItemId,
                Return_Request__r.Status__c requestStatus,
                SUM(Quantity__c) totalQuantity
            FROM Return_Request_Line__c
            WHERE Order_Item__c IN:orderItemIds
            AND Return_Request__r.Status__c
                NOT IN ('REJECTED', 'CANCELLED')
            GROUP BY
                Order_Item__c,
                Return_Request__r.Status__c
        ]) {
            Id orderItemId = (Id) row.get('orderItemId');
            String status = (String) row.get('requestStatus');
            Decimal quantity =
                (Decimal) row.get('totalQuantity');

            if (status == 'COMPLETED') {
                addQuantity(
                    result.completedByOrderItem,
                    orderItemId,
                    quantity
                );
            } else {
                addQuantity(
                    result.pendingByOrderItem,
                    orderItemId,
                    quantity
                );
            }
        }

        return result;
    }

    private static void addQuantity(
        Map<Id, Decimal> values,
        Id recordId,
        Decimal quantity
    ) {
        Decimal currentValue = values.containsKey(recordId)
            ? values.get(recordId)
            : 0;

        values.put(
            recordId,
            currentValue + valueOrZero(quantity)
        );
    }

    private class QuantitySummary {
        Map<Id, Decimal> completedByOrderItem {
            get;
            private set;
        }

        Map<Id, Decimal> pendingByOrderItem {
            get;
            private set;
        }

        QuantitySummary() {
            completedByOrderItem = new Map<Id, Decimal>();
            pendingByOrderItem = new Map<Id, Decimal>();
        }
    }

    /*
     * ============================================================
     * COMMON HELPERS
     * ============================================================
     */

    private static Decimal valueOrZero(Decimal input) {
        return input == null? 0: input;
    }

    private static void validateOrderId(Id orderId) {
        if (orderId == null) {
            throw new SR_DomainException(
                'MISSING_FIELD',
                'Thiếu orderId.'
            );
        }
    }

    private static String newCorrelationId() {
        return String.valueOf(Crypto.getRandomLong())
            + '-'
            + String.valueOf(Datetime.now().getTime());
    }

    private static SR_DTO.ReturnableInfo buildReturnableError(
        SR_DTO.ReturnableInfo result,
        Exception ex,
        String correlationId
    ) {
        result.success = false;
        result.correlationId = correlationId;

        if (ex instanceof SR_DomainException) {
            SR_DomainException domainEx =
                (SR_DomainException) ex;

            result.errorCode = domainEx.errorCode;
            result.message = domainEx.getMessage();
        } else {
            result.errorCode = 'INTERNAL_ERROR';
            result.message =
                'Không thể đọc thông tin đổi trả.';

            /*
             * SR_Logger should receive the original exception,
             * correlation ID and current user, but must not expose
             * stack trace to the caller.
             */
        }

        return result;
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
}
public with sharing class SR_RefundCalculator {
    private static final Decimal ROUND_UNIT = 1000;

    public static Decimal rateFor(String reason, String condition) {
        return SR_Config.getRefundRate(reason, condition);
    }

    public static Decimal lineAmount(Decimal unitPrice, Decimal quantity, Decimal refundRate) {
        if (unitPrice == null || quantity == null || refundRate == null) {
            return 0;
        }
        Decimal normalized = refundRate > 1 ? refundRate / 100 : refundRate;
        Decimal raw = unitPrice * quantity * normalized;
        return (raw / ROUND_UNIT).setScale(0, RoundingMode.FLOOR) * ROUND_UNIT;
    }

    public static Decimal total(List<Decimal> lineAmounts) {
        Decimal sum = 0;
        if (lineAmounts == null) {
            return sum;
        }
        for (Decimal amount : lineAmounts) {
            sum += amount == null ? 0 : amount;
        }
        return sum;
    }
}

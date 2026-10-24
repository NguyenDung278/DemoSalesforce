@IsTest(SeeAllData=false)
private class SR_RefundCalculatorTest {
    @IsTest
    static void positive_ratesAndRounding() {
        Assert.areEqual(2490000, SR_RefundCalculator.lineAmount(2490000, 1, 100));
        Assert.areEqual(1992000, SR_RefundCalculator.lineAmount(2490000, 1, 80));
        Assert.areEqual(0, SR_RefundCalculator.lineAmount(2490000, 1, 0));
        Assert.areEqual(1000, SR_RefundCalculator.lineAmount(1550, 1, 1));
        Assert.areEqual(3482000, SR_RefundCalculator.total(new List<Decimal>{ 2490000, 992000, null }));
    }

    @IsTest
    static void negative_nullInputsReturnZero() {
        Assert.areEqual(0, SR_RefundCalculator.lineAmount(null, 1, 100));
        Assert.areEqual(0, SR_RefundCalculator.lineAmount(1000, null, 100));
        Assert.areEqual(0, SR_RefundCalculator.lineAmount(1000, 1, null));
        Assert.areEqual(0, SR_RefundCalculator.total(null));
    }

    @IsTest
    static void bulk_sumsTwoHundredLines() {
        List<Decimal> amounts = new List<Decimal>();
        for (Integer i = 0; i < 200; i++) {
            amounts.add(SR_RefundCalculator.lineAmount(1550, 1, 100));
        }
        Assert.areEqual(200000, SR_RefundCalculator.total(amounts));
    }
}

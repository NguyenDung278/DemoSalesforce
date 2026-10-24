@IsTest(SeeAllData=false)
private class SR_ReturnEligibilityServiceTest {
    @IsTest
    static void positive_lastDayStillValid() {
        SR_CategoryPolicy policy = new SR_CategoryPolicy('Laptop', true, 7, true);
        Date delivered = Date.today().addDays(-7);
        Order orderRow = new Order(Delivery_Date__c = delivered, EffectiveDate = Date.today().addDays(-10));
        Date deadline = SR_ReturnEligibilityService.resolveDeadline(
            SR_ReturnEligibilityService.resolveAnchorDate(orderRow),
            policy
        );
        Assert.areEqual(Date.today(), deadline);
        Assert.isTrue(SR_ReturnEligibilityService.isWithinReturnWindow(Date.today(), deadline));
    }

    @IsTest
    static void negative_expiredAndNonReturnable() {
        SR_CategoryPolicy expiredPolicy = new SR_CategoryPolicy('Laptop', true, 7, true);
        Date deadline = Date.today().addDays(-1);
        Assert.isFalse(SR_ReturnEligibilityService.isWithinReturnWindow(Date.today(), deadline));
        Assert.isFalse(SR_ReturnEligibilityService.isCategoryReturnable(new SR_CategoryPolicy('Thẻ cào', false, 0, true)));
        Assert.isFalse(SR_ReturnEligibilityService.isCategoryReturnable(new SR_CategoryPolicy('X', true, 7, false)));
        Assert.isNotNull(expiredPolicy);
    }

    @IsTest
    static void positive_counterOrderUsesEffectiveDate() {
        Order counterOrder = new Order(EffectiveDate = Date.today().addDays(-2), Delivery_Date__c = null);
        Assert.areEqual(Date.today().addDays(-2), SR_ReturnEligibilityService.resolveAnchorDate(counterOrder));
    }

    @IsTest
    static void bulk_quantityLocksTwoHundredLines() {
        Map<Id, Decimal> reserved = new Map<Id, Decimal>();
        SR_ReturnableLineDTO sample = new SR_ReturnableLineDTO();
        for (Integer i = 0; i < 200; i++) {
            sample.returnableQuantity = 0;
            sample.returnDeadline = Date.today().addDays(1);
            SR_ReturnEligibilityService.applyLock(
                sample,
                new SR_CategoryPolicy('Laptop', true, 30, true),
                Date.today()
            );
        }
        Assert.isFalse(sample.eligible);
        Assert.areEqual(SR_ErrorCode.QUANTITY_EXCEEDED, sample.lockCode);
        Assert.areEqual(0, SR_ReturnEligibilityService.remainingQuantity(2, 5));
        Assert.areEqual(0, SR_ReturnEligibilityService.reservedQuantity(null, reserved));
    }
}

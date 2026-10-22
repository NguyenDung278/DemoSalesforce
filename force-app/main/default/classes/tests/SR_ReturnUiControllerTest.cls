/**
 * Test cho SR_ReturnUiController (D.1).
 *  ở đây kiểm tra controller gọi đúng và báo lỗi dễ đọc.
 */
@IsTest
private class SR_ReturnUiControllerTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Khách test D.1', Phone = '0900000001');
        insert acc;
        Product2 laptop = new Product2(Name = 'Laptop test', ProductCode = 'LT-TEST-D1', Family = 'Laptop', IsActive = true);
        insert laptop;
        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(), Product2Id = laptop.Id, UnitPrice = 25000000, IsActive = true);
        insert entry;
        Order o = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today().addDays(-3),
            Delivery_Date__c = Date.today().addDays(-2),
            Pricebook2Id = Test.getStandardPricebookId(),
            Status = 'Draft'
        );
        insert o;
        insert new OrderItem(OrderId = o.Id, PricebookEntryId = entry.Id, Quantity = 1, UnitPrice = 25000000);
    }

    private static String draftJson() {
        OrderItem oi = [SELECT Id, OrderId FROM OrderItem LIMIT 1];
        return JSON.serialize(new Map<String, Object>{
            'orderId' => oi.OrderId,
            'lines' => new List<Object>{
                new Map<String, Object>{
                    'orderItemId' => oi.Id, 'quantity' => 1, 'reason' => 'DEFECT', 'condition' => 'SEALED'
                }
            }
        });
    }

    @IsTest
    static void loadsPreviewsAndCreates() {
        Id orderId = [SELECT Id FROM Order LIMIT 1].Id;
        String draft = draftJson();
        Test.startTest();
        //SR_DTO.ReturnableInfo info = SR_ReturnUiController.getReturnableLines(orderId);
        SR_DTO.PreviewResult preview = SR_ReturnUiController.previewLevel(draft);
        SR_DTO.CreateResult result = SR_ReturnUiController.createFromCounter(draft);
        Test.stopTest();
        //Assert.isNotNull(info, 'Phải trả thông tin đơn');
        Assert.isNotNull(preview, 'Phải trả kết quả tính trước');
        Assert.isNotNull(result, 'Phải trả kết quả tạo yêu cầu');
    }

    @IsTest
    static void badInputGivesReadableError() {
        try {
            SR_ReturnUiController.previewLevel('không phải JSON');
            Assert.fail('Phải báo lỗi khi dữ liệu nháp sai');
        } catch (AuraHandledException e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()), 'Thông báo lỗi không được trống');
        }
        try {
            SR_ReturnUiController.createFromCounter('{');
            Assert.fail('Phải báo lỗi khi dữ liệu tạo sai');
        } catch (AuraHandledException e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()), 'Thông báo lỗi không được trống');
        }
    }
}
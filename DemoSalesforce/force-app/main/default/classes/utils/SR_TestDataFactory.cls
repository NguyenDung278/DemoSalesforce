@IsTest
public class SR_TestDataFactory {

    private static final String TEST_LAST_NAME =
        'SmartReturn Test';

    private static final String STORE_CODE =
        'HCM-012';

    private static final String CUSTOMER_PHONE =
        '0901234567';

    /*
     * Các permission set được gán nếu metadata đã tồn tại.
     * Factory vẫn tạo user nếu permission set chưa được deploy.
     */
    private static final Map<String, String>
        PERMISSION_BY_ALIAS = new Map<String, String>{
            'srstaff' => 'SR_STORE_EMPLOYEE',
            'srmgr' => 'SR_STORE_MANAGER',
            'srqlv' => 'SR_REGIONAL_MANAGER',
            'sracct' => 'SR_ACCOUNTING',
            'srcskh' => 'SR_CUSTOMER_SERVICE'
        };

    private static final Map<String, Decimal>
        PRICE_BY_SKU = new Map<String, Decimal>{
            'PH-X' => 15000000,
            'LT-Y' => 25000000,
            'AF-PH-5L' => 2490000,
            'AC-CBL' => 250000,
            'TC-VT-100K' => 100000,
            'SW-OFFICE' => 2000000
        };

    private static final Map<String, Integer>
        DELIVERY_AGE_BY_SKU = new Map<String, Integer>{
            // Điện thoại: chính sách 7 ngày, đơn này đã 10 ngày.
            'PH-X' => 10,

            // Gia dụng: chính sách 30 ngày, đơn này mới 4 ngày.
            'AF-PH-5L' => 4,

            // Laptop giá trị lớn nhưng vẫn trong hạn.
            'LT-Y' => 2,

            'AC-CBL' => 2,
            'TC-VT-100K' => 2,
            'SW-OFFICE' => 2
        };

    /**
     * Gọi một lần trong @TestSetup.
     */
    public static void createStandardData() {
        Map<String, User> usersByAlias =
            createPersonaUsers();

        assignPermissionSets(usersByAlias);

        /*
         * Tách Setup Object DML và business object DML bằng runAs
         * để tránh MIXED_DML_OPERATION.
         */
        System.runAs(usersByAlias.get('srstaff')) {
            createBusinessData(usersByAlias);
        }
    }

    /**
     * Tìm test user theo Alias.
     */
    public static User userByAlias(String aliasValue) {
        if (String.isBlank(aliasValue)) {
            throw new IllegalArgumentException(
                'User alias is required.'
            );
        }

        List<User> users = [
            SELECT
                Id,
                Alias,
                Username,
                Store_Code__c
            FROM User
            WHERE Alias =:aliasValue
            AND LastName =:TEST_LAST_NAME
            AND IsActive = true
            LIMIT 1
        ];

        if (users.isEmpty()) {
            throw new IllegalArgumentException(
                'Không tìm thấy test user có alias: ' +
                aliasValue
            );
        }

        return users[0];
    }

    /**
     * Tạo Order có đúng một OrderItem theo SKU.
     *
     * PH-X -> giao 10 ngày trước.
     * AF-PH-5L -> giao 4 ngày trước.
     * LT-Y -> giao 2 ngày trước.
     */
    public static Order orderWithSku(String sku) {
        if (
            String.isBlank(sku) ||
            !PRICE_BY_SKU.containsKey(sku)
        ) {
            throw new IllegalArgumentException(
                'SKU test không được hỗ trợ: ' + sku
            );
        }

        Product2 product = [
            SELECT
                Id,
                ProductCode,
                Family
            FROM Product2
            WHERE ProductCode =:sku
            AND IsActive = true
            LIMIT 1
        ];

        Account customer = [
            SELECT Id, Phone
            FROM Account
            WHERE Phone =:CUSTOMER_PHONE
            LIMIT 1
        ];

        Store__c store = [
            SELECT Id, Store_Code__c
            FROM Store__c
            WHERE Store_Code__c =:STORE_CODE
            LIMIT 1
        ];

        Id standardPricebookId =
            Test.getStandardPricebookId();

        PricebookEntry pricebookEntry = [
            SELECT
                Id,
                UnitPrice
            FROM PricebookEntry
            WHERE Pricebook2Id =:standardPricebookId
            AND Product2Id =:product.Id
            AND IsActive = true
            LIMIT 1
        ];

        Integer deliveryAge =
            DELIVERY_AGE_BY_SKU.get(sku);

        Date deliveryDate =
            Date.today().addDays(-deliveryAge);

        Order orderRecord = new Order(
            AccountId = customer.Id,
            EffectiveDate = deliveryDate,
            Delivery_Date__c = deliveryDate,
            Status = 'Draft',
            Pricebook2Id = standardPricebookId,
            Store__c = store.Id,
            Payment_Method__c = 'CARD'
        );
        insert orderRecord;

        insert new OrderItem(
            OrderId = orderRecord.Id,
            PricebookEntryId = pricebookEntry.Id,
            Quantity = 1,
            UnitPrice = pricebookEntry.UnitPrice
        );

        return orderRecord;
    }

    /**
     * Tạo DTO cho yêu cầu tại quầy.
     *
     * Dùng JSON deserialize để factory không phụ thuộc vào tên
     * nested class của DTO dòng, miễn contract vẫn dùng:
     * orderItemId, quantity, reason, condition.
     */
    public static SR_DTO.CreateRequest counterRequest(
        Order orderRecord,
        String reason,
        String condition,
        Decimal quantity
    ) {
        if (orderRecord == null || orderRecord.Id == null) {
            throw new IllegalArgumentException(
                'Order đã insert là bắt buộc.'
            );
        }

        OrderItem orderItem = [
            SELECT Id
            FROM OrderItem
            WHERE OrderId =:orderRecord.Id
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        Map<String, Object> requestMap =
            new Map<String, Object>{
                'channel' => 'COUNTER',
                'orderId' => orderRecord.Id,
                'lines' => new List<Object>{
                    new Map<String, Object>{
                        'orderItemId' => orderItem.Id,
                        'quantity' => quantity,
                        'reason' => reason,
                        'condition' => condition
                    }
                }
            };

        return (SR_DTO.CreateRequest) JSON.deserialize(
            JSON.serialize(requestMap),
            SR_DTO.CreateRequest.class
        );
    }

    private static Map<String, User> createPersonaUsers() {
        Id runningUserId = UserInfo.getUserId();

        User runningUser = [
            SELECT
                ProfileId,
                TimeZoneSidKey,
                LocaleSidKey,
                EmailEncodingKey,
                LanguageLocaleKey
            FROM User
            WHERE Id =:runningUserId
        ];

        String uniqueSuffix =
            String.valueOf(DateTime.now().getTime());

        List<User> users = new List<User>{
            buildUser(
                runningUser,
                'srstaff',
                'NV cửa hàng',
                STORE_CODE,
                uniqueSuffix
            ),
            buildUser(
                runningUser,
                'srmgr',
                'Cửa hàng trưởng',
                STORE_CODE,
                uniqueSuffix
            ),
            buildUser(
                runningUser,
                'srqlv',
                'Quản lý vùng',
                null,
                uniqueSuffix
            ),
            buildUser(
                runningUser,
                'sracct',
                'Kế toán',
                null,
                uniqueSuffix
            ),
            buildUser(
                runningUser,
                'srcskh',
                'CSKH',
                null,
                uniqueSuffix
            )
        };

        insert users;

        Map<String, User> result =
            new Map<String, User>();

        for (User userRecord: users) {
            result.put(userRecord.Alias, userRecord);
        }

        return result;
    }

    private static User buildUser(
        User templateUser,
        String aliasValue,
        String firstName,
        String storeCode,
        String uniqueSuffix
    ) {
        String username =
            aliasValue +
            '.' +
            UserInfo.getOrganizationId() +
            '.' +
            uniqueSuffix +
            '@smartreturn.test';

        return new User(
            FirstName = firstName,
            LastName = TEST_LAST_NAME,
            Alias = aliasValue,
            Email = aliasValue + '@smartreturn.test',
            Username = username,
            CommunityNickname =
                aliasValue + uniqueSuffix,
            ProfileId = templateUser.ProfileId,
            TimeZoneSidKey =
                templateUser.TimeZoneSidKey,
            LocaleSidKey =
                templateUser.LocaleSidKey,
            EmailEncodingKey =
                templateUser.EmailEncodingKey,
            LanguageLocaleKey =
                templateUser.LanguageLocaleKey,
            Store_Code__c = storeCode
        );
    }

    private static void assignPermissionSets(
        Map<String, User> usersByAlias
    ) {
        Set<String> permissionNames =
            new Set<String>();

        permissionNames.addAll(
            PERMISSION_BY_ALIAS.values()
        );

        Map<String, PermissionSet>
            permissionByName =
                new Map<String, PermissionSet>();

        for (PermissionSet permissionRecord: [
            SELECT Id, Name
            FROM PermissionSet
            WHERE Name IN:permissionNames
        ]) {
            permissionByName.put(
                permissionRecord.Name,
                permissionRecord
            );
        }

        List<PermissionSetAssignment> assignments =
            new List<PermissionSetAssignment>();

        for (
            String aliasValue:
            PERMISSION_BY_ALIAS.keySet()
        ) {
            String permissionName =
                PERMISSION_BY_ALIAS.get(aliasValue);

            if (
                usersByAlias.containsKey(aliasValue) &&
                permissionByName.containsKey(permissionName)
            ) {
                assignments.add(
                    new PermissionSetAssignment(
                        AssigneeId =
                            usersByAlias.get(aliasValue).Id,
                        PermissionSetId =
                            permissionByName
                                .get(permissionName)
                                .Id
                    )
                );
            }
        }

        if (!assignments.isEmpty()) {
            /*
             * false: một permission set không tương thích license
             * không chặn toàn bộ factory.
             */
            Database.insert(assignments, false);
        }
    }

    private static void createBusinessData(
        Map<String, User> usersByAlias
    ) {
        Store__c storeRecord = new Store__c(
            Name = 'SmartReturn HCM 012',
            Store_Code__c = STORE_CODE,
            Region__c = 'SOUTH',
            Store_Manager__c =
                usersByAlias.get('srmgr').Id,
            Regional_Manager__c =
                usersByAlias.get('srqlv').Id
        );
        insert storeRecord;

        Account customer = new Account(
            Name = 'Khách hàng SmartReturn',
            Phone = CUSTOMER_PHONE,
            Risk_Flag__c = false
        );
        insert customer;

        List<Product2> products =
            new List<Product2>{
                product(
                    'Điện thoại PH-X',
                    'PH-X',
                    'Điện thoại'
                ),
                product(
                    'Laptop LT-Y',
                    'LT-Y',
                    'Laptop'
                ),
                product(
                    'Nồi chiên không dầu 5L',
                    'AF-PH-5L',
                    'Gia dụng'
                ),
                product(
                    'Cáp kết nối',
                    'AC-CBL',
                    'Phụ kiện'
                ),
                product(
                    'Thẻ cào 100K',
                    'TC-VT-100K',
                    'Thẻ cào'
                ),
                product(
                    'Phần mềm Office',
                    'SW-OFFICE',
                    'Phần mềm'
                )
            };
        insert products;

        Id standardPricebookId =
            Test.getStandardPricebookId();

        List<PricebookEntry> entries =
            new List<PricebookEntry>();

        for (Product2 productRecord: products) {
            entries.add(
                new PricebookEntry(
                    Pricebook2Id =
                        standardPricebookId,
                    Product2Id =
                        productRecord.Id,
                    UnitPrice =
                        PRICE_BY_SKU.get(
                            productRecord.ProductCode
                        ),
                    IsActive = true
                )
            );
        }

        insert entries;
    }

    private static Product2 product(
        String productName,
        String sku,
        String family
    ) {
        return new Product2(
            Name = productName,
            ProductCode = sku,
            Family = family,
            IsActive = true
        );
    }
}
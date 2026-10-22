public with sharing class SR_Config {
    private static final String DEFAULT_SETTING = 'Default';
    private static final String CONFIGURATION_ERROR = 'CONFIGURATION_ERROR';
    private static final String KEY_SEPARATOR = '|';

    public interface Provider {
        SR_Setting__mdt getSetting(String developerName);
        Map<String, SR_Category_Policy__mdt> getCategoryPolicies();
        Map<String, SR_Refund_Rate__mdt> getRefundRates();
    }

    private class MetadataProvider implements Provider {
        public SR_Setting__mdt getSetting(String developerName) {
            return SR_Setting__mdt.getInstance(developerName);
        }

        public Map<String, SR_Category_Policy__mdt> getCategoryPolicies() {
            return SR_Category_Policy__mdt.getAll();
        }

        public Map<String, SR_Refund_Rate__mdt> getRefundRates() {
            return SR_Refund_Rate__mdt.getAll();
        }
    }

    public class CategoryPolicy {
        public String productFamily { get; private set; }
        public Boolean isReturnable { get; private set; }
        public Integer returnWindowDays { get; private set; }

        private CategoryPolicy(SR_Category_Policy__mdt source) {
            productFamily = source.Product_Family__c;
            isReturnable = source.Is_Returnable__c;
            returnWindowDays = source.Return_Window_Days__c == null
                ? null
                : source.Return_Window_Days__c.intValue();
        }
    }

    @TestVisible
    private static Provider provider = new MetadataProvider();
    private static SR_Setting__mdt settingCache;
    private static Map<String, CategoryPolicy> categoryCache;
    private static Map<String, Decimal> refundRateCache;

    public static Decimal autoApprovalThreshold() {
        return setting().Auto_Approval_Threshold__c;
    }

    public static Decimal storeManagerMaxThreshold() {
        return setting().Store_Manager_Max_Threshold__c;
    }

    public static Integer riskRequestCount() {
        return setting().Risk_Request_Count__c.intValue();
    }

    public static Decimal riskTotalAmount() {
        return setting().Risk_Total_Amount__c;
    }

    public static Integer riskWindowDays() {
        return setting().Risk_Window_Days__c.intValue();
    }

    public static Integer approvalSlaHours() {
        return setting().Approval_SLA_Hours__c.intValue();
    }

    public static Integer goodsDueDays() {
        return setting().Goods_Due_Days__c.intValue();
    }

    public static Integer payHubTimeoutSeconds() {
        return setting().PayHub_Timeout_Seconds__c.intValue();
    }

    public static Integer payHubMaxTotalAttempts() {
        return setting().PayHub_Max_Total_Attempts__c.intValue();
    }

    public static Integer payHubRetryIntervalMinutes() {
        return setting().PayHub_Retry_Interval_Minutes__c.intValue();
    }

    public static Boolean isAutoApprovalEnabled() {
        return setting().Enable_Auto_Approval__c;
    }

    public static Boolean isPayHubEnabled() {
        return setting().Enable_PayHub__c;
    }

    public static Boolean isPosAppNotificationEnabled() {
        return setting().Enable_POS_App_Notification__c;
    }

    public static CategoryPolicy categoryPolicy(String productFamily) {
        if (String.isBlank(productFamily)) {
            throw configurationError('Product family is required.');
        }
        loadCategoryPolicies();
        CategoryPolicy result = categoryCache.get(normalize(productFamily));
        if (result == null) {
            throw configurationError('No active category policy for: ' + productFamily);
        }
        return result;
    }

    public static Decimal refundRate(String reason, String condition) {
        if (String.isBlank(reason) || String.isBlank(condition)) {
            throw configurationError('Reason and condition are required.');
        }
        loadRefundRates();
        String key = compositeKey(reason, condition);
        if (!refundRateCache.containsKey(key)) {
            throw configurationError(
                'No active refund rate for reason/condition: ' + reason + '/' + condition
            );
        }
        return refundRateCache.get(key);
    }

    @TestVisible
    static void setProvider(Provider customProvider) {
        if (customProvider == null) {
            throw configurationError('Config provider cannot be null.');
        }
        provider = customProvider;
        clearCache();
    }

    @TestVisible
    static void resetProvider() {
        provider = new MetadataProvider();
        clearCache();
    }

    @TestVisible
    static void clearCache() {
        settingCache = null;
        categoryCache = null;
        refundRateCache = null;
    }

    public static SR_Setting__mdt setting() {
        if (settingCache == null) {
            settingCache = provider.getSetting(DEFAULT_SETTING);
            validateSetting(settingCache);
        }
        return settingCache;
    }

    private static void validateSetting(SR_Setting__mdt value) {
        if (value == null) {
            throw configurationError('Missing SR_Setting__mdt.Default.');
        }

        Map<String, Decimal> requiredNumbers = new Map<String, Decimal>{
            'Auto_Approval_Threshold__c' => value.Auto_Approval_Threshold__c,
            'Store_Manager_Max_Threshold__c' => value.Store_Manager_Max_Threshold__c,
            'Risk_Request_Count__c' => value.Risk_Request_Count__c,
            'Risk_Total_Amount__c' => value.Risk_Total_Amount__c,
            'Risk_Window_Days__c' => value.Risk_Window_Days__c,
            'Approval_SLA_Hours__c' => value.Approval_SLA_Hours__c,
            'Goods_Due_Days__c' => value.Goods_Due_Days__c,
            'PayHub_Timeout_Seconds__c' => value.PayHub_Timeout_Seconds__c,
            'PayHub_Max_Total_Attempts__c' => value.PayHub_Max_Total_Attempts__c,
            'PayHub_Retry_Interval_Minutes__c' => value.PayHub_Retry_Interval_Minutes__c
        };

        for (String fieldName : requiredNumbers.keySet()) {
            if (requiredNumbers.get(fieldName) == null) {
                throw configurationError('Missing required setting: ' + fieldName);
            }
        }
    }

    private static void loadCategoryPolicies() {
        if (categoryCache != null) {
            return;
        }
        categoryCache = new Map<String, CategoryPolicy>();
        for (SR_Category_Policy__mdt item : provider.getCategoryPolicies().values()) {
            if (item.Active__c != true || String.isBlank(item.Product_Family__c)) {
                continue;
            }
            if (item.Is_Returnable__c == true && item.Return_Window_Days__c == null) {
                throw configurationError(
                    'Return window is missing for category: ' + item.Product_Family__c
                );
            }
            categoryCache.put(normalize(item.Product_Family__c), new CategoryPolicy(item));
        }
    }

    private static void loadRefundRates() {
        if (refundRateCache != null) {
            return;
        }
        refundRateCache = new Map<String, Decimal>();
        for (SR_Refund_Rate__mdt item : provider.getRefundRates().values()) {
            if (item.Active__c != true) {
                continue;
            }
            if (
                String.isBlank(item.Reason__c) ||
                String.isBlank(item.Condition__c) ||
                item.Refund_Rate__c == null
            ) {
                throw configurationError('Active refund-rate metadata is incomplete.');
            }
            refundRateCache.put(
                compositeKey(item.Reason__c, item.Condition__c),
                item.Refund_Rate__c
            );
        }
    }

    private static String compositeKey(String firstValue, String secondValue) {
        return normalize(firstValue) + KEY_SEPARATOR + normalize(secondValue);
    }

    private static String normalize(String value) {
        return value == null ? null : value.trim().toUpperCase();
    }

    private static SR_ConfigurationException configurationError(String message) {
        return new SR_ConfigurationException(CONFIGURATION_ERROR, message);
    }

    @TestVisible
    private static Map<String, Decimal> refundRateByKey;

    /**
     * Trả về tỷ lệ ở dạng thập phân:
     * 100% -> 1
     * 80% -> 0.8
     * 0% -> 0
     */
    public static Decimal getRefundRate(
        String reason,
        String condition
    ) {
        if (String.isBlank(reason) || String.isBlank(condition)) {
            throw new IllegalArgumentException(
                'Reason và condition không được để trống.'
            );
        }

        loadRefundRates();

        String key = buildRefundRateKey(reason, condition);

        if (!refundRateByKey.containsKey(key)) {
            throw new SR_ConfigurationException(
                'Không tìm thấy cấu hình refund rate cho '
                + 'reason='
                + reason
                + ', condition='
                + condition
            );
        }

        return refundRateByKey.get(key);
    }

    private static void loadRefundRates() {
        if (refundRateByKey!= null) {
            return;
        }

        refundRateByKey = new Map<String, Decimal>();

        for (
            SR_Refund_Rate__mdt metadataRecord:
            SR_Refund_Rate__mdt.getAll().values()
        ) {
            if (
                metadataRecord.Active__c!= true
                || String.isBlank(metadataRecord.Reason__c)
                || String.isBlank(metadataRecord.Condition__c)
                || metadataRecord.Refund_Rate__c == null
            ) {
                continue;
            }

            String key = buildRefundRateKey(
                metadataRecord.Reason__c,
                metadataRecord.Condition__c
            );

            /*
             * Salesforce Percent field trả về:
             * 100% = 100
             * 80% = 80
             *
             * Chuyển sang dạng decimal để tính:
             * 100 -> 1
             * 80 -> 0.8
             */
            refundRateByKey.put(
                key,
                metadataRecord.Refund_Rate__c / 100
            );
        }
    }

    private static String buildRefundRateKey(
        String reason,
        String condition
    ) {
        return reason.trim().toUpperCase()
            + '|'
            + condition.trim().toUpperCase();
    }

    @TestVisible
    private static void resetCache() {
        refundRateByKey = null;
    }
}

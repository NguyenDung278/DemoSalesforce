/**
 * Selector cho Store__c. "inherited sharing": chạy theo sharing của class gọi.
 */
public inherited sharing class SR_StoreSelector {

    // Cửa hàng mà người dùng là CHT hoặc QLV
    public static List<Store__c> selectManagedBy(Id userId) {
        return [
            SELECT Id, Name, Store_Code__c FROM Store__c
            WHERE Store_Manager__c = :userId OR Regional_Manager__c = :userId
            WITH USER_MODE
            ORDER BY Store_Code__c
        ];
    }
}

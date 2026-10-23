public with sharing class SR_OrderSelector {
    public static Map<Id, Order> selectByIds(Set<Id> orderIds, Boolean forUpdate) {
        if (orderIds == null || orderIds.isEmpty()) return new Map<Id, Order>();
        String soql = baseQuery() + ' WHERE Id IN :orderIds' + (forUpdate ? ' FOR UPDATE' : '');
        return new Map<Id, Order>((List<Order>) Database.query(soql));
    }

    public static Map<String, Order> selectByNumbers(Set<String> orderNumbers, Boolean forUpdate) {
        Map<String, Order> result = new Map<String, Order>();
        if (orderNumbers == null || orderNumbers.isEmpty()) return result;
        String soql = baseQuery() + ' WHERE OrderNumber IN :orderNumbers' + (forUpdate ? ' FOR UPDATE' : '');
        for (Order row : (List<Order>) Database.query(soql)) result.put(row.OrderNumber, row);
        return result;
    }

    private static String baseQuery() {
        return 'SELECT Id, OrderNumber, AccountId, Account.Name, Account.Phone, Account.Risk_Flag__c, ' +
            'EffectiveDate, Delivery_Date__c, Store__c, Store__r.Name, Store__r.Store_Code__c, ' +
            'Store__r.Store_Manager__c, Store__r.Regional_Manager__c, ' +
            '(SELECT Id, Product2Id, Product2.Name, Product2.ProductCode, Product2.Family, Quantity, UnitPrice FROM OrderItems) ' +
            'FROM Order';
    }
}

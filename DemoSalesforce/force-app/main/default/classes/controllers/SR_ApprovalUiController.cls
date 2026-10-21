/**
 * Controller cho màn hình duyệt của CHT/QLV (D.2, FR-08, FR-09).
 * Truy vấn ở USER_MODE: chỉ thấy yêu cầu và field người dùng được phép xem (BR-16).
 * Owner: Dev C (hàm duyệt thật nằm ở SR_ApprovalService của Dev A)
 */
public with sharing class SR_ApprovalUiController {

    public static final Integer PAGE_SIZE = 50;

    public class Filters {
        public String status;
        public Id storeId;
        public Date fromDate;
        public Date toDate;
        public Boolean onlyMine;
        public String sortBy;      // AMOUNT | WAIT
        public String sortDir;     // asc | desc
        public Integer pageNumber;
    }

    public class Row {
        @AuraEnabled public Id id;
        @AuraEnabled public String requestNumber;
        @AuraEnabled public String customerName;
        @AuraEnabled public String storeName;
        @AuraEnabled public String channel;
        @AuraEnabled public Decimal estimatedRefund;
        @AuraEnabled public String approvalLevel;
        @AuraEnabled public String approverName;
        @AuraEnabled public Decimal waitingHours;
        @AuraEnabled public Boolean risky;
        @AuraEnabled public Boolean overdue;
        @AuraEnabled public Datetime lastModified;
    }

    public class PageResult {
        @AuraEnabled public List<Row> rows = new List<Row>();
        @AuraEnabled public Integer total = 0;
        @AuraEnabled public Integer pageSize = PAGE_SIZE;
    }

    public class StoreOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String storeCode;
    }

    // Cửa hàng mà người dùng là CHT hoặc QLV (bộ lọc + lọc thông báo realtime)
    @AuraEnabled(cacheable=true)
    public static List<StoreOption> getMyStores() {
        try {
            Id me = UserInfo.getUserId();
            List<StoreOption> result = new List<StoreOption>();
            for (Store__c st : [
                SELECT Id, Name, Store_Code__c FROM Store__c
                WHERE Store_Manager__c = :me OR Regional_Manager__c = :me
                ORDER BY Store_Code__c
            ]) {
                StoreOption o = new StoreOption();
                o.label = st.Store_Code__c + ' – ' + st.Name;
                o.value = st.Id;
                o.storeCode = st.Store_Code__c;
                result.add(o);
            }
            return result;
        } catch (Exception e) {
            throw SR_Util.auraError(e);
        }
    }

    @AuraEnabled
    public static PageResult getQueue(String filtersJson) {
        try {
            Filters f = String.isBlank(filtersJson) ? new Filters() : (Filters) JSON.deserialize(filtersJson, Filters.class);
            String status = String.isBlank(f.status) ? 'PENDING_APPROVAL' : f.status;
            Date fromDay = (f.fromDate == null) ? Date.today().addDays(-30) : f.fromDate;
            Date toDay = (f.toDate == null) ? Date.today() : f.toDate;

            Map<String, Object> binds = new Map<String, Object>{
                'status' => status,
                'fromDt' => Datetime.newInstance(fromDay, Time.newInstance(0, 0, 0, 0)),
                'toDt' => Datetime.newInstance(toDay.addDays(1), Time.newInstance(0, 0, 0, 0))
            };
            String whereClause = ' WHERE Status__c = :status AND CreatedDate >= :fromDt AND CreatedDate < :toDt';
            if (f.storeId != null) {
                whereClause += ' AND Store__c = :storeId';
                binds.put('storeId', f.storeId);
            }
            if (f.onlyMine == true) {
                whereClause += ' AND Assigned_Approver__c = :me';
                binds.put('me', UserInfo.getUserId());
            }
            // Mặc định: chờ lâu nhất lên đầu
            String orderField = (f.sortBy == 'AMOUNT') ? 'Estimated_Refund__c' : 'Submitted_At__c';
            String direction = (f.sortDir == 'desc') ? 'DESC' : 'ASC';
            Integer pageNumber = (f.pageNumber == null || f.pageNumber < 1) ? 1 : f.pageNumber;
            Integer offsetRows = Math.min((pageNumber - 1) * PAGE_SIZE, 2000);

            String soql = 'SELECT Id, Name, Account__r.Name, Account__r.Risk_Flag__c, Store__r.Name, Channel__c, ' +
                'Estimated_Refund__c, Approval_Level__c, Assigned_Approver__r.Name, Submitted_At__c, ' +
                'Approval_Due_At__c, LastModifiedDate FROM Return_Request__c' + whereClause +
                ' ORDER BY ' + orderField + ' ' + direction + ' NULLS LAST' +
                ' LIMIT ' + PAGE_SIZE + ' OFFSET ' + offsetRows;

            PageResult page = new PageResult();
            page.total = Database.countQueryWithBinds(
                'SELECT COUNT() FROM Return_Request__c' + whereClause, binds, AccessLevel.USER_MODE);
            Datetime now = System.now();
            for (Return_Request__c r : (List<Return_Request__c>) Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE)) {
                Row row = new Row();
                row.id = r.Id;
                row.requestNumber = r.Name;
                row.customerName = r.Account__r?.Name;
                row.storeName = r.Store__r?.Name;
                row.channel = SR_Util.picklistLabel(Return_Request__c.Channel__c, r.Channel__c);
                row.estimatedRefund = r.Estimated_Refund__c;
                row.approvalLevel = r.Approval_Level__c;
                row.approverName = r.Assigned_Approver__r?.Name;
                row.waitingHours = (r.Submitted_At__c == null) ? 0 :
                    Decimal.valueOf(now.getTime() - r.Submitted_At__c.getTime()).divide(3600000, 1);
                row.risky = (r.Account__r?.Risk_Flag__c == true);
                row.overdue = (status == 'PENDING_APPROVAL' && r.Approval_Due_At__c != null && r.Approval_Due_At__c < now);
                row.lastModified = r.LastModifiedDate;
                page.rows.add(row);
            }
            return page;
        } catch (Exception e) {
            throw SR_Util.auraError(e);
        }
    }

    // itemsJson: [ { "requestId": "...", "lastModified": "2026-10-19T02:03:04.000Z" } ]
    @AuraEnabled
    public static SR_DTO.DecisionResult decide(String itemsJson, Boolean approve, String reason) {
        try {
            List<SR_DTO.DecisionItem> items =
                (List<SR_DTO.DecisionItem>) JSON.deserialize(itemsJson, List<SR_DTO.DecisionItem>.class);
            return SR_ApprovalService.decide(items, approve, reason);
        } catch (Exception e) {
            throw SR_Util.auraError(e);
        }
    }
}

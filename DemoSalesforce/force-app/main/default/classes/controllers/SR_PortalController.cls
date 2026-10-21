/**
 * Customer Portal (D.4, FR-05, BR-17, NFR-07).
 *  - Khách vãng lai: tra bằng mã yêu cầu + 4 số cuối SĐT. Guest không có quyền trên object,
 *    nên phần này chạy without sharing và CHỈ trả trạng thái, lịch sử, tên + số lượng sản phẩm.
 *  - Khách đăng nhập: thấy yêu cầu của mình qua Sharing Set (class con "with sharing").
 * Owner: Dev C
 */
public without sharing class SR_PortalController {

    public class HistoryItem {
        @AuraEnabled public String key;
        @AuraEnabled public String statusLabel;
        @AuraEnabled public String changedAt;
    }

    public class ProductItem {
        @AuraEnabled public String key;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal quantity;
    }

    public class LookupResult {
        @AuraEnabled public Boolean found = false;
        @AuraEnabled public String message;
        @AuraEnabled public String requestNumber;
        @AuraEnabled public String statusLabel;
        @AuraEnabled public List<HistoryItem> history = new List<HistoryItem>();
        @AuraEnabled public List<ProductItem> products = new List<ProductItem>();
    }

    public class MyRequest {
        @AuraEnabled public Id id;
        @AuraEnabled public String requestNumber;
        @AuraEnabled public String createdDate;
        @AuraEnabled public String statusLabel;
        @AuraEnabled public Decimal amount;
    }

    // ---------- Khách vãng lai ----------
    // Không throw lỗi khi nhập sai: throw sẽ rollback cả bản ghi đếm số lần sai.
    @AuraEnabled
    public static LookupResult lookup(String requestNumber, String phoneLast4) {
        LookupResult res = new LookupResult();
        try {
            String code = (requestNumber == null) ? '' : requestNumber.trim().toUpperCase();
            String last4 = (phoneLast4 == null) ? '' : phoneLast4.trim();
            if (isLocked(code)) {
                res.message = System.Label.SR_MSG_41;              // sai 5 lần trong 15 phút
                return res;
            }
            List<Return_Request__c> found = [
                SELECT Id, Account__r.Phone FROM Return_Request__c WHERE Name = :code LIMIT 1
            ];
            Boolean ok = !found.isEmpty() && last4.length() == 4
                && digitsOnly(found[0].Account__r?.Phone).endsWith(last4);
            if (!ok) {
                insert new SR_Lookup_Attempt__c(Key__c = code.abbreviate(80));
                res.message = System.Label.SR_MSG_40;              // cùng một câu cho mọi trường hợp sai
                return res;
            }
            fillDetail(res, found[0].Id);
            return res;
        } catch (Exception e) {
            throw SR_Util.auraError(e);
        }
    }

    // ---------- Khách đăng nhập ----------
    @AuraEnabled
    public static List<MyRequest> getMyRequests(Integer pageSize, Integer pageNumber) {
        try {
            return new MyQueries().myRequests(pageSize, pageNumber);
        } catch (Exception e) {
            throw SR_Util.auraError(e);
        }
    }

    @AuraEnabled
    public static LookupResult getMyRequestDetail(Id requestId) {
        try {
            LookupResult res = new LookupResult();
            if (!new MyQueries().canSee(requestId)) {
                res.message = System.Label.SR_MSG_40;
                return res;
            }
            fillDetail(res, requestId);
            return res;
        } catch (Exception e) {
            throw SR_Util.auraError(e);
        }
    }

    // ---------- Hàm phụ ----------
    // Chỉ lấy trạng thái, lịch sử, tên + số lượng sản phẩm. KHÔNG lấy số tiền, tên, SĐT (BR-17).
    private static void fillDetail(LookupResult res, Id requestId) {
        Return_Request__c r = [
            SELECT Id, Name, Status__c,
                   (SELECT Id, Product__r.Name, Quantity__c FROM Lines__r ORDER BY Name),
                   (SELECT Id, To_Status__c, Changed_At__c FROM Histories__r ORDER BY Changed_At__c, Name)
            FROM Return_Request__c WHERE Id = :requestId
        ];
        res.found = true;
        res.requestNumber = r.Name;
        res.statusLabel = SR_StatusMachine.labelOf(r.Status__c);
        for (Return_Request_History__c h : r.Histories__r) {
            HistoryItem hi = new HistoryItem();
            hi.key = h.Id;
            hi.statusLabel = SR_StatusMachine.labelOf(h.To_Status__c);
            hi.changedAt = h.Changed_At__c.format('dd/MM/yyyy HH:mm', 'Asia/Ho_Chi_Minh');
            res.history.add(hi);
        }
        for (Return_Request_Line__c l : r.Lines__r) {
            ProductItem pi = new ProductItem();
            pi.key = l.Id;
            pi.name = l.Product__r?.Name;
            pi.quantity = l.Quantity__c;
            res.products.add(pi);
        }
    }

    private static Boolean isLocked(String code) {
        SR_Setting__mdt s = SR_Config.setting();
        Datetime since = System.now().addMinutes(-s.Portal_Lock_Minutes__c.intValue());
        Integer failed = [
            SELECT COUNT() FROM SR_Lookup_Attempt__c WHERE Key__c = :code AND CreatedDate >= :since
        ];
        return failed >= s.Portal_Max_Failed__c;
    }

    private static String digitsOnly(String s) {
        return (s == null) ? '' : s.replaceAll('[^0-9]', '');
    }

    // Truy vấn theo quyền của khách đăng nhập (Sharing Set: Account của User = Account__c của yêu cầu)
    private with sharing class MyQueries {

        public List<MyRequest> myRequests(Integer pageSize, Integer pageNumber) {
            Integer size = (pageSize == null || pageSize < 1) ? 10 : Math.min(pageSize, 50);
            Integer offsetRows = ((pageNumber == null || pageNumber < 1) ? 0 : pageNumber - 1) * size;
            List<MyRequest> result = new List<MyRequest>();
            for (Return_Request__c r : [
                SELECT Id, Name, CreatedDate, Status__c, Estimated_Refund__c, Actual_Refund__c
                FROM Return_Request__c
                ORDER BY CreatedDate DESC
                LIMIT :size OFFSET :offsetRows
            ]) {
                MyRequest m = new MyRequest();
                m.id = r.Id;
                m.requestNumber = r.Name;
                m.createdDate = r.CreatedDate.format('dd/MM/yyyy', 'Asia/Ho_Chi_Minh');
                m.statusLabel = SR_StatusMachine.labelOf(r.Status__c);
                m.amount = (r.Actual_Refund__c != null && r.Actual_Refund__c > 0) ? r.Actual_Refund__c : r.Estimated_Refund__c;
                result.add(m);
            }
            return result;
        }

        public Boolean canSee(Id requestId) {
            return ![SELECT Id FROM Return_Request__c WHERE Id = :requestId].isEmpty();
        }
    }
}

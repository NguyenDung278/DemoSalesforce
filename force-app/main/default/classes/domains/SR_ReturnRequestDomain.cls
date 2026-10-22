/**
 * Quy tắc trên bản ghi Return_Request__c cho màn hình duyệt (D.2) và Customer Portal (D.4).
 * Không truy vấn, không ghi dữ liệu: nhận bản ghi đã query sẵn, nên test được mà không cần tạo dữ liệu.
 */
public inherited sharing class SR_ReturnRequestDomain {

    public static final String STATUS_PENDING_APPROVAL = 'PENDING_APPROVAL';

    // D.4: 4 số cuối SĐT của khách, bỏ ký tự không phải số. Cần query Account__r.Phone.
    public static Boolean matchesPhoneLast4(Return_Request__c r, String last4) {
        return last4 != null && last4.length() == 4
            && digitsOnly(r.Account__r?.Phone).endsWith(last4);
    }

    // Portal: tiền thực hoàn nếu đã có, chưa có thì tiền dự kiến
    public static Decimal refundAmount(Return_Request__c r) {
        return (r.Actual_Refund__c != null && r.Actual_Refund__c > 0) ? r.Actual_Refund__c : r.Estimated_Refund__c;
    }

    // D.2: số giờ đã chờ duyệt, lấy 1 chữ số thập phân
    public static Decimal waitingHours(Return_Request__c r, Datetime now) {
        return (r.Submitted_At__c == null) ? 0 :
            Decimal.valueOf(now.getTime() - r.Submitted_At__c.getTime()).divide(3600000, 1);
    }

    // D.2: đang chờ duyệt mà đã quá hạn duyệt thì tô đỏ
    public static Boolean isApprovalOverdue(Return_Request__c r, Datetime now) {
        return r.Status__c == STATUS_PENDING_APPROVAL && r.Approval_Due_At__c != null && r.Approval_Due_At__c < now;
    }

    // BR-09: khách đang bị gắn cờ rủi ro
    public static Boolean isRiskyCustomer(Return_Request__c r) {
        return r.Account__r?.Risk_Flag__c == true;
    }

    private static String digitsOnly(String s) {
        return (s == null) ? '' : s.replaceAll('[^0-9]', '');
    }
}

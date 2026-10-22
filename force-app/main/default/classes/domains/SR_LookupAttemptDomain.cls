/**
 * Quy tắc khóa tra cứu trên Portal (D.4): sai Portal_Max_Failed__c lần trong
 * Portal_Lock_Minutes__c phút gần nhất thì khóa mã yêu cầu đó.
 * Không truy vấn, không ghi dữ liệu.
 */
public inherited sharing class SR_LookupAttemptDomain {

    // Mốc bắt đầu đếm số lần sai
    public static Datetime lockWindowStart(SR_Setting__mdt s, Datetime now) {
        return now.addMinutes(-s.Portal_Lock_Minutes__c.intValue());
    }

    public static Boolean isLocked(Integer failedInWindow, SR_Setting__mdt s) {
        return failedInWindow >= s.Portal_Max_Failed__c;
    }

    // Key__c dài tối đa 80 ký tự
    public static SR_Lookup_Attempt__c newFailedAttempt(String key) {
        return new SR_Lookup_Attempt__c(Key__c = key.abbreviate(80));
    }
}

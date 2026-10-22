/**
 * Controller cho màn hình duyệt của CHT/QLV (D.2, FR-08, FR-09).
 * Chỉ nhận/trả dữ liệu: hàng chờ ở SR_ApprovalQueueService (truy vấn USER_MODE, BR-16).
 * Owner: Dev C (hàm duyệt thật nằm ở SR_ApprovalService của Dev A)
 */
public with sharing class SR_ApprovalUiController {

    // Cửa hàng mà người dùng là CHT hoặc QLV (bộ lọc + lọc thông báo realtime)
    @AuraEnabled(cacheable=true)
    public static List<SR_ApprovalQueueService.StoreOption> getMyStores() {
        try {
            return SR_ApprovalQueueService.getMyStores();
        } catch (Exception e) {
            //throw SR_Util.auraError(e);
            throw e;
        }
    }

    // filtersJson: các field của SR_ApprovalQueueService.Filters; để trống thì dùng bộ lọc mặc định
    @AuraEnabled
    public static SR_ApprovalQueueService.PageResult getQueue(String filtersJson) {
        try {
            SR_ApprovalQueueService.Filters f = String.isBlank(filtersJson)
                ? new SR_ApprovalQueueService.Filters()
                : (SR_ApprovalQueueService.Filters) JSON.deserialize(filtersJson, SR_ApprovalQueueService.Filters.class);
            return SR_ApprovalQueueService.getQueue(f);
        } catch (Exception e) {
            //throw SR_Util.auraError(e);
            throw e;
        }
    }

    // itemsJson: [ { "requestId": "...", "lastModified": "2026-10-19T02:03:04.000Z" } ]
    // @AuraEnabled
    // public static SR_DTO.DecisionResult decide(String itemsJson, Boolean approve, String reason) {
    //     try {
    //         List<SR_DTO.DecisionItem> items =
    //             (List<SR_DTO.DecisionItem>) JSON.deserialize(itemsJson, List<SR_DTO.DecisionItem>.class);
    //         return SR_ApprovalService.decide(items, approve, reason);
    //     } catch (Exception e) {
    //         //throw SR_Util.auraError(e);
    //         throw e;
    //     }
    // }
}

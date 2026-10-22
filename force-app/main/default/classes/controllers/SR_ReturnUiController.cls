/**
 * Controller cho màn hình tạo yêu cầu trả hàng tại quầy (D.1).
 * Chỉ nhận/trả dữ liệu. Kiểm tra điều kiện, tính tiền, định tuyến duyệt nằm ở service của Dũng.
 * Phần kiểm định (D.3) sẽ thêm vào class này ở task sau.
 */
public with sharing class SR_ReturnUiController {

    // D.1 bước 1–3: thông tin đơn và từng dòng sản phẩm, dòng nào bị khóa kèm lý do
    @AuraEnabled(cacheable=true)
    public static SR_DTO.ReturnableInfo getReturnableLines(Id orderId) {
        try {
            return SR_ReturnRequestService.getReturnableLines(orderId);
        } catch (Exception e) {
            //throw SR_Util.auraError(e);
            throw e;
        }
    }

    // D.1 bước 4: tính trước tiền từng dòng, tổng tiền và cấp duyệt – không ghi dữ liệu
    // draftJson: { "orderId": "...", "lines": [ { "orderItemId", "quantity", "reason", "condition" } ] }
    @AuraEnabled
    public static SR_DTO.PreviewResult previewLevel(String draftJson) {
        try {
            return SR_ApprovalService.previewLevel(toCounterRequest(draftJson));
        } catch (Exception e) {
            //throw SR_Util.auraError(e);
            throw e;
        }
    }

    // D.1 bước 5: tạo yêu cầu tại quầy, cùng JSON với previewLevel
    @AuraEnabled
    public static SR_DTO.CreateResult createFromCounter(String draftJson) {
        try {
            return SR_ReturnRequestService.createRequests(
                new List<SR_DTO.CreateRequest>{ toCounterRequest(draftJson) })[0];
        } catch (Exception e) {
            //throw SR_Util.auraError(e);
            throw e;
        }
    }

    // Màn hình D.1 luôn là kênh Tại quầy; cửa hàng xử lý do service lấy theo người tạo
    private static SR_DTO.CreateRequest toCounterRequest(String draftJson) {
        SR_DTO.CreateRequest req = (SR_DTO.CreateRequest) JSON.deserialize(draftJson, SR_DTO.CreateRequest.class);
        req.channel = SR_ReturnRequestService.CH_COUNTER;
        return req;
    }
}
public with sharing class SR_ApprovalService {
    public static SR_ApprovalPreviewResultDTO previewLevel(SR_ApprovalPreviewDTO input) {
        SR_ApprovalPreviewResultDTO out = new SR_ApprovalPreviewResultDTO();
        out.success = true;
        Decimal amount = input == null || input.estimatedRefund == null ? 0 : input.estimatedRefund;
        Boolean risk = input != null && input.riskFlag == true;
        Store__c store = input != null && input.storeId != null
            ? SR_StoreSelector.selectByIds(new Set<Id>{input.storeId}).get(input.storeId)
            : null;

        if (risk || amount > SR_Config.storeManagerMaxThreshold()) {
            out.approvalLevel = 'QLV';
            out.assignedApproverId = store == null ? null : store.Regional_Manager__c;
            out.targetStatus = 'PENDING_APPROVAL';
        } else if (SR_Config.enableAutoApproval() && amount <= SR_Config.autoApprovalThreshold()) {
            out.approvalLevel = 'AUTO';
            out.targetStatus = input != null && input.channel == 'APP' ? 'AWAITING_GOODS' : 'INSPECTING';
        } else {
            out.approvalLevel = 'CHT';
            out.assignedApproverId = store == null ? null : store.Store_Manager__c;
            out.targetStatus = 'PENDING_APPROVAL';
        }
        return out;
    }
}

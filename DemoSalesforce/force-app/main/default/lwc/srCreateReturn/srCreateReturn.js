import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getReturnableLines from '@salesforce/apex/SR_ReturnUiController.getReturnableLines';
import createFromCounter from '@salesforce/apex/SR_ReturnUiController.createFromCounter';
import MSG_01 from '@salesforce/label/c.SR_MSG_01';
import MSG_04 from '@salesforce/label/c.SR_MSG_04';
import MSG_05 from '@salesforce/label/c.SR_MSG_05';
import MSG_06 from '@salesforce/label/c.SR_MSG_06';
import {
    REASON_OPTIONS,
    CONDITION_OPTIONS,
    labelOf,
    formatLabel,
    formatDate,
    vnd,
    refundAmount,
    reduceErrors
} from 'c/srUtils';

const LEVEL_LABELS = {
    AUTO: 'Tự động duyệt',
    CHT: 'Cửa hàng trưởng duyệt',
    QLV: 'Quản lý vùng duyệt'
};

// D.1 – Tạo yêu cầu trả hàng tại quầy (FR-01, FR-02). Quick Action trên Order. Owner: Dev C
export default class SrCreateReturn extends NavigationMixin(LightningElement) {
    @api recordId; // Id đơn hàng
    info;
    lines = [];
    errorMessage;
    resultErrors = [];
    isSaving = false;
    reasonOptions = REASON_OPTIONS;
    conditionOptions = CONDITION_OPTIONS;

    // recordId của Quick Action có thể đến muộn, nên dùng @wire với '$recordId'
    @wire(getReturnableLines, { orderId: '$recordId' })
    wiredInfo({ data, error }) {
        if (data) {
            this.info = data;
            this.lines = data.lines.map((l) => ({
                ...l,
                key: l.orderItemId,
                disabled: !l.returnable,
                qty: 0,
                reason: null,
                condition: null,
                refund: 0,
                refundText: '0',
                warning: null,
                deadlineText: formatDate(l.deadline),
                rowClass: l.returnable ? '' : 'slds-text-color_weak'
            }));
            this.errorMessage = undefined;
        } else if (error) {
            this.errorMessage = reduceErrors(error);
        }
    }

    get purchaseDateText() {
        return formatDate(this.info?.purchaseDate);
    }

    get deliveryDateText() {
        return this.info?.deliveryDate ? formatDate(this.info.deliveryDate) : 'Mua tại quầy';
    }

    get chosenLines() {
        return this.lines.filter((l) => l.qty > 0);
    }

    get total() {
        return this.chosenLines.reduce((sum, l) => sum + l.refund, 0);
    }

    get totalText() {
        return vnd(this.total);
    }

    // Giống SR_ApprovalService.levelFor ở Apex – chỉ để hiển thị trước
    get levelText() {
        if (!this.info || this.chosenLines.length === 0) {
            return '—';
        }
        let level = 'QLV';
        if (this.info.customerRisky) {
            level = 'QLV';
        } else if (this.info.autoApproveEnabled && this.total <= this.info.autoApproveLimit) {
            level = 'AUTO';
        } else if (this.total <= this.info.chtApproveLimit) {
            level = 'CHT';
        }
        return LEVEL_LABELS[level] + (this.info.customerRisky ? ' (khách có cờ Rủi ro)' : '');
    }

    get submitDisabled() {
        return this.isSaving || this.chosenLines.length === 0;
    }

    get errorItems() {
        return this.resultErrors.filter((t) => !!t).map((text, index) => ({ key: String(index), text }));
    }

    handleQty(event) {
        this.updateLine(event.target.dataset.id, { qty: Number(event.detail.value) || 0 });
    }

    handleReason(event) {
        this.updateLine(event.target.dataset.id, { reason: event.detail.value });
    }

    handleCondition(event) {
        this.updateLine(event.target.dataset.id, { condition: event.detail.value });
    }

    updateLine(orderItemId, changes) {
        this.lines = this.lines.map((l) => (l.orderItemId === orderItemId ? this.recalc({ ...l, ...changes }) : l));
    }

    recalc(line) {
        let refund = 0;
        let warning = null;
        if (line.qty > line.remainingQty) {
            warning = formatLabel(MSG_04, line.productName, line.remainingQty);
        } else if (line.qty > 0 && line.reason && line.condition) {
            const rate = this.info.rates[`${line.reason}|${line.condition}`] || 0;
            refund = refundAmount(line.unitPrice, line.qty, rate);
            if (rate === 0) {
                warning = formatLabel(
                    MSG_05,
                    line.productName,
                    labelOf(REASON_OPTIONS, line.reason),
                    labelOf(CONDITION_OPTIONS, line.condition)
                );
            }
        }
        return { ...line, refund, refundText: vnd(refund), warning };
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleSubmit() {
        const chosen = this.chosenLines;
        if (chosen.length === 0) {
            this.resultErrors = [MSG_06];
            return;
        }
        const missing = chosen.find((l) => !l.reason || !l.condition);
        if (missing) {
            this.resultErrors = [`Vui lòng chọn lý do và tình trạng cho ${missing.productName}.`];
            return;
        }
        const blocked = chosen.find((l) => l.warning);
        if (blocked) {
            this.resultErrors = [blocked.warning];
            return;
        }

        this.isSaving = true;
        this.resultErrors = [];
        try {
            const request = {
                orderId: this.recordId,
                lines: chosen.map((l) => ({
                    orderItemId: l.orderItemId,
                    quantity: l.qty,
                    reason: l.reason,
                    condition: l.condition
                }))
            };
            const result = await createFromCounter({ requestJson: JSON.stringify(request) });
            if (result.success) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: formatLabel(MSG_01, result.requestNumber, vnd(result.estimatedRefundAmount)),
                        variant: 'success'
                    })
                );
                this.dispatchEvent(new CloseActionScreenEvent());
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: { recordId: result.requestId, objectApiName: 'Return_Request__c', actionName: 'view' }
                });
            } else {
                this.resultErrors = [result.message, ...(result.details || []).map((d) => d.message)];
            }
        } catch (e) {
            this.resultErrors = [reduceErrors(e)];
        } finally {
            this.isSaving = false;
        }
    }
}

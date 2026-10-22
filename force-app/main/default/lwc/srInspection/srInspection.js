import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import LightningConfirm from 'lightning/confirm';
import LightningPrompt from 'lightning/prompt';
import getInspectionData from '@salesforce/apex/SR_ReturnUiController.getInspectionData';
import completeInspection from '@salesforce/apex/SR_ReturnUiController.completeInspection';
import receiveGoods from '@salesforce/apex/SR_ReturnUiController.receiveGoods';
import cancelRequest from '@salesforce/apex/SR_ReturnUiController.cancelRequest';
import MSG_21 from '@salesforce/label/c.SR_MSG_21';
import { CONDITION_OPTIONS, labelOf, vnd, refundAmount, reduceErrors } from 'c/srUtils';

const RESULT_OPTIONS = [
    { label: 'Đạt', value: 'PASSED' },
    { label: 'Không đạt', value: 'FAILED' }
];

// D.3 – Kiểm định hàng (FR-10) + nút Nhận hàng / Hủy. Đặt trên trang Return Request. Owner: Dev C
export default class SrInspection extends LightningElement {
    @api recordId;
    data = {};
    lines = [];
    rates = {};
    errorMessage;
    isBusy = false;
    resultOptions = RESULT_OPTIONS;
    conditionOptions = CONDITION_OPTIONS;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.isBusy = true;
        try {
            const d = await getInspectionData({ requestId: this.recordId });
            this.data = d;
            this.rates = d.rates || {};
            this.lines = d.lines.map((l) =>
                this.recalc({
                    ...l,
                    result: l.result === 'NOT_INSPECTED' ? null : l.result,
                    declaredConditionLabel: labelOf(CONDITION_OPTIONS, l.declaredCondition)
                })
            );
            this.errorMessage = undefined;
        } catch (e) {
            this.errorMessage = reduceErrors(e);
        } finally {
            this.isBusy = false;
        }
    }

    get hasLines() {
        return this.lines.length > 0;
    }

    get readOnly() {
        return !this.data.canInspect || this.isBusy;
    }

    get estimatedTotalText() {
        return vnd(this.lines.reduce((sum, l) => sum + (l.estimatedRefund || 0), 0));
    }

    get actualTotalText() {
        return vnd(this.lines.reduce((sum, l) => sum + l.refund, 0));
    }

    get completeDisabled() {
        return this.isBusy || this.lines.some((l) => !l.result);
    }

    handleResult(event) {
        this.updateLine(event.target.dataset.id, { result: event.detail.value });
    }

    handleCondition(event) {
        this.updateLine(event.target.dataset.id, { actualCondition: event.detail.value });
    }

    handleNote(event) {
        this.updateLine(event.target.dataset.id, { note: event.detail.value });
    }

    updateLine(lineId, changes) {
        this.lines = this.lines.map((l) => (l.lineId === lineId ? this.recalc({ ...l, ...changes }) : l));
    }

    // Đổi tình trạng → tính lại tiền ngay theo Phụ lục B.2; dòng Không đạt = 0đ
    recalc(line) {
        const rate = this.rates[`${line.reason}|${line.actualCondition}`] || 0;
        const refund = line.result === 'PASSED' ? refundAmount(line.unitPrice, line.quantity, rate) : 0;
        return { ...line, refund, refundText: vnd(refund), noteRequired: line.result === 'FAILED' };
    }

    async handleComplete() {
        const missingNote = this.lines.find((l) => l.result === 'FAILED' && !l.note);
        if (missingNote) {
            this.toast(MSG_21, 'error');
            return;
        }
        const ok = await LightningConfirm.open({
            message: 'Sau khi hoàn tất sẽ không sửa lại được kết quả kiểm định. Bạn chắc chắn?',
            label: 'Hoàn tất kiểm định',
            theme: 'warning'
        });
        if (!ok) {
            return;
        }
        const results = this.lines.map((l) => ({
            lineId: l.lineId,
            result: l.result,
            actualCondition: l.actualCondition,
            note: l.note
        }));
        await this.run(() => completeInspection({ requestId: this.recordId, resultsJson: JSON.stringify(results) }),
            'Đã hoàn tất kiểm định');
    }

    async handleReceive() {
        await this.run(() => receiveGoods({ requestId: this.recordId }), 'Đã nhận hàng, chuyển sang kiểm định');
    }

    async handleCancel() {
        const reason = await LightningPrompt.open({
            message: 'Nhập lý do hủy yêu cầu',
            label: 'Hủy yêu cầu',
            theme: 'warning'
        });
        if (!reason) {
            return;
        }
        await this.run(() => cancelRequest({ requestId: this.recordId, reason }), 'Đã hủy yêu cầu');
    }

    // Gọi Apex, báo kết quả, tải lại dữ liệu và làm mới các component chuẩn trên trang
    async run(action, successMessage) {
        this.isBusy = true;
        try {
            await action();
            this.toast(successMessage, 'success');
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            await this.load();
        } catch (e) {
            this.toast(reduceErrors(e), 'error');
        } finally {
            this.isBusy = false;
        }
    }

    toast(message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title: message, variant }));
    }
}

import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import LightningConfirm from 'lightning/confirm';
import LightningPrompt from 'lightning/prompt';
import getInspectionData from '@salesforce/apex/SR_ReturnUiController.getInspectionData';
import calcLineRefund from '@salesforce/apex/SR_ReturnUiController.calcLineRefund';
import completeInspection from '@salesforce/apex/SR_ReturnUiController.completeInspection';
import receiveGoods from '@salesforce/apex/SR_ReturnUiController.receiveGoods';
import cancelRequest from '@salesforce/apex/SR_ReturnUiController.cancelRequest';
import MSG_21 from '@salesforce/label/c.SR_MSG_21';
import { REASON_OPTIONS, CONDITION_OPTIONS, labelOf, vnd, reduceErrors } from 'c/srUtils';

const RESULT_OPTIONS = [
    { label: 'Đạt', value: 'PASSED' },
    { label: 'Không đạt', value: 'FAILED' }
];

// D.3 – Kiểm định hàng (FR-10) + nút Nhận hàng / Hủy. Đặt trên trang Return Request. Owner: Dev C
// Tiền dòng luôn do Apex tính (calcLineRefund của Dũng); JS chỉ cộng các dòng Đạt để hiện tổng.
export default class SrInspection extends LightningElement {
    @api recordId;
    data = {};
    lines = [];
    errorMessage;
    isBusy = false;
    resultOptions = RESULT_OPTIONS;
    conditionOptions = CONDITION_OPTIONS;
    calcSeq = 0; // số thứ tự lần tính tiền, để bỏ kết quả của lần gọi cũ

    connectedCallback() {
        this.load();
    }

    async load() {
        this.isBusy = true;
        try {
            const d = await getInspectionData({ requestId: this.recordId });
            this.lines = d.lines.map((l) =>
                this.withRefund({
                    ...l,
                    reasonLabel: labelOf(REASON_OPTIONS, l.reason),
                    declaredConditionLabel: labelOf(CONDITION_OPTIONS, l.declaredCondition)
                })
            );
            this.data = d;
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

    // Đổi tình trạng thực tế → Apex tính lại tiền dòng theo Phụ lục B.2
    async handleCondition(event) {
        const lineId = event.target.dataset.id;
        const actualCondition = event.detail.value;
        const previous = this.lines.find((l) => l.lineId === lineId).actualCondition;
        const seq = ++this.calcSeq;
        this.updateLine(lineId, { actualCondition, calcSeq: seq, calculating: true });
        try {
            const actualRefund = await calcLineRefund({ lineId, actualCondition });
            this.updateIfLatest(lineId, seq, { actualRefund, calculating: false });
        } catch (e) {
            this.updateIfLatest(lineId, seq, { actualCondition: previous, calculating: false });
            this.toast(reduceErrors(e), 'error');
        }
    }

    handleNote(event) {
        this.updateLine(event.target.dataset.id, { note: event.detail.value });
    }

    updateLine(lineId, changes) {
        this.lines = this.lines.map((l) => (l.lineId === lineId ? this.withRefund({ ...l, ...changes }) : l));
    }

    // Người dùng đã đổi tình trạng lần nữa thì bỏ kết quả của lần tính trước
    updateIfLatest(lineId, seq, changes) {
        const line = this.lines.find((l) => l.lineId === lineId);
        if (line && line.calcSeq === seq) {
            this.updateLine(lineId, changes);
        }
    }

    // Chỉ dòng Đạt được hoàn tiền; dòng Không đạt hoặc chưa chọn = 0đ
    withRefund(line) {
        const refund = line.result === 'PASSED' ? line.actualRefund || 0 : 0;
        return {
            ...line,
            refund,
            refundText: line.calculating ? 'Đang tính…' : vnd(refund),
            noteRequired: line.result === 'FAILED'
        };
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

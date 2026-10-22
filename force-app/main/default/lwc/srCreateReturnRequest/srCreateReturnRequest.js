import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getReturnableLines from '@salesforce/apex/SR_ReturnUiController.getReturnableLines';
import previewLevel from '@salesforce/apex/SR_ReturnUiController.previewLevel';
import createFromCounter from '@salesforce/apex/SR_ReturnUiController.createFromCounter';
import { MSG_01, MSG_06, formatLabel, msgFromError } from 'c/srMessages';
import { REASON_OPTIONS, CONDITION_OPTIONS, LEVEL_LABELS, vnd, formatDate, reduceErrors } from 'c/srUtils';

const PREVIEW_DELAY_MS = 300;
const EMPTY = '—';

// D.1 – Tạo yêu cầu trả hàng tại quầy (FR-01, FR-02). Quick Action trên Order. Owner: Dev C (Đức)
// Tiền hoàn và cấp duyệt luôn do Apex tính (previewLevel); JS chỉ hiển thị, không tự tính BR.
export default class SrCreateReturnRequest extends NavigationMixin(LightningElement) {
    @api recordId; // Id đơn hàng
    info;
    lines = [];
    loadError;
    preview; // kết quả previewLevel gần nhất
    submitErrors = [];
    isPreviewing = false;
    isSaving = false;
    reasonOptions = REASON_OPTIONS;
    conditionOptions = CONDITION_OPTIONS;
    noLineMessage = MSG_06;
    previewTimer;
    previewSeq = 0;

    // recordId của Quick Action có thể đến muộn, nên dùng @wire với '$recordId'
    @wire(getReturnableLines, { orderId: '$recordId' })
    wiredInfo({ data, error }) {
        if (data) {
            this.info = data;
            this.lines = (data.lines || []).map((l) => ({
                ...l,
                locked: !l.returnable,
                rowClass: l.returnable ? '' : 'sr-row_locked',
                deadlineText: formatDate(l.deadline),
                qty: 0,
                reason: null,
                condition: null,
                refundText: EMPTY,
                error: null,
                hint: null
            }));
            this.loadError = undefined;
        } else if (error) {
            this.loadError = reduceErrors(error);
        }
    }

    disconnectedCallback() {
        clearTimeout(this.previewTimer);
    }

    get isLoading() {
        return !this.info && !this.loadError;
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

    // Dòng đủ thông tin để Apex tính tiền
    get draftLines() {
        return this.chosenLines
            .filter((l) => l.reason && l.condition)
            .map((l) => ({ orderItemId: l.orderItemId, quantity: l.qty, reason: l.reason, condition: l.condition }));
    }

    get showNoLineHint() {
        return !!this.info && this.chosenLines.length === 0;
    }

    get submitDisabled() {
        return this.isSaving || this.chosenLines.length === 0;
    }

    get totalText() {
        if (this.isPreviewing) {
            return 'Đang tính…';
        }
        return `${vnd(this.preview ? this.preview.totalRefund : 0)}đ`;
    }

    get levelText() {
        if (this.isPreviewing) {
            return 'Đang tính…';
        }
        const level = this.preview && this.preview.approvalLevel;
        if (!level) {
            return EMPTY;
        }
        const label = LEVEL_LABELS[level] || level;
        return this.preview.customerRisky ? `${label} (khách có cờ Rủi ro)` : label;
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
        this.lines = this.lines.map((l) => (l.orderItemId === orderItemId ? { ...l, ...changes } : l));
        this.submitErrors = [];
        this.schedulePreview();
    }

    // Đổi SL / lý do / tình trạng: chờ 300ms không đổi nữa mới gọi Apex (debounce)
    schedulePreview() {
        clearTimeout(this.previewTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.previewTimer = setTimeout(() => {
            this.runPreview();
        }, PREVIEW_DELAY_MS);
    }

    async runPreview() {
        const seq = ++this.previewSeq; // chỉ nhận kết quả của lần gọi mới nhất
        const draftLines = this.draftLines;
        if (draftLines.length === 0) {
            this.isPreviewing = false;
            this.applyPreview(null);
            return;
        }
        this.isPreviewing = true;
        try {
            const result = await previewLevel({
                draftJson: JSON.stringify({ orderId: this.recordId, lines: draftLines })
            });
            if (seq === this.previewSeq) {
                this.applyPreview(result);
            }
        } catch (e) {
            if (seq === this.previewSeq) {
                this.applyPreview(null);
                this.submitErrors = [{ key: 'preview', text: reduceErrors(e) }];
            }
        } finally {
            if (seq === this.previewSeq) {
                this.isPreviewing = false;
            }
        }
    }

    // Gắn tiền từng dòng và lỗi tại dòng (MSG-04 vượt số lượng, MSG-05 tỷ lệ 0%) từ kết quả Apex
    applyPreview(result) {
        this.preview = result;
        const byItem = new Map(((result && result.lines) || []).map((p) => [p.orderItemId, p]));
        this.lines = this.lines.map((l) => {
            const p = l.qty > 0 ? byItem.get(l.orderItemId) : undefined;
            const needsChoice = l.qty > 0 && (!l.reason || !l.condition);
            return {
                ...l,
                refundText: p && p.refundAmount !== undefined && p.refundAmount !== null ? `${vnd(p.refundAmount)}đ` : EMPTY,
                error: p && p.errorCode ? msgFromError({ code: p.errorCode, params: p.errorParams }) : null,
                hint: needsChoice ? 'Chọn lý do và tình trạng để tính tiền' : null
            };
        });
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleSubmit() {
        const chosen = this.chosenLines;
        if (chosen.length === 0) {
            this.submitErrors = [{ key: 'msg06', text: MSG_06 }];
            return;
        }
        const missing = chosen.find((l) => !l.reason || !l.condition);
        if (missing) {
            this.submitErrors = [{ key: 'missing', text: `Vui lòng chọn lý do và tình trạng cho ${missing.productName}.` }];
            return;
        }
        const withError = chosen.find((l) => l.error);
        if (withError) {
            this.submitErrors = [{ key: 'line', text: withError.error }];
            return;
        }

        clearTimeout(this.previewTimer);
        this.isSaving = true;
        this.submitErrors = [];
        try {
            const result = await createFromCounter({
                draftJson: JSON.stringify({ orderId: this.recordId, lines: this.draftLines })
            });
            if (result && result.success) {
                const amount = result.estimatedRefundAmount !== undefined ? result.estimatedRefundAmount : result.estimatedRefund;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: formatLabel(MSG_01, result.requestNumber, vnd(amount)),
                        variant: 'success'
                    })
                );
                this.dispatchEvent(new CloseActionScreenEvent());
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: { recordId: result.requestId, objectApiName: 'Return_Request__c', actionName: 'view' }
                });
            } else {
                const details = (result && (result.errors || result.details)) || [];
                const texts = [result && result.message, ...details.map(msgFromError)].filter((t) => !!t);
                this.submitErrors = texts.map((text, index) => ({ key: String(index), text }));
            }
        } catch (e) {
            this.submitErrors = [{ key: 'error', text: reduceErrors(e) }];
        } finally {
            this.isSaving = false;
        }
    }
}
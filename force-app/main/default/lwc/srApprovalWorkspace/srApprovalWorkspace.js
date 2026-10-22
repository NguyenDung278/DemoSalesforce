import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import LightningPrompt from 'lightning/prompt';
import getMyStores from '@salesforce/apex/SR_ApprovalUiController.getMyStores';
import getQueue from '@salesforce/apex/SR_ApprovalUiController.getQueue';
import decide from '@salesforce/apex/SR_ApprovalUiController.decide';
import MSG_12 from '@salesforce/label/c.SR_MSG_12';
import MSG_30 from '@salesforce/label/c.SR_MSG_30';
import MSG_31 from '@salesforce/label/c.SR_MSG_31';
import { STATUS_OPTIONS, formatLabel, vnd, reduceErrors } from 'c/srUtils';

const CHANNEL = '/event/SR_UI_Notice__e';
const PAGE_SIZE = 50;

function isoDay(date) {
    const d = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
    return d.toISOString().substring(0, 10);
}

// Dòng quá hạn duyệt tô đỏ (D.2 "Cảnh báo")
const CELL = { class: { fieldName: 'rowClass' } };

const COLUMNS = [
    { label: 'Mã yêu cầu', fieldName: 'recordUrl', type: 'url', typeAttributes: { label: { fieldName: 'requestNumber' } }, cellAttributes: CELL },
    { label: 'Khách hàng', fieldName: 'customerName', cellAttributes: CELL },
    { label: 'Cửa hàng', fieldName: 'storeName', cellAttributes: CELL },
    { label: 'Kênh', fieldName: 'channel', cellAttributes: CELL },
    { label: 'Tổng tiền dự kiến', fieldName: 'estimatedRefund', type: 'currency', sortable: true,
      typeAttributes: { currencyCode: 'VND', minimumFractionDigits: 0, maximumFractionDigits: 0 }, cellAttributes: CELL },
    { label: 'Cấp duyệt', fieldName: 'approvalLevel', cellAttributes: CELL },
    { label: 'Người duyệt', fieldName: 'approverName', cellAttributes: CELL },
    { label: 'Chờ (giờ)', fieldName: 'waitingHours', type: 'number', sortable: true, cellAttributes: CELL },
    { label: 'Rủi ro', fieldName: 'riskText', cellAttributes: CELL }
];

// D.2 – Màn hình duyệt cho CHT/QLV (FR-08) + thông báo realtime (FR-09). Owner: Dev C
export default class SrApprovalWorkspace extends LightningElement {
    columns = COLUMNS;
    statusOptions = STATUS_OPTIONS;
    storeOptions = [{ label: 'Tất cả cửa hàng của tôi', value: '' }];
    myStoreCodes = [];
    rows = [];
    total = 0;
    selectedIds = [];
    isLoading = false;
    errorMessage;
    sortedBy = 'waitingHours';
    sortedDirection = 'desc';
    pageNumber = 1;
    subscription;

    filters = {
        status: 'PENDING_APPROVAL',
        storeId: '',
        fromDate: isoDay(new Date(Date.now() - 30 * 24 * 3600 * 1000)),
        toDate: isoDay(new Date()),
        onlyMine: false
    };

    @wire(getMyStores)
    wiredStores({ data }) {
        if (data) {
            this.storeOptions = [
                { label: 'Tất cả cửa hàng của tôi', value: '' },
                ...data.map((s) => ({ label: s.label, value: s.value }))
            ];
            this.myStoreCodes = data.map((s) => s.storeCode);
        }
    }

    connectedCallback() {
        this.load();
        this.subscribeRealtime();
    }

    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription);
        }
    }

    get noSelection() {
        return this.selectedIds.length === 0;
    }

    get pageCount() {
        return Math.max(1, Math.ceil(this.total / PAGE_SIZE));
    }

    get isFirstPage() {
        return this.pageNumber <= 1;
    }

    get isLastPage() {
        return this.pageNumber >= this.pageCount;
    }

    async load() {
        this.isLoading = true;
        try {
            const page = await getQueue({
                filtersJson: JSON.stringify({
                    ...this.filters,
                    storeId: this.filters.storeId || null,
                    // "Chờ (giờ)" giảm dần = Submitted_At tăng dần = chờ lâu nhất lên đầu
                    sortBy: this.sortedBy === 'estimatedRefund' ? 'AMOUNT' : 'WAIT',
                    sortDir: this.sortedBy === 'estimatedRefund'
                        ? this.sortedDirection
                        : this.sortedDirection === 'desc' ? 'asc' : 'desc',
                    pageNumber: this.pageNumber
                })
            });
            this.total = page.total;
            this.rows = page.rows.map((r) => ({
                ...r,
                recordUrl: `/lightning/r/Return_Request__c/${r.id}/view`,
                riskText: r.risky ? '⚠ Rủi ro' : '',
                rowClass: r.overdue ? 'slds-text-color_error' : ''
            }));
            this.selectedIds = [];
            this.errorMessage = undefined;
        } catch (e) {
            this.errorMessage = reduceErrors(e);
        } finally {
            this.isLoading = false;
        }
    }

    handleFilter(event) {
        const field = event.target.dataset.field;
        const value = field === 'onlyMine' ? event.target.checked : event.detail.value;
        this.filters = { ...this.filters, [field]: value };
        this.pageNumber = 1;
        this.load();
    }

    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
        this.load();
    }

    handleSelection(event) {
        this.selectedIds = event.detail.selectedRows.map((r) => r.id);
    }

    prevPage() {
        this.pageNumber -= 1;
        this.load();
    }

    nextPage() {
        this.pageNumber += 1;
        this.load();
    }

    async handleApprove() {
        await this.submitDecision(true, null);
    }

    async handleReject() {
        const reason = await LightningPrompt.open({
            message: 'Lý do từ chối (áp dụng cho mọi dòng đã chọn)',
            label: 'Từ chối yêu cầu',
            theme: 'warning'
        });
        if (reason === null) {
            return; // bấm Hủy
        }
        if (!reason.trim()) {
            this.toast(MSG_12, 'error');
            return;
        }
        await this.submitDecision(false, reason.trim());
    }

    async submitDecision(approve, reason) {
        const items = this.rows
            .filter((r) => this.selectedIds.includes(r.id))
            .map((r) => ({ requestId: r.id, lastModified: r.lastModified }));
        this.isLoading = true;
        try {
            const result = await decide({ itemsJson: JSON.stringify(items), approve, reason });
            this.toast(result.summary, result.errors.length === 0 ? 'success' : 'warning');
        } catch (e) {
            this.toast(reduceErrors(e), 'error');
        } finally {
            this.isLoading = false;
        }
        await this.load();
    }

    // FR-09: hoàn tiền xong/lỗi → hiện thông báo góc màn hình, không cần tải lại trang
    subscribeRealtime() {
        onError((error) => {
            // eslint-disable-next-line no-console
            console.error('empApi error', JSON.stringify(error));
        });
        subscribe(CHANNEL, -1, (message) => {
            const p = message.data.payload;
            if (!this.myStoreCodes.includes(p.Store_Code__c)) {
                return;
            }
            if (p.Result__c === 'COMPLETED') {
                this.toast(formatLabel(MSG_30, p.Request_Number__c, vnd(p.Amount__c)), 'success');
            } else {
                this.toast(formatLabel(MSG_31, p.Request_Number__c), 'warning');
            }
            this.load();
        }).then((sub) => {
            this.subscription = sub;
        });
    }

    toast(message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title: message, variant }));
    }
}

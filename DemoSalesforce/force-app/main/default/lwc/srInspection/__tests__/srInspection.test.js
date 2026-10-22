import { createElement } from '@lwc/engine-dom';
import SrInspection from 'c/srInspection';
import getInspectionData from '@salesforce/apex/SR_ReturnUiController.getInspectionData';
import calcLineRefund from '@salesforce/apex/SR_ReturnUiController.calcLineRefund';

jest.mock('@salesforce/apex/SR_ReturnUiController.getInspectionData', () => ({ default: jest.fn() }), {
    virtual: true
});
jest.mock('@salesforce/apex/SR_ReturnUiController.calcLineRefund', () => ({ default: jest.fn() }), {
    virtual: true
});
jest.mock('@salesforce/apex/SR_ReturnUiController.completeInspection', () => ({ default: jest.fn() }), {
    virtual: true
});
jest.mock('@salesforce/apex/SR_ReturnUiController.receiveGoods', () => ({ default: jest.fn() }), {
    virtual: true
});
jest.mock('@salesforce/apex/SR_ReturnUiController.cancelRequest', () => ({ default: jest.fn() }), {
    virtual: true
});

const LINE_ID = 'a01000000000001AAA';
const DATA = {
    status: 'INSPECTING',
    canInspect: true,
    canReceiveGoods: false,
    canCancel: false,
    lines: [
        {
            lineId: LINE_ID,
            productName: 'Nồi chiên không dầu 5L',
            sku: 'AF-PH-5L',
            quantity: 1,
            reason: 'NOT_SATISFIED',
            declaredCondition: 'OPENED',
            actualCondition: 'OPENED',
            result: null,
            note: null,
            estimatedRefund: 1992000,
            actualRefund: 1992000
        }
    ]
};

// Chờ Apex giả lập trả kết quả và component render lại (vài vòng microtask)
async function flushPromises(rounds = 5) {
    await Promise.resolve();
    if (rounds > 1) {
        await flushPromises(rounds - 1);
    }
}

function render() {
    const element = createElement('c-sr-inspection', { is: SrInspection });
    element.recordId = 'a00000000000001AAA';
    document.body.appendChild(element);
    return element;
}

const refundCell = (element) => [...element.shadowRoot.querySelectorAll('tbody td')].pop().textContent;
const actualTotal = (element) => element.shadowRoot.querySelector('b').textContent;

describe('c-sr-inspection', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('đổi tình trạng thực tế thì lấy tiền dòng từ Apex, tổng thực tế chỉ cộng dòng Đạt', async () => {
        getInspectionData.mockResolvedValue(DATA);
        calcLineRefund.mockResolvedValue(1494000);
        const element = render();
        await flushPromises();
        expect(refundCell(element)).toBe('0'); // chưa chọn Đạt / Không đạt

        element.shadowRoot
            .querySelector('lightning-radio-group')
            .dispatchEvent(new CustomEvent('change', { detail: { value: 'PASSED' } }));
        await flushPromises();
        expect(refundCell(element)).toBe('1.992.000');
        expect(actualTotal(element)).toBe('1.992.000đ');

        element.shadowRoot
            .querySelector('lightning-combobox')
            .dispatchEvent(new CustomEvent('change', { detail: { value: 'USED' } }));
        await flushPromises();
        expect(calcLineRefund).toHaveBeenCalledWith({ lineId: LINE_ID, actualCondition: 'USED' });
        expect(refundCell(element)).toBe('1.494.000');
        expect(actualTotal(element)).toBe('1.494.000đ');
    });

    it('Apex tính tiền lỗi thì giữ lại tình trạng cũ', async () => {
        getInspectionData.mockResolvedValue(DATA);
        calcLineRefund.mockRejectedValue({ body: { message: 'Lỗi tính tiền' } });
        const element = render();
        await flushPromises();

        const combobox = element.shadowRoot.querySelector('lightning-combobox');
        combobox.dispatchEvent(new CustomEvent('change', { detail: { value: 'USED' } }));
        await flushPromises();
        expect(combobox.value).toBe('OPENED');
    });
});

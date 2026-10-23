@IsTest(SeeAllData=false)
private class SR_SharedDTOTest {
    @IsTest
    static void createRequest_roundTripsThroughJson() {
        SR_CreateRequestDTO input = new SR_CreateRequestDTO();
        input.externalRequestId = 'POS-HCM012-20261005-0007';
        input.channel = 'POS';
        input.orderNumber = '00012345';
        input.customerPhone = '0901234567';
        input.storeCode = 'HCM-012';
        input.lines.add(
            new SR_CreateLineDTO(
                null,
                'AF-PH-5L',
                1,
                'NOT_SATISFIED',
                'OPENED'
            )
        );

        String payload = JSON.serialize(input);
        SR_CreateRequestDTO actual = (SR_CreateRequestDTO) JSON.deserialize(
            payload,
            SR_CreateRequestDTO.class
        );

        Assert.areEqual('POS-HCM012-20261005-0007', actual.externalRequestId);
        Assert.areEqual('POS', actual.channel);
        Assert.areEqual('00012345', actual.orderNumber);
        Assert.areEqual(1, actual.lines.size());
        Assert.areEqual('AF-PH-5L', actual.lines[0].sku);
        Assert.areEqual(Decimal.valueOf('1'), actual.lines[0].quantity);
        Assert.isFalse(actual.atomicMode);
    }

    @IsTest
    static void resultDtos_initializeCollectionsAndDefaults() {
        SR_CreateResultDTO createResult = new SR_CreateResultDTO();
        SR_DecisionResultDTO decisionResult = new SR_DecisionResultDTO();
        SR_ReturnableLineDTO returnableLine = new SR_ReturnableLineDTO();
        SR_ErrorDetailDTO errorDetail = new SR_ErrorDetailDTO(
            'AF-PH-5L',
            SR_ErrorCode.NOT_RETURNABLE,
            new List<String>{ 'Thẻ cào' }
        );

        Assert.isFalse(createResult.success);
        Assert.isFalse(createResult.isDuplicate);
        Assert.areEqual(Decimal.valueOf('0'), createResult.estimatedRefund);
        Assert.areEqual(0, createResult.lines.size());
        Assert.areEqual(0, createResult.errors.size());

        Assert.isFalse(decisionResult.success);
        Assert.areEqual(0, decisionResult.errors.size());

        Assert.isFalse(returnableLine.eligible);
        Assert.areEqual(Decimal.valueOf('0'), returnableLine.returnableQuantity);
        Assert.areEqual(0, returnableLine.params.size());

        Assert.areEqual('AF-PH-5L', errorDetail.reference);
        Assert.areEqual(SR_ErrorCode.NOT_RETURNABLE, errorDetail.code);
        Assert.areEqual('Thẻ cào', errorDetail.params[0]);
    }

    @IsTest
    static void lineResult_constructorSetsInspectionContract() {
        SR_LineResultDTO dto = new SR_LineResultDTO(
            null,
            'FAILED',
            'USED',
            'Vỏ máy bị nứt'
        );

        Assert.areEqual('FAILED', dto.result);
        Assert.areEqual('USED', dto.actualCondition);
        Assert.areEqual('Vỏ máy bị nứt', dto.note);
    }
}

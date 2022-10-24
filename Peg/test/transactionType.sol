library transactionType {
    struct DepositType {
        uint8 _operationType;
        uint64 callerUserChainID;
        uint8 callerUserAddressIndex;
        uint8 asset;
        uint8 refundAddressIndex;
        uint8 zionToAddressIndex;
        uint256 amount;
    }

    struct DepositAndWithdrawType {
        uint8 _operationType;
        uint64 callerUserChainID;
        uint8 callerUserAddressIndex;
        uint8 asset;
        uint8 refundAddressIndex;
        uint8 zionToAddressIndex;
        uint8 targetAddressIndex;
        uint64 targetChainID;
        uint256 amount;
    }
}
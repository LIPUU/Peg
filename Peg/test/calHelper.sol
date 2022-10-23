library calHelper {
    
    // using calHelper for mapping(uint64 =>mapping(address=>uint)); // vaultState type 
    // using calHelper for mapping(address=>uint); // PegTokensTotalSupplyState type
    // using calHelper for mapping(address=>mapping(uint64=>uint)); // PegTokensSideChainLiquidity type

    function updateUserState(
        mapping(uint64 =>mapping(address=>mapping(address=>uint))) storage userState,
        uint64 chainId,
        address assetAddress,
        address userAddress,
        uint expectedBalance
        ) external {
            userState[chainId][assetAddress][userAddress]=expectedBalance;
    }

    // function updateVaultState
}


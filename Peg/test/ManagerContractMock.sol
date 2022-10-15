// because there is a Mock multi-chain environment, ManagerContractMock.crossChain simulates the operation of relayers
// it directly calls zion peg Token's methods.

import "core/ZionPegToken.sol";
import "forge-std/console.sol";
import "core/Codec.sol";

contract MockChainIDChannel {
    uint64 public currentlyFromChainID;
    function setCurrentlyChainID(uint64 chainID) public {
        currentlyFromChainID=chainID;
    }
}

contract ManagerContractMock {
    MockChainIDChannel mockChainIDChannel;
    constructor(MockChainIDChannel _mockChainIDChannel) {
        mockChainIDChannel = _mockChainIDChannel;
    }
    function crossChain(
        // for example, user -> vault.deposit -> ManagerContract.crossChain(emit event)-> |relayer|->PegToken
        // relayer left side is side chain,right side is zion chain.
        uint64 toChainId,
        bytes calldata toContract, // pegToken(s)
        bytes calldata method, // receiveMessage
        bytes calldata txData // Codec.encodeDepositeMessage(toAddress, Utils.addressToBytes(refundAddress), pegAmount)
    ) external returns (bool) {
        uint64 fromChainID = mockChainIDChannel.currentlyFromChainID();
        address _toContract = abi.decode(toContract,(address)); // corresponding PegToken
        ZionPegToken(_toContract).receiveMessage(txData,abi.encodePacked(msg.sender),fromChainID);
        return true;
    }
}


pragma solidity ^0.8.0;

import "../interfaces/ICrossChainManager.sol";
import "../libs/utils/Utils.sol";

abstract contract Core {

    bytes constant BRANCH_RECEIVE_METHOD_BYTES = "0x726563656976654d657373616765"; // receiveMessage

    address managerContractAddress;
    mapping(uint64 => bytes) public branchMap; // chainID->side chain vault address(本pegToken对应的代币)
    // 假设zion上的某种pegToken是usdtPegToken，它将能够在zion连接到的生态系统内的任意链上兑换出usdt。
    modifier onlyManagerContract {
        require(msg.sender == managerContractAddress, "msgSender is not CrossChainManagerContract");
        _;
    }

    modifier onlyBranch(bytes memory fromContractAddr, uint64 fromChainId) {
        require(Utils.equalStorage(branchMap[fromChainId], fromContractAddr), "from contract is not valid branch contract");
        _;
    }

    function sendMessageToBranch( // ZionPegToken里的实现有调这个方法
        uint64 branchChainId, // side chainID
        bytes memory message 
        // 这个message在不同的情景下承载了不同的内容
        // 在withdraw时message中打包的目标地址以及数量
        // 在暂停某个侧链的某个vault的时候，打包的有pause的信息
    ) virtual internal {
        require(branchMap[branchChainId].length != 0, "invalid branch chainId");
        require(
            CrossChainManager(managerContractAddress).crossChain(
                branchChainId,
                branchMap[branchChainId], // vault contract address of side chain.
                BRANCH_RECEIVE_METHOD_BYTES,
                message),
            "CrossChainManager crossChain executed error!"
        );
    } // relayer会监听crossChain发出的事件，从而在目标侧链的vault合约上做出进一步的操作

    // receive message from sideChain ( user->vault.sol(disposit||dispositAndWithDraw)---relayer->PegToken.receiveMessage  )
    function receiveMessage(
        bytes memory argsBs,
        bytes memory fromContractAddr, // vault address in side chain
        uint64 fromChainId
    ) onlyManagerContract onlyBranch(fromContractAddr, fromChainId) virtual external returns (bool) {
        handleBranchMessage(fromChainId, argsBs);
        return true;
    }
    // in peg Token, only this function is external

    function handleBranchMessage(uint64 branchChainId, bytes memory message) virtual internal;

}


abstract contract Branch {

    bytes constant CORE_RECEIVE_METHOD_BYTES = "0x726563656976654d657373616765"; // receiveMessage

    address managerContractAddress;
    bytes public coreAddress;
    uint64 coreChainId;

    modifier onlyManagerContract {
        require(msg.sender == managerContractAddress, "msgSender is not CrossChainManagerContract");
        _;
    }

    // core chain is zion chain, that mean coreChainId is zion chainId
    // coreAddress is corresponding PegToken on Zion
    modifier onlyCore(bytes memory fromContractAddr, uint64 fromChainId) {
        require(coreChainId == fromChainId, "from chain is not core chain"); 
        // require(Utils.equalStorage(coreAddress, fromContractAddr), "from contract is not core contract");
        address _coreAddress = Utils.bytesToAddress(coreAddress);
        address _fromContractAddr=Utils.bytesToAddress(fromContractAddr);
        require(_coreAddress==_fromContractAddr);
        _;
    }

    function sendMessageToCore(
        bytes memory message
    ) virtual internal {
        require(
            CrossChainManager(managerContractAddress).crossChain(
                coreChainId, // zionChainId
                coreAddress, // corresponding PegToken address on Zion. Each side chain Vault contract corresponds a Zion PegToken(coreAddress)
                CORE_RECEIVE_METHOD_BYTES,
                message),
            "CrossChainManager crossChain executed error!"
        );
    }

    function receiveMessage(
        bytes memory argsBs,
        bytes memory fromContractAddr,
        uint64 fromChainId
    ) onlyManagerContract onlyCore(fromContractAddr, fromChainId) external returns (bool) {
        handleCoreMessage(argsBs);
        return true;
    }

    function handleCoreMessage(bytes memory message) virtual internal;

}
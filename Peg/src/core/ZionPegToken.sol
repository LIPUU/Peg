pragma solidity ^0.8.8;

import "../libs/common/ZeroCopySink.sol";
import "../libs/common/ZeroCopySource.sol";
import "../libs/token/ERC20/ERC20.sol";
import "../libs/access/Ownable.sol";
import "../libs/security/Pausable.sol";
import "../libs/security/ReentrancyGuard.sol";
import "../libs/utils/Utils.sol";
import "./CrossChainGovernance.sol";
import "./Codec.sol";
import "./MessageFilter.sol";

contract ZionPegToken is Ownable, Pausable, ReentrancyGuard, Core, ERC20 {
    
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        branchs[SENTINEL_BRANCH] = SENTINEL_BRANCH;
    }

    address public messageFilter;
    mapping(uint64 => uint) public chainLiquidityMap; // chainLiquidityMap[chainId] = amount

    uint64 internal constant SENTINEL_BRANCH = 0xffffffffffffffff;
    mapping(uint64 => uint64) internal branchs;
    uint256 internal branchCount;

    event BindBranchEvent(uint64 branchChainId, bytes branchAddress);

    event Pause(uint64[] chainIds, bool needWait);
    event Unpause(uint64[] chainIds, bool needWait);

    event DepositeEvent(uint64 fromChainId, address toAddress, uint256 amount);
    event WithdrawEvent(uint64 toChainId, bytes toAddress, uint amount);
    event RollBackEvent(uint64 fromChainId, bytes refundAddress, uint amount, string err);
    event RelayInterrupted(uint64 fromChainId, address zionReceiveAddress, uint amount, string err);
    event RevertEvent(string err);

    function setManagerContract(address _managerContractAddress) public onlyOwner {
        managerContractAddress=_managerContractAddress;
    }

    // User functions 
    function withdraw(bytes memory toAddress, uint64 toChainId, uint256 amount) public nonReentrant whenNotPaused {
        require(amount != 0, "amount cannot be zero!");

        require(chainLiquidityMap[toChainId] >= amount,"target chain liquidity is not enough!");
        chainLiquidityMap[toChainId]-=amount;
        
        _burn(msg.sender, amount); // this是某种资产的映射PegToken

        sendWithdrawToBranch(toChainId, toAddress, amount);
    }
    
    // Management
    function setMessageFilter(address messageFilterAddress) onlyOwner public {
        messageFilter = messageFilterAddress;
    }

    function bindBranch(uint64 branchChainId, bytes memory branchAddress) onlyOwner public {
        branchMap[branchChainId] = branchAddress; // 记录目标链上对应的vault合约地址
        if (branchAddress.length == 0) {
            removeBranch(branchChainId);
        } else {
            addBranch(branchChainId);
        }
        emit BindBranchEvent(branchChainId, branchAddress); 
    }

    // 假设本PigToken是usdt，那么branchChainIds就是连接的各条区块链，branchAddrs就是对应的各条区块链上的usdt的地址
    function bindBranchBatch(uint64[] memory branchChainIds, bytes[] memory branchAddrs) onlyOwner public {
        require(branchChainIds.length == branchAddrs.length, "input lists length do not match");
        for (uint i = 0; i < branchChainIds.length; i++) {
            uint64 branchChainId = branchChainIds[i];
            bytes memory branchAddress = branchAddrs[i];
            branchMap[branchChainId] = branchAddress;
            if (branchAddress.length == 0) {
                removeBranch(branchChainId);
            } else {
                addBranch(branchChainId);
            }
            emit BindBranchEvent(branchChainId, branchAddress); 
        }
    }

    function pauseBranch(uint64[] memory chainIds, bool needWait) onlyOwner public {
        bytes memory message = Codec.encodePauseMessage(needWait);
        for (uint i = 0; i < chainIds.length; i++) {
            sendMessageToBranch(chainIds[i], message);
        }
        emit Pause(chainIds, needWait);
    }

    function pauseAllBranchs(bool needWait) onlyOwner public {
        uint64[] memory chainIds = getBranchs(); // 有没有可能里面有空的
        bytes memory message = Codec.encodePauseMessage(needWait);
        for (uint i = 0; i < chainIds.length; i++) {
            sendMessageToBranch(chainIds[i], message);
        }
        emit Pause(chainIds, needWait);
    }

    function unpauseBranch(uint64[] memory chainIds, bool needWait) onlyOwner public {
        bytes memory message = Codec.encodeUnpauseMessage(needWait);
        for (uint i = 0; i < chainIds.length; i++) {
            sendMessageToBranch(chainIds[i], message);
        }
        emit Unpause(chainIds, needWait);
    }

    function unpauseAllBranchs(bool needWait) onlyOwner public {
        uint64[] memory chainIds = getBranchs();
        bytes memory message = Codec.encodeUnpauseMessage(needWait);
        for (uint i = 0; i < chainIds.length; i++) {
            sendMessageToBranch(chainIds[i], message);
        }
        emit Unpause(chainIds, needWait);
    }

    function addBranch(uint64 newBranchChainId) internal {
        require(newBranchChainId != SENTINEL_BRANCH, "Invalid branch chainId provided");
        if (branchs[newBranchChainId] != 0) { return; } // No duplicate branch chainId
        branchs[newBranchChainId] = branchs[SENTINEL_BRANCH];
        branchs[SENTINEL_BRANCH] = newBranchChainId;
        branchCount++;
    }

    function removeBranch(uint64 branchChainId) internal {
        require(branchChainId != SENTINEL_BRANCH, "Invalid branch chainId provided");
        if (branchs[branchChainId] == 0) { return; }
        uint64 prevBranch = branchs[SENTINEL_BRANCH];
        for (;branchs[prevBranch] != branchChainId;) {
            prevBranch = branchs[prevBranch];
        }
        branchs[prevBranch] = branchs[branchChainId];
        branchs[branchChainId] = 0;
        branchCount--;
    }

    function getBranchs() public view returns (uint64[] memory chainIdArray) {
        uint64[] memory arrayChainId = new uint64[](branchCount);

        // populate return array
        uint256 index = 0;
        uint64 currentBranch = branchs[SENTINEL_BRANCH];
        while (currentBranch != SENTINEL_BRANCH) {
            arrayChainId[index] = currentBranch;
            currentBranch = branchs[currentBranch];
            index++;
        }
        return arrayChainId;
    }

    // Handle message from branch
    function handleBranchMessage(uint64 branchChainId, bytes memory message) override internal { 
        Codec.TAG tag = Codec.getTag(message);
        if (Codec.compareTag(tag, Codec.DEPOSITE_TAG)) { // 只允许存款和跨链
            handleDeposite(branchChainId, message);
        } else if (Codec.compareTag(tag, Codec.DEPOSITE_AND_WITHDRAW_TAG)) {
            handleDepositeAndWithdraw(branchChainId, message);
        } else {
            revert("Unknown tag");
        }
    }

    function checkMessage(uint64 fromChainId, bytes memory message) internal returns(bool isValid, string memory err) {
        if (messageFilter != address(0)) {
            return IMessageFilter(messageFilter).handleMessage(fromChainId, message);
        }
        return (true, "");
    }

    // refundAddres is user origin chain address
    function handleRelayInterrupted(bytes memory zionReceiveAddressBytes, uint64 branchChainId, bytes memory refundAddress, uint amount, string memory err) internal {
        if (zionReceiveAddressBytes.length == 20) {
            address zionReceiveAddress = Utils.bytesToAddress(zionReceiveAddressBytes);
            _mint(zionReceiveAddress, amount);
            emit RelayInterrupted(branchChainId, zionReceiveAddress, amount, err);
        } else {
            bytes memory rollBackData = Codec.encodeRollBackMessage(refundAddress, amount);
            sendMessageToBranch(branchChainId, rollBackData);
            emit RollBackEvent(branchChainId, refundAddress, amount, err);
        }
    }

    function sendRollBackToBranch(uint64 branchChainId, bytes memory refundAddress, uint amount, string memory err) internal {
        bytes memory rollBackData = Codec.encodeRollBackMessage(refundAddress, amount);
        sendMessageToBranch(branchChainId, rollBackData);
        emit RollBackEvent(branchChainId, refundAddress, amount, err);
    }

    function sendWithdrawToBranch(uint64 toChainId, bytes memory toAddress, uint amount) internal {
        bytes memory withdrawData = Codec.encodeWithdrawMessage(toAddress, amount);
        sendMessageToBranch(toChainId, withdrawData);
        emit WithdrawEvent(toChainId, toAddress, amount);
    }

    function handleDeposite(uint64 fromChainId, bytes memory message) internal {
        // toAddress is address at zion. refundAddress is source chain address(may be it should be msg.sender)
        (bytes memory toAddressBytes, bytes memory refundAddress, uint256 amount) = Codec.decodeDepositeMessage(message);
        (bool isValidMessage, string memory err) = checkMessage(fromChainId, message);
        if (!isValidMessage) {
            sendRollBackToBranch(fromChainId, refundAddress, amount, string.concat("deposite error: ", err));
            return;
        }
        chainLiquidityMap[fromChainId] += amount;
        address toAddress = Utils.bytesToAddress(toAddressBytes);
        _mint(toAddress, amount);
        emit DepositeEvent(fromChainId, toAddress, amount);
    }

    // 调用handleDepositeAndWithdraw之后，relayer最终会调用到side chain得vault中handleCoreMessage
    function handleDepositeAndWithdraw(uint64 fromChainId, bytes memory message) internal {
        (bytes memory toAddress, bytes memory refundAddress, bytes memory zionReceiveAddress, uint64 toChainId, uint256 amount) = Codec.decodeDepositeAndWithdrawMessage(message);
        (bool isValidMessage, string memory err) = checkMessage(fromChainId, message);
        if (!isValidMessage) {
            sendRollBackToBranch(fromChainId, refundAddress, amount, string.concat("deposite_&_withdraw error: ", err));
            return;
        }
        if (paused()) {
            sendRollBackToBranch(fromChainId, refundAddress, amount, string.concat("deposite_&_withdraw error: root contract is paused"));
            return;
        }
        bytes memory toBranch = branchMap[toChainId];
        if (toBranch.length == 0) {
            handleRelayInterrupted(zionReceiveAddress, fromChainId, refundAddress, amount, "deposite_&_withdraw error: invalid toBranch");
            return;
        }

        // 每种underlying token在其各个侧链上vault中锁着的数量与其对应的pegToken chainLiquidityMap 中记录的、按pegToken换算的数量严格一致
        if (chainLiquidityMap[toChainId] < amount) {
            handleRelayInterrupted(zionReceiveAddress, fromChainId, refundAddress, amount, "deposite_&_withdraw error: target chain do not have enough liquidity");
            return;
        }
        chainLiquidityMap[fromChainId] += amount;
        chainLiquidityMap[toChainId] -= amount;
        emit DepositeEvent(fromChainId, address(0), amount);
        sendWithdrawToBranch(toChainId, toAddress, amount);
    }
}


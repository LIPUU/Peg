pragma solidity ^0.8.8;

import "../interfaces/ICrossChainManager.sol";
import "../libs/token/ERC20/utils/SafeERC20.sol";
import "../libs/token/ERC20/IERC20.sol";
import "../libs/token/ERC20/ERC20.sol";
import "../libs/security/ReentrancyGuard.sol";
import "../libs/security/Pausable.sol";
import "../libs/utils/Utils.sol";
import "../interfaces/ICrossChainManager.sol";
import "./CrossChainGovernance.sol";
import "./Codec.sol";

contract Vault is Branch, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    address public underlyingToken;
    uint8 public underlyingTokenDecimals;
    uint8 constant PEG_TOKEN_DECIMALS = 18;
    address constant ETH_ADDRESS = address(0);

    constructor(address _managerContractAddress, address _tokenUnderlying, bytes memory _coreAddress, uint64 _coreChainId) {
        managerContractAddress = _managerContractAddress;
        coreAddress = _coreAddress;
        coreChainId = _coreChainId;
        underlyingToken = _tokenUnderlying;
        if (_tokenUnderlying == ETH_ADDRESS) {
            underlyingTokenDecimals = 18;
        } else {
            underlyingTokenDecimals = ERC20(_tokenUnderlying).decimals();
        }
    }

    event DepositeAndWithdrawEvent(address fromAddress, address refundAddress, bytes zionReceiveAddress, bytes toAddress, uint64 toChainId, uint256 amount, uint256 pegAmount);
    event DepositeEvent(address fromAddress, address refundAddress, bytes toAddress, uint256 amount, uint256 pegAmount);
    event WithdrawEvent(address toAddress, uint256 amount, uint256 pegAmount);
    event RollBackEvent(address refundAddress, uint amount, uint256 pegAmount);

    function deposite(address refundAddress, bytes memory toAddress, uint256 amount) public payable nonReentrant whenNotPaused {
        uint256 pegAmount = rounding(amount, false);

        require(pegAmount != 0, "amount cannot be zero!");
        
        _transferToContract(amount);
        
        sendMessageToCore(Codec.encodeDepositeMessage(toAddress, Utils.addressToBytes(refundAddress), pegAmount));

        emit DepositeEvent(msg.sender, refundAddress, toAddress, amount, pegAmount);
    }

    // when withdraw failed, if `zionReceiveAddress` is valid zion address, fund will be sent to given address in zion, otherwise it will be sent back to refundAddress in source chain 
    function depositeAndWithdraw(address refundAddress, bytes memory zionReceiveAddress, bytes memory toAddress, uint64 toChainId, uint256 amount) public payable nonReentrant whenNotPaused {
        uint256 pegAmount = rounding(amount, false);

        require(pegAmount != 0, "amount cannot be zero!");
        
        _transferToContract(amount);
        
        sendMessageToCore(Codec.encodeDepositeAndWithdrawMessage(toAddress, Utils.addressToBytes(refundAddress), zionReceiveAddress, toChainId, pegAmount));

        emit DepositeAndWithdrawEvent(msg.sender, refundAddress, zionReceiveAddress, toAddress, toChainId, amount, pegAmount);
    }

    function handleCoreMessage(bytes memory message) override internal {
        Codec.TAG tag = Codec.getTag(message);
        if (Codec.compareTag(tag, Codec.WITHDRAW_TAG)) {
            (bytes memory toAddressBytes, uint pegAmount) = Codec.decodeWithdrawMessage(message);
            uint256 amount = rounding(pegAmount, true); 
            address toAddress = Utils.bytesToAddress(toAddressBytes);
            _transferFromContract(toAddress, amount);
            emit WithdrawEvent(toAddress, amount, pegAmount);
        } else if (Codec.compareTag(tag, Codec.ROLLBACK_TAG)) {
            (bytes memory refundAddressBytes, uint pegAmount) = Codec.decodeRollBackMessage(message);
            uint256 amount = rounding(pegAmount, true); 
            address refundAddress = Utils.bytesToAddress(refundAddressBytes);
            _transferFromContract(refundAddress, amount);
            emit RollBackEvent(refundAddress, amount, pegAmount);
        } else if (Codec.compareTag(tag, Codec.PAUSE_TAG)) {
            bool needWait = Codec.decodePauseMessage(message);
            if (paused()) {
                require(!needWait, "vault is paused! wait until its not paused");
            } else {
                _pause();
            }
        } else if (Codec.compareTag(tag, Codec.UNPAUSE_TAG)) {
            bool needWait = Codec.decodeUnpauseMessage(message);
            if (!paused()) {
                require(!needWait, "vault is not paused! wait until its paused");
            } else {
                _unpause();
            }
        } else {
            revert("Unknown message tag");
        }
    }

    function _transferToContract(uint256 amount) internal {
        address token = underlyingToken;
        if (token == ETH_ADDRESS) {
            require(msg.value != 0, "transferred ether cannot be zero!");
            require(msg.value == amount, "transferred ether is not equal to amount!");
        } else {
            require(msg.value == 0, "there should be no ether transfer!");
            IERC20 erc20Token = IERC20(token);
            erc20Token.safeTransferFrom(token, msg.sender, amount);
        }
    }

    function _transferFromContract(address toAddress, uint256 amount) internal {
        address token = underlyingToken;
        if (token == ETH_ADDRESS) {
            payable(address(uint160(toAddress))).transfer(amount);
        } else {
            IERC20 erc20Token = IERC20(token);
            erc20Token.safeTransfer(toAddress, amount);
        }
    }

    function rounding(uint256 amount, bool fromPegTokenDecimals) internal view returns(uint256) {
        if (fromPegTokenDecimals) {
            if (underlyingTokenDecimals < PEG_TOKEN_DECIMALS) {
                return amount / 10**(PEG_TOKEN_DECIMALS - underlyingTokenDecimals);
            } else {
                return amount * 10**(underlyingTokenDecimals - PEG_TOKEN_DECIMALS);
            }
        } else {
            if (underlyingTokenDecimals < PEG_TOKEN_DECIMALS) {
                return amount * 10**(PEG_TOKEN_DECIMALS - underlyingTokenDecimals);
            } else {
                return amount / 10**(underlyingTokenDecimals - PEG_TOKEN_DECIMALS);
            }
        }
    }
}
pragma solidity ^0.8.0;

import "../libs/common/ZeroCopySink.sol";
import "../libs/common/ZeroCopySource.sol";

library Codec {

    type TAG is bytes1;

    TAG constant PAUSE_TAG = TAG.wrap(0x01);
    TAG constant UNPAUSE_TAG = TAG.wrap(0x02);
    TAG constant ROLLBACK_TAG = TAG.wrap(0x03);
    TAG constant DEPOSITE_TAG = TAG.wrap(0x04);
    TAG constant WITHDRAW_TAG = TAG.wrap(0x05);
    TAG constant DEPOSITE_AND_WITHDRAW_TAG = TAG.wrap(0x06);

    function getTag(bytes memory message) pure public returns(TAG) {
        return TAG.wrap(message[0]);
    }

    // return true is tag1 == tag2
    function compareTag(TAG tag1, TAG tag2) pure public returns(bool) {
        return TAG.unwrap(tag1) == TAG.unwrap(tag2);
    }



    function encodePauseMessage(bool needWait) pure public returns(bytes memory) {
        bytes memory buff;
        buff = abi.encodePacked(
            PAUSE_TAG,
            ZeroCopySink.WriteBool(needWait)
            );
        return buff;
    }
    function decodePauseMessage(bytes memory rawData) pure public returns(bool needWait) {
        require(compareTag(getTag(rawData), PAUSE_TAG), "Not pause message");
        (needWait, ) = ZeroCopySource.NextBool(rawData, 1);
    }



    function encodeUnpauseMessage(bool needWait) pure public returns(bytes memory) {
        bytes memory buff;
        buff = abi.encodePacked(
            UNPAUSE_TAG,
            ZeroCopySink.WriteBool(needWait)
            );
        return buff;
    }
    function decodeUnpauseMessage(bytes memory rawData) pure public returns(bool needWait) {
        require(compareTag(getTag(rawData), UNPAUSE_TAG), "Not unpause message");
        (needWait, ) = ZeroCopySource.NextBool(rawData, 1);
    }



    function encodeRollBackMessage(bytes memory refundAddress, uint amount) pure public returns(bytes memory) {
        bytes memory buff;
        buff = abi.encodePacked(
            ROLLBACK_TAG,
            ZeroCopySink.WriteVarBytes(refundAddress),
            ZeroCopySink.WriteUint255(amount)
            );
        return buff;
    }
    function decodeRollBackMessage(bytes memory rawData) pure public returns(bytes memory refundAddress, uint amount) {
        require(compareTag(getTag(rawData), ROLLBACK_TAG), "Not rollback message");
        uint256 off = 1;
        (refundAddress, off) = ZeroCopySource.NextVarBytes(rawData, off);
        (amount, off) = ZeroCopySource.NextUint255(rawData, off);
    }



    function encodeDepositeMessage(bytes memory toAddress, bytes memory refundAddress, uint256 amount) pure public returns(bytes memory) {
        bytes memory buff;
        buff = abi.encodePacked(
            DEPOSITE_TAG,
            ZeroCopySink.WriteVarBytes(toAddress),
            ZeroCopySink.WriteVarBytes(refundAddress),
            ZeroCopySink.WriteUint255(amount)
            );
        return buff;
    }
    function decodeDepositeMessage(bytes memory rawData) pure public returns(bytes memory toAddress, bytes memory refundAddress, uint256 amount) {
        require(compareTag(getTag(rawData), DEPOSITE_TAG), "Not deposite message");
        uint256 off = 1;
        (toAddress, off) = ZeroCopySource.NextVarBytes(rawData, off);
        (refundAddress, off) = ZeroCopySource.NextVarBytes(rawData, off);
        (amount, off) = ZeroCopySource.NextUint255(rawData, off);
    }



    function encodeWithdrawMessage(bytes memory toAddress, uint256 amount) pure public returns(bytes memory) {
        bytes memory buff;
        buff = abi.encodePacked(
            WITHDRAW_TAG,
            ZeroCopySink.WriteVarBytes(toAddress),
            ZeroCopySink.WriteUint255(amount)
            );
        return buff;
    }
    function decodeWithdrawMessage(bytes memory rawData) pure public returns(bytes memory toAddress, uint256 amount) {
        require(compareTag(getTag(rawData), WITHDRAW_TAG), "Not withdraw message");
        uint256 off = 1;
        (toAddress, off) = ZeroCopySource.NextVarBytes(rawData, off);
        (amount, off) = ZeroCopySource.NextUint255(rawData, off);
    }



    function encodeDepositeAndWithdrawMessage(bytes memory toAddress, bytes memory refundAddress, bytes memory zionReceiveAddress, uint64 toChainId, uint256 amount) pure public returns(bytes memory) {
        bytes memory buff;
        buff = abi.encodePacked(
            DEPOSITE_AND_WITHDRAW_TAG,
            ZeroCopySink.WriteVarBytes(toAddress),
            ZeroCopySink.WriteVarBytes(refundAddress),
            ZeroCopySink.WriteVarBytes(zionReceiveAddress),
            ZeroCopySink.WriteUint64(toChainId),
            ZeroCopySink.WriteUint255(amount)
            );
        return buff;
    }
    function decodeDepositeAndWithdrawMessage(bytes memory rawData) pure public returns(bytes memory toAddress, bytes memory refundAddress, bytes memory zionReceiveAddress, uint64 toChainId, uint256 amount) {
        require(compareTag(getTag(rawData), DEPOSITE_AND_WITHDRAW_TAG), "Not deposite_and_withdraw message");
        uint256 off = 1;
        (toAddress, off) = ZeroCopySource.NextVarBytes(rawData, off);
        (refundAddress, off) = ZeroCopySource.NextVarBytes(rawData, off);
        (zionReceiveAddress, off) = ZeroCopySource.NextVarBytes(rawData, off);
        (toChainId, off) = ZeroCopySource.NextUint64(rawData, off);
        (amount, off) = ZeroCopySource.NextUint255(rawData, off);
    }
}
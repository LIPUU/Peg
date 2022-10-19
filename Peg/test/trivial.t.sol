// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "core/Codec.sol";

contract CodecTest is Test {
    uint8 constant PEG_TOKEN_DECIMALS = 18;
    function setUp() public {
        
    }

    function bytesToAddress(bytes memory _bs) internal pure returns (address addr)
    {
        require(_bs.length == 20, "bytes length does not match address");
        assembly {
            // for _bs, first word store _bs.length, second word store _bs.value
            // load 32 bytes from mem[_bs+20], convert it into Uint160, meaning we take last 20 bytes as addr (address).
            addr := mload(add(_bs, 0x14))
        }

    }

    function testEncodeAndDecodeDepositMessage() public {
        address myAddress=0xf9d7A0DcE38C55039457B6ac3c275429f2E5DF0D;
        bytes memory toAddress_zion=abi.encodePacked(myAddress);
        bytes memory refoundAddress_sourceChain=abi.encodePacked(myAddress);
        bytes memory encodedDepositMessage = Codec.encodeDepositeMessage(toAddress_zion,refoundAddress_sourceChain,10 ether);

        (bytes memory _toAddress_zion,bytes memory _refoundAddress_sourceChain,uint _amount)=Codec.decodeDepositeMessage(encodedDepositMessage);

        assertEq(toAddress_zion,_toAddress_zion);
        assertEq(refoundAddress_sourceChain,_refoundAddress_sourceChain);
        assertEq(10 ether,_amount);

        Codec.TAG tag = Codec.getTag(encodedDepositMessage);
        assertTrue(Codec.compareTag(tag, Codec.DEPOSITE_TAG));
    }

    function testBytesToAddress(address addr) public {
        bytes memory _addr=abi.encodePacked(addr);
        assertEq(bytesToAddress(_addr),addr);
    }

    function rounding(uint8 underlyingTokenDecimals,uint256 amount, bool fromPegTokenDecimals) internal pure returns(uint256) {
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

    function testRounding() public {
        uint source_to_peg_amount = rounding(6,10000*10**6,false);
        uint peg_to_source_amount = rounding(8,source_to_peg_amount,true);
        console.log(source_to_peg_amount);
        console.log(peg_to_source_amount);
    }

    // export FOUNDRY_FUZZ_RUNS=100000
    // that will fuzzing 100000 times
    // function test_FUZZING_Rounding_(uint8 _decimals,uint96 before_amount) public {
    //     uint8 decimals=_decimals%18;
    //     uint after_amout=rounding(decimals,rounding(decimals,before_amount,false),true);
    //     assertEq(before_amount,after_amout);
    //     console.log(before_amount);
    //     console.log(after_amout);
    // }
    
}

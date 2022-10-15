// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "core/Vault.sol";
import "core/ZionPegToken.sol";
import {ERC20Template} from "test/token/ERC20Template.sol"; 
import {ManagerContractMock,MockChainIDChannel} from "./ManagerContractMock.sol";
import "forge-std/console.sol";

contract VaultTest is Test {
    address deployer=vm.addr(1);
    address user1_EVM=vm.addr(0x60);
    address user2_EVM=vm.addr(0x62);
    address user1_Zion=vm.addr(0x63);
    address user2_Zion=vm.addr(0x64);

    ManagerContractMock managerContractMock;
    
    uint64 coreChainId = 1;
    
    ERC20Template usdt_sourceChainId5;
    Vault usdt_vault_sourceChainId_5;
    ERC20Template usdt_sourceChainId6;
    Vault usdt_vault_sourceChainId_6;

    ZionPegToken PegUSDT;
    ZionPegToken PegETH;
    MockChainIDChannel mockChainIDChannel;

    function setUp() public {
        vm.startPrank(deployer);
        
        mockChainIDChannel=new MockChainIDChannel();
        managerContractMock=new ManagerContractMock(mockChainIDChannel);

        PegUSDT=new ZionPegToken("TetherUSD","usdt");
        PegETH = new ZionPegToken("ZionETH","eth");
        
        PegUSDT.setManagerContract(address(managerContractMock));
        PegUSDT.setManagerContract(address(managerContractMock));

        usdt_sourceChainId5 = new ERC20Template("TetherUSD","usdt",6);
        usdt_sourceChainId6 = new ERC20Template("TetherUSD","usdt",18);

        usdt_vault_sourceChainId_5 = new Vault(address(managerContractMock),address(usdt_sourceChainId5),abi.encode(address(PegUSDT)),coreChainId);
        usdt_vault_sourceChainId_6 = new Vault(address(managerContractMock),address(usdt_sourceChainId6),abi.encode(address(PegUSDT)),coreChainId);

        usdt_sourceChainId5.initialize();
        usdt_sourceChainId6.initialize();

        uint64[] memory chainIDs=new uint64[](2);
        bytes[] memory vaultsAddresses=new bytes[](2);
        chainIDs[0]=5;
        chainIDs[1]=6;
        vaultsAddresses[0]=abi.encodePacked(address(usdt_vault_sourceChainId_5));
        vaultsAddresses[1]=abi.encodePacked(address(usdt_vault_sourceChainId_6));
        PegUSDT.bindBranchBatch(chainIDs,vaultsAddresses);
        
        vm.stopPrank();
    }

    function helper_initState_1() public {
        vm.startPrank(deployer);

        usdt_sourceChainId5.transfer(user1_EVM,10000 ether);
        usdt_sourceChainId5.transfer(user2_EVM,10000 ether);
        usdt_sourceChainId5.transfer(address(usdt_vault_sourceChainId_5),10000 ether);

        usdt_sourceChainId6.transfer(user1_EVM,10000 ether);
        usdt_sourceChainId6.transfer(user2_EVM,10000 ether);
        usdt_sourceChainId6.transfer(address(usdt_vault_sourceChainId_6),10000 ether);

        vm.stopPrank();
        
        assertEq(usdt_sourceChainId5.balanceOf(user1_EVM),10000 ether);
        assertEq(usdt_sourceChainId5.balanceOf(user2_EVM),10000 ether);
        assertEq(usdt_sourceChainId6.balanceOf(user1_EVM),10000 ether);
        assertEq(usdt_sourceChainId6.balanceOf(user2_EVM),10000 ether);
        assertEq(usdt_sourceChainId5.balanceOf(address(usdt_vault_sourceChainId_5)),10000 ether);
        assertEq(usdt_sourceChainId6.balanceOf(address(usdt_vault_sourceChainId_6)),10000 ether);
        assertEq(usdt_sourceChainId5.totalSupply()-3*10000 ether,usdt_sourceChainId5.balanceOf(deployer));
        assertEq(usdt_sourceChainId6.totalSupply()-3*10000 ether,usdt_sourceChainId6.balanceOf(deployer));
    }
    function helper_rounding(uint8 underlyingTokenDecimals,uint256 amount, bool fromPegTokenDecimals) internal pure returns(uint256) {
        uint8 PEG_TOKEN_DECIMALS = 18;
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

    // FUZZING
    function testDepositeERC20TokenSuccess(uint96 _usdt_chainID5_cross_amount,uint96 _usdt_chainID6_cross_amount) public {
        helper_initState_1();

        uint usdt_chainID5_cross_amount = uint(_usdt_chainID5_cross_amount % 10000 ether)+1;
        uint usdt_chainID6_cross_amount = uint(_usdt_chainID6_cross_amount % 10000 ether)+1;

        vm.startPrank(user1_EVM);

        // user1_EVM address before status on source chain && zion
        uint before_balance_user1_EVM_at_evm = usdt_sourceChainId5.balanceOf(user1_EVM);
        uint before_balance_user1_Zion_at_zion = PegUSDT.balanceOf(user1_Zion);
        assertEq(before_balance_user1_Zion_at_zion,0);

        // zion-usdtPeg  before status on zion
        uint before_totalSupply = PegUSDT.totalSupply();
        uint before_chainLiquidity_at_chainID_5 = PegUSDT.chainLiquidityMap(5);
        uint before_chainLiquidity_at_chainID_6 = PegUSDT.chainLiquidityMap(6);
        assertEq(before_totalSupply,0);
        assertEq(before_chainLiquidity_at_chainID_5,0);
        assertEq(before_chainLiquidity_at_chainID_6,0);

        // ! deposit operation !
        usdt_sourceChainId5.approve(address(usdt_vault_sourceChainId_5), usdt_chainID5_cross_amount );
        mockChainIDChannel.setCurrentlyChainID(5);
        usdt_vault_sourceChainId_5.deposite(user1_EVM,abi.encodePacked(user1_Zion), usdt_chainID5_cross_amount );
        vm.stopPrank();

        // user1_EVM address after status on source chain && zion
        uint after_balance_user1_EVM_at_evm = usdt_sourceChainId5.balanceOf(user1_EVM);
        uint after_balance_user1_Zion_at_zion = PegUSDT.balanceOf(user1_Zion);
        assertEq(PegUSDT.balanceOf(user1_EVM),0, "after deposit balance of user1_EVM at zion should be zero!" );

        // zion-usdtPeg  after status on zion
        uint after_totalSupply = PegUSDT.totalSupply();
        uint after_chainLiquidity_at_chainID_5 = PegUSDT.chainLiquidityMap(5);
        assertEq( PegUSDT.chainLiquidityMap(6),0,"after deposit chainLiquidity of chainID_6 should be zero!" );

        assertEq(after_balance_user1_EVM_at_evm, before_balance_user1_EVM_at_evm - usdt_chainID5_cross_amount , 
                "#ERROR# after deposits user1_EVM's PegUSDT amount is incorrect!");

        uint side_chain_amount_convert_to_PegToken_amount = helper_rounding(6,usdt_chainID5_cross_amount,false);

        assertEq(after_balance_user1_Zion_at_zion, before_balance_user1_Zion_at_zion + side_chain_amount_convert_to_PegToken_amount , 
                "#ERROR# after deposits user1_zion's PegUSDT amounts is incorrect!");

        assertEq(after_totalSupply, before_totalSupply + side_chain_amount_convert_to_PegToken_amount, 
                "#ERROR# after deposits PegUSDT total supply is incorrect!");

        assertEq(after_chainLiquidity_at_chainID_5, before_chainLiquidity_at_chainID_5 + side_chain_amount_convert_to_PegToken_amount, 
                "#ERROR# after deposits PegUSDT chainLiquidity is incorrect!");
        
    }

    function testDepositeNativeTokenSuccess() public {
        
    }

}

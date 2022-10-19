// -------------deprecated------------- //

// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "forge-std/Test.sol";
// import "core/Vault.sol";
// import "core/ZionPegToken.sol";
// import {ERC20Template} from "test/token/ERC20Template.sol"; 
// import {ManagerContractMock,MockChainIDChannel} from "./ManagerContractMock.sol";
// import "forge-std/console.sol";

// contract VaultTest is Test {
//     address deployer=vm.addr(1);
//     address user1_EVM_5=vm.addr(0x60);
//     address user2_EVM_5=vm.addr(0x62);
//     address user1_Zion=vm.addr(0x63);
//     address user2_Zion=vm.addr(0x64);
//     address user1_EVM_6=vm.addr(0x100);
//     address user2_EVM_6=vm.addr(0x101);

//     ManagerContractMock managerContractMock;
    
//     uint64 coreChainId = 1;
    
//     ERC20Template usdt_chainId5;
//     Vault usdt_vault_chainId_5;
//     ERC20Template usdt_chainId6;
//     Vault usdt_vault_chainId_6;

//     ZionPegToken PegUSDT;
//     ZionPegToken PegETH;
//     MockChainIDChannel mockChainIDChannel;

//     function setUp() public {
//         vm.startPrank(deployer);
        
//         mockChainIDChannel=new MockChainIDChannel();
//         managerContractMock=new ManagerContractMock(mockChainIDChannel);

//         PegUSDT=new ZionPegToken("TetherUSD","usdt");
//         PegETH = new ZionPegToken("ZionETH","eth");

//         PegUSDT.setManagerContract(address(managerContractMock));
//         PegUSDT.setManagerContract(address(managerContractMock));

//         usdt_chainId5 = new ERC20Template("TetherUSD","usdt",6);
//         usdt_chainId6 = new ERC20Template("TetherUSD","usdt",18);

//         usdt_vault_chainId_5 = new Vault(address(managerContractMock),address(usdt_chainId5),abi.encode(address(PegUSDT)),coreChainId);
//         usdt_vault_chainId_6 = new Vault(address(managerContractMock),address(usdt_chainId6),abi.encode(address(PegUSDT)),coreChainId);

//         uint64[] memory chainIDs=new uint64[](2);
//         bytes[] memory vaultsAddresses=new bytes[](2);
//         chainIDs[0]=5;
//         chainIDs[1]=6;
//         vaultsAddresses[0]=abi.encodePacked(address(usdt_vault_chainId_5));
//         vaultsAddresses[1]=abi.encodePacked(address(usdt_vault_chainId_6));
//         PegUSDT.bindBranchBatch(chainIDs,vaultsAddresses);
        
//         vm.stopPrank();
//     }

//     function helper_initState_1() public {
//         vm.startPrank(deployer);
//         usdt_chainId5.transfer(user1_EVM_5, 10000*10**6);
//         usdt_chainId5.transfer(user2_EVM_5, 10000*10**6);
//         usdt_chainId5.approve(address(usdt_vault_chainId_5), 10000*10**6 );
//         mockChainIDChannel.setCurrentlyChainID(5);
//         usdt_vault_chainId_5.deposite(deployer,abi.encodePacked(deployer), 10000*10**6 );

//         usdt_chainId6.transfer(user1_EVM_6,10000 ether);
//         usdt_chainId6.transfer(user2_EVM_6,10000 ether);
//         usdt_chainId6.approve(address(usdt_vault_chainId_6), 10000 ether );
//         mockChainIDChannel.setCurrentlyChainID(6);
//         usdt_vault_chainId_6.deposite(deployer,abi.encodePacked(deployer), 10000 ether );
//         vm.stopPrank();
        
//         assertEq(usdt_chainId5.balanceOf(user1_EVM_5),10000*10**6);
//         assertEq(usdt_chainId5.balanceOf(user2_EVM_5),10000*10**6);
//         assertEq(usdt_chainId6.balanceOf(user1_EVM_6),10000 ether);
//         assertEq(usdt_chainId6.balanceOf(user2_EVM_6),10000 ether);
//         assertEq(usdt_chainId5.balanceOf(address(usdt_vault_chainId_5)),10000*10**6);
//         assertEq(usdt_chainId6.balanceOf(address(usdt_vault_chainId_6)),10000 ether);

//         assertEq(PegUSDT.chainLiquidityMap(5),helper_rounding(6,10000*10**6,false));
//         assertEq(PegUSDT.chainLiquidityMap(6),helper_rounding(18,10000 ether,false));
//     }
//     function helper_rounding(uint8 underlyingTokenDecimals,uint256 amount, bool fromPegTokenDecimals) internal pure returns(uint256) {
//         uint8 PEG_TOKEN_DECIMALS = 18;
//         if (fromPegTokenDecimals) {
//             if (underlyingTokenDecimals < PEG_TOKEN_DECIMALS) {
//                 return amount / 10**(PEG_TOKEN_DECIMALS - underlyingTokenDecimals);
//             } else {
//                 return amount * 10**(underlyingTokenDecimals - PEG_TOKEN_DECIMALS);
//             }
//         } else {
//             if (underlyingTokenDecimals < PEG_TOKEN_DECIMALS) {
//                 return amount * 10**(PEG_TOKEN_DECIMALS - underlyingTokenDecimals);
//             } else {
//                 return amount / 10**(underlyingTokenDecimals - PEG_TOKEN_DECIMALS);
//             }
//         }
//     }

//     // FUZZING
//     function testDepositeERC20TokenSuccess(uint96 _usdt_chainID5_cross_amount,uint96 _usdt_chainID6_cross_amount) public {
//         helper_initState_1();

//         uint usdt_chainID5_cross_amount = uint(_usdt_chainID5_cross_amount % 10000*10*6)+1;
//         uint usdt_chainID6_cross_amount = uint(_usdt_chainID6_cross_amount % 10000 ether)+1;

//         vm.startPrank(user1_EVM_5);

//         // user1_EVM_5 address before status on source chain && zion
//         uint before_balance_user1_EVM_5_at_evm = usdt_chainId5.balanceOf(user1_EVM_5);
//         uint before_balance_user1_Zion_at_zion = PegUSDT.balanceOf(user1_Zion);
//         assertEq(before_balance_user1_Zion_at_zion,0);

//         // zion-usdtPeg  before status on zion
//         uint before_totalSupply = PegUSDT.totalSupply();
//         uint before_chainLiquidity_at_chainID_5 = PegUSDT.chainLiquidityMap(5);
//         uint before_chainLiquidity_at_chainID_6 = PegUSDT.chainLiquidityMap(6);
//         assertEq(before_totalSupply,PegUSDT.balanceOf(deployer));
        

//         // ! deposit operation !
//         usdt_chainId5.approve(address(usdt_vault_chainId_5), usdt_chainID5_cross_amount );
//         mockChainIDChannel.setCurrentlyChainID(5);
//         usdt_vault_chainId_5.deposite(user1_EVM_5,abi.encodePacked(user1_Zion), usdt_chainID5_cross_amount );
//         vm.stopPrank();

//         // user1_EVM_5 address after status on source chain && zion
//         uint after_balance_user1_EVM_5_at_evm = usdt_chainId5.balanceOf(user1_EVM_5);
//         uint after_balance_user1_Zion_at_zion = PegUSDT.balanceOf(user1_Zion);

//         // zion-usdtPeg  after states on zion
//         uint after_totalSupply = PegUSDT.totalSupply();
//         uint after_chainLiquidity_at_chainID_5 = PegUSDT.chainLiquidityMap(5);
        
//         assertEq(after_balance_user1_EVM_5_at_evm, before_balance_user1_EVM_5_at_evm - usdt_chainID5_cross_amount , 
//                 "#ERROR# after deposits user1_EVM_5's PegUSDT amount is incorrect!");

//         uint side_chain_amount_convert_to_PegToken_amount = helper_rounding(6,usdt_chainID5_cross_amount,false);

//         assertEq(after_balance_user1_Zion_at_zion, before_balance_user1_Zion_at_zion + side_chain_amount_convert_to_PegToken_amount , 
//                 "#ERROR# after deposits user1_zion's PegUSDT amounts is incorrect!");

//         assertEq(after_totalSupply, before_totalSupply + side_chain_amount_convert_to_PegToken_amount, 
//                 "#ERROR# after deposits PegUSDT total supply is incorrect!");

//         assertEq(after_chainLiquidity_at_chainID_5, before_chainLiquidity_at_chainID_5 + side_chain_amount_convert_to_PegToken_amount, 
//                 "#ERROR# after deposits PegUSDT chainLiquidity is incorrect!");
        
//     }

//     // 
//     function testDepositeAndWithDrawERC20TokenSuccess(uint96 _usdt_chainID5_cross_amount) public {
//         helper_initState_1();

//         uint usdt_chainID5_cross_amount = uint(_usdt_chainID5_cross_amount % 10000*10*6)+1;

//         vm.startPrank(user1_EVM_5);

//         // user1_EVM_5 && EVM6 && zion
//         uint before_balance_user1_EVM_5_at_evm = usdt_chainId5.balanceOf(user1_EVM_5);
//         uint before_balance_user1_EVM_6_at_evm = usdt_chainId6.balanceOf(user1_EVM_6);
//         uint before_balance_user1_Zion_at_zion = PegUSDT.balanceOf(user1_Zion);
//         uint before_balance_usdt_vault_at_chainId5 = usdt_chainId5.balanceOf(address(usdt_vault_chainId_5));
//         uint before_balance_usdt_vault_at_chainId6 = usdt_chainId6.balanceOf(address(usdt_vault_chainId_6));
//         assertEq(before_balance_user1_Zion_at_zion,0);

//         // zion-usdtPeg  before status on zion
//         uint before_totalSupply = PegUSDT.totalSupply();
//         uint before_chainLiquidity_at_chainID_5 = PegUSDT.chainLiquidityMap(5);
//         uint before_chainLiquidity_at_chainID_6 = PegUSDT.chainLiquidityMap(6);
//         assertEq(before_totalSupply,PegUSDT.balanceOf(deployer));

//         // ! depositAndWitdraw operation !
//         // (address refundAddress, bytes memory zionReceiveAddress, bytes memory toAddress, uint64 toChainId, uint256 amount)
//         usdt_chainId5.approve(address(usdt_vault_chainId_5), usdt_chainID5_cross_amount );
//         mockChainIDChannel.setCurrentlyChainID(5);
//         usdt_vault_chainId_5.depositeAndWithdraw(user1_EVM_5,abi.encodePacked(user1_Zion), abi.encodePacked(user1_EVM_6),6,usdt_chainID5_cross_amount );
//         vm.stopPrank();

//         uint after_balance_user1_EVM_5_at_evm = usdt_chainId5.balanceOf(user1_EVM_5);
//         uint after_balance_user1_EVM_6_at_evm = usdt_chainId6.balanceOf(user1_EVM_6);
//         uint after_balance_user1_Zion_at_zion = PegUSDT.balanceOf(user1_Zion);
//         uint after_balance_usdt_vault_at_chainId5 = usdt_chainId5.balanceOf(address(usdt_vault_chainId_5));
//         uint after_balance_usdt_vault_at_chainId6 = usdt_chainId6.balanceOf(address(usdt_vault_chainId_6));
//         uint after_totalSupply = PegUSDT.totalSupply();
//         uint after_chainLiquidity_at_chainID_5 = PegUSDT.chainLiquidityMap(5);
//         uint after_chainLiquidity_at_chainID_6 = PegUSDT.chainLiquidityMap(6);
        
//         assertEq(after_balance_user1_EVM_5_at_evm, before_balance_user1_EVM_5_at_evm - usdt_chainID5_cross_amount , 
//                 "#ERROR# after deposits user1_EVM_5's PegUSDT amount is incorrect!");

//         uint side_chain_amount_convert_to_PegToken_amount = helper_rounding(6,usdt_chainID5_cross_amount,false);
//         uint PegToken_amount_convert_to_side_chain_amount = helper_rounding(18,side_chain_amount_convert_to_PegToken_amount,true);

//         assertEq(after_balance_user1_EVM_6_at_evm, before_balance_user1_EVM_6_at_evm + PegToken_amount_convert_to_side_chain_amount);

//         assertEq(after_balance_user1_Zion_at_zion, before_balance_user1_Zion_at_zion,
//                 "#ERROR# after DW user1_zion's PegUSDT amounts is incorrect!");

//         assertEq(after_balance_usdt_vault_at_chainId5, before_balance_usdt_vault_at_chainId5 + usdt_chainID5_cross_amount,
//                 "#ERROR# after DW vault5 amounts in is incorrect!"
//         );

//         assertEq(after_balance_usdt_vault_at_chainId6, before_balance_usdt_vault_at_chainId6 - PegToken_amount_convert_to_side_chain_amount,
//                 "#ERROR# after DW vault5 amounts in is incorrect!"
//         );

//         assertEq(after_totalSupply, before_totalSupply + side_chain_amount_convert_to_PegToken_amount, 
//                 "#ERROR# after deposits PegUSDT total supply is incorrect!"
//         );

//         assertEq(after_chainLiquidity_at_chainID_5, before_chainLiquidity_at_chainID_5 + side_chain_amount_convert_to_PegToken_amount, 
//                 "#ERROR# after deposits PegUSDT chainLiquidity is incorrect!"
//         );

//         assertEq(after_chainLiquidity_at_chainID_6, before_chainLiquidity_at_chainID_6 - side_chain_amount_convert_to_PegToken_amount, 
//                 "#ERROR# after deposits PegUSDT chainLiquidity is incorrect!"
//         );
        
//     }
    

// }

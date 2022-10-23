// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "core/Vault.sol";
import "core/ZionPegToken.sol";
import {ERC20Template} from "test/token/ERC20Template.sol"; 
import {ManagerContractMock,MockChainIDChannel} from "./ManagerContractMock.sol";
import "forge-std/console.sol";
import {Helper} from "./helper.sol";
import "src/libs/token/ERC20/ERC20.sol";
import "./calHelper.sol";

contract AllTest is Test {
    uint constant USER_NUMBER = 100;
    address deployer = vm.addr(0x64);

    // assume 5 is Ethereum, 6 is Bsc, 7 is Polygon
    uint64[] chainIDs = [5,6,7];

    string[] nameAndSymbolOnEthereum = ["usdt_ethereum","usdc_ethereum"];
    string[] nameAndSymbolOnBsc=["ether_bsc","usdt_bsc","usdc_bsc"];
    string[] nameAndSymbolOnPolygon=["ether_polygon","usdt_polygon","usdc_polygon"];
    uint8[] decimalsOnEthereum=[6,6];
    uint8[] decimalsOnBsc=[18,18,18];
    uint8[] decimalsOnPolygon=[18,6,6];
    
    address[] users_on_ethereum;
    address[] users_on_bsc;
    address[] users_on_polygon;
    address[] users_on_zion;

    ERC20Template[] tokens; // side chain underlying tokens
    Vault[] vaults; // side chain vault
    ZionPegToken[] pegTokens;

    MockChainIDChannel mockChainIDChannel;
    ManagerContractMock managerContractMock;
    
    // users state on each blockChain. for example:
    // chainID => ( assetAddress  => ( user_address => balance ) )
    // chainID 1 is zion chain, chainID 5 6 7 is sideChain
    // assetAddress are sideChain vault address and zion PegAddress
    mapping(uint64 => mapping(address => mapping(address=>uint) ) ) userState;
    
    // sideChain vault state
    // chainID => vault address => balance
    mapping(uint64 => mapping(address=>uint)) vaultState;

    // zion state
    // one PegToken totalSupply
    mapping(address=>uint) PegTokensTotalSupplyState;
    // inner liquidity state of each PegToken of each side chain
    mapping(address=>mapping(uint64=>uint)) PegTokensSideChainLiquidity;

    using calHelper for mapping(uint64 =>mapping(address=>mapping(address=>uint))); // userState type
    using calHelper for mapping(uint64 =>mapping(address=>uint)); // vaultState type 
    using calHelper for mapping(address=>uint); // PegTokensTotalSupplyState type
    using calHelper for mapping(address=>mapping(uint64=>uint)); // PegTokensSideChainLiquidity type

    mapping(uint64=>mapping(uint8=>uint8)) decimalRecord;

                                                            // EVENT SCOPE //
    event DepositeEvent(address fromAddress, address refundAddress, bytes toAddress, uint256 amount, uint256 pegAmount);
    
                                                            // EVENT SCOPE //

    function setUp() public {
        mockChainIDChannel=new MockChainIDChannel();
        managerContractMock=new ManagerContractMock(mockChainIDChannel);

        vm.startPrank(deployer);
        // deploy token on ecah chain

        // deploy PegToken
        pegTokens = [new ZionPegToken("Ethereum","ether"),new ZionPegToken("usdt","usdt"),new ZionPegToken("usdc","usdc")];
        managerContractMock.bindPegToken(pegTokens);
        for (uint i =0;i<pegTokens.length;++i){
            pegTokens[i].setManagerContract(address(managerContractMock));
        }

        // deploy ether vault on ethereum
        vaults.push(new Vault(address(managerContractMock),address(0),abi.encodePacked(address(pegTokens[0])),1));
        for (uint i=0;i<decimalsOnEthereum.length; ++i) {
            ERC20Template token_=new ERC20Template(nameAndSymbolOnEthereum[i],nameAndSymbolOnEthereum[i],decimalsOnEthereum[i]);
            tokens.push(token_);
            vaults.push(new Vault(address(managerContractMock),address(token_),abi.encodePacked(address(pegTokens[i+1])),1));
            // (address _managerContractAddress, address _tokenUnderlying, bytes memory _coreAddress, uint64 _coreChainId)
        }

        for (uint i=0;i<decimalsOnBsc.length; ++i) {
            ERC20Template token_ = new ERC20Template(nameAndSymbolOnBsc[i],nameAndSymbolOnBsc[i],decimalsOnBsc[i]);
            tokens.push(token_);
            vaults.push(new Vault(address(managerContractMock),address(token_),abi.encodePacked(address(pegTokens[i])),1));
        }

        for (uint i=0;i<decimalsOnPolygon.length; ++i) {
            ERC20Template token_ = new ERC20Template(nameAndSymbolOnPolygon[i],nameAndSymbolOnPolygon[i],decimalsOnPolygon[i]);
            tokens.push(token_);
            vaults.push(new Vault(address(managerContractMock),address(token_),abi.encodePacked(address(pegTokens[i])),1));
        }

        managerContractMock.bindPegToVault(
            pegTokens,
            chainIDs,
            [[vaults[0],vaults[3],vaults[6]],[vaults[1],vaults[4],vaults[7]],[vaults[2],vaults[5],vaults[8]]]
        );
        
        // bind some state for PegToken
        for (uint i=0;i<pegTokens.length;++i){
            bytes[] memory  branchAddrs = new bytes[](3);
            if(i==0) {
                branchAddrs[0]=abi.encodePacked(address(vaults[0])); 
                branchAddrs[1]=abi.encodePacked(address(vaults[3]));
                branchAddrs[2]=abi.encodePacked(address(vaults[6]));
            }else if(i==1){
                branchAddrs[0]=abi.encodePacked(address(vaults[1]));
                branchAddrs[1]=abi.encodePacked(address(vaults[4]));
                branchAddrs[2]=abi.encodePacked(address(vaults[7]));
            }else if(i==2){
                branchAddrs[0]=abi.encodePacked(address(vaults[2]));
                branchAddrs[1]=abi.encodePacked(address(vaults[5]));
                branchAddrs[2]=abi.encodePacked(address(vaults[8]));
            }
            // bindBranchBatch(uint64[] memory branchChainIds, bytes[] memory branchAddrs)
            pegTokens[i].bindBranchBatch(chainIDs,branchAddrs);
        }

        
        vm.stopPrank();
        
        // generate user address on each chain
        uint startValue = 0x65;
        for (uint i=0; i<USER_NUMBER; i++) {
            users_on_ethereum.push(vm.addr(startValue++));
            users_on_bsc.push(vm.addr(startValue++));
            users_on_polygon.push(vm.addr(startValue++));
            users_on_zion.push(vm.addr(startValue++));
        }

        decimalRecord[5][0]=18;
        decimalRecord[5][1]=6;
        decimalRecord[5][2]=6;
        decimalRecord[6][0]=18;
        decimalRecord[6][1]=18;
        decimalRecord[6][2]=18;
        decimalRecord[7][0]=18;
        decimalRecord[7][1]=6;
        decimalRecord[7][2]=6;
    }

    function initUserBalanceState() internal {
        vm.startPrank(deployer);
        vm.deal(deployer,1000000 ether);
        // init ether to user of ethereum
        for(uint i=0;i<users_on_ethereum.length;++i) {
            vm.deal(users_on_ethereum[i],10000 ether);
            userState[5][address(0)][users_on_ethereum[i]]=10000 ether;
            assertEq(users_on_ethereum[i].balance,10000 ether,"wrong!");
        }

        // initialize tokens of ethereum state for users on ethereum
        for(uint i=0;i<2;++i){
            for(uint j=0;j<users_on_ethereum.length;++j){
                tokens[i].transfer(users_on_ethereum[j],10**6*10000 wei);
                userState[5][address(tokens[i])][users_on_ethereum[j]]=10**6*10000 wei;
            }
        }
        // initialize tokens of bsc for users on bsc
        for(uint i=2;i<5;++i){
            for(uint j=0;j<users_on_bsc.length;++j){
                tokens[i].transfer(users_on_bsc[j],10000 ether);
                userState[6][address(tokens[i])][users_on_bsc[j]]=10000 ether;
            }
        }

        // init polygon token state
        for(uint i=0;i<users_on_polygon.length;++i){
            tokens[5].transfer(users_on_polygon[i],10000 ether);
            userState[7][address(tokens[5])][users_on_polygon[i]]=10000 ether;
        }
        for(uint i=0;i<users_on_polygon.length;++i){
            for (uint j=6;j<tokens.length;++j) {
                tokens[j].transfer(users_on_polygon[i],10**6*10000 wei);
                userState[7][address(tokens[j])][users_on_polygon[i]]=10**6*10000 wei;
            }
        }

        // init vault token state

        // init ether vault on ethereum
        // deposite(address refundAddress, bytes memory toAddress, uint256 amount)
        vm.expectEmit(true, true, true, true,address(vaults[0]));
        emit DepositeEvent(deployer, deployer, abi.encodePacked(deployer), 10000 ether, 10000 ether);
        mockChainIDChannel.setCurrentlyChainID(5);
        vaults[0].deposite{value:10000 ether}(deployer, abi.encodePacked(deployer), 10000 ether);

        vaultState[5][address(vaults[0])] += 10000 ether;
        PegTokensTotalSupplyState[address(pegTokens[0])] += 10000 ether;
        PegTokensSideChainLiquidity[address(pegTokens[0])][5] += 10000 ether;
        assertEq(address(vaults[0]).balance,10000 ether);
        assertEq(pegTokens[0].totalSupply(),10000 ether);
        assertEq(pegTokens[0].chainLiquidityMap(5),10000 ether);
        

        assertEq(address(vaults[0]).balance, 10000 ether);

        // init erc20 token of vault
        for (uint i=1;i<vaults.length;++i) {
            if(i==1 || i==2 ){
                mockChainIDChannel.setCurrentlyChainID(5);
            }else if (i==3 || i==4 || i==5) {
                mockChainIDChannel.setCurrentlyChainID(6);
            }else if (i==6 || i==7 || i==8 ){
                mockChainIDChannel.setCurrentlyChainID(7);
            }

            uint64 currentlyChainId = mockChainIDChannel.currentlyFromChainID();

            if(vaults[i].underlyingTokenDecimals()==18) {
                vm.expectEmit(true, true, true, true,address(vaults[i]));
                emit DepositeEvent(deployer, deployer, abi.encodePacked(deployer), 10000 ether, 10000 ether);
                ERC20(vaults[i].underlyingToken()).approve(address(vaults[i]),10000 ether);
                vaults[i].deposite(deployer,abi.encodePacked(deployer),10000 ether);
                
                vaultState[currentlyChainId][address(vaults[i])]+=10000 ether;
                assertEq(
                    vaultState[currentlyChainId][address(vaults[i])],
                    ERC20(vaults[i].underlyingToken()).balanceOf(address(vaults[i]))
                );
                if (i==3 || i==6) { // ether
                    PegTokensTotalSupplyState[address(pegTokens[0])]+=10000 ether;
                    PegTokensSideChainLiquidity[address(pegTokens[0])][currentlyChainId]+=10000 ether;
                    assertEq(PegTokensTotalSupplyState[address(pegTokens[0])],pegTokens[0].totalSupply());
                    assertEq(PegTokensSideChainLiquidity[address(pegTokens[0])][currentlyChainId],pegTokens[0].chainLiquidityMap(currentlyChainId));
                }else if(i==1 || i==4 || i==7) { // usdt
                    PegTokensTotalSupplyState[address(pegTokens[1])]+=10000 ether;
                    PegTokensSideChainLiquidity[address(pegTokens[1])][currentlyChainId]+=10000 ether;
                    assertEq(PegTokensTotalSupplyState[address(pegTokens[1])],pegTokens[1].totalSupply());
                    assertEq(PegTokensSideChainLiquidity[address(pegTokens[1])][currentlyChainId],pegTokens[1].chainLiquidityMap(currentlyChainId));
                }else if (i==2 || i==5 || i==8) { // usdc
                    PegTokensTotalSupplyState[address(pegTokens[2])]+=10000 ether;
                    PegTokensSideChainLiquidity[address(pegTokens[2])][currentlyChainId]+=10000 ether;
                    assertEq(PegTokensTotalSupplyState[address(pegTokens[2])],pegTokens[2].totalSupply());
                    assertEq(PegTokensSideChainLiquidity[address(pegTokens[2])][currentlyChainId],pegTokens[2].chainLiquidityMap(currentlyChainId));
                }
                
                assertEq(ERC20(vaults[i].underlyingToken()).balanceOf(deployer),100000000000000 ether-(10000 ether*100+10000 ether));

            }else if(vaults[i].underlyingTokenDecimals()==6){
                vm.expectEmit(true, true, true, true,address(vaults[i]));
                emit DepositeEvent(deployer, deployer, abi.encodePacked(deployer), 10**6*10000, Helper.helper_rounding(6,10**6*10000,false));
                ERC20(vaults[i].underlyingToken()).approve(address(vaults[i]),10**6*10000);
                vaults[i].deposite(deployer,abi.encodePacked(deployer),10**6*10000);

                vaultState[currentlyChainId][address(vaults[i])]+=10**6*10000;
                assertEq(
                    vaultState[currentlyChainId][address(vaults[i])],
                    ERC20(vaults[i].underlyingToken()).balanceOf(address(vaults[i]))
                );
                
                uint256 pegAmount = Helper.helper_rounding(6,10**6*10000,false);
                if(i==1 || i==7) { // usdt
                    PegTokensTotalSupplyState[address(pegTokens[1])] += pegAmount;
                    PegTokensSideChainLiquidity[address(pegTokens[1])][currentlyChainId] += pegAmount;
                    assertEq(PegTokensTotalSupplyState[address(pegTokens[1])],pegTokens[1].totalSupply());
                    assertEq(PegTokensSideChainLiquidity[address(pegTokens[1])][currentlyChainId],pegTokens[1].chainLiquidityMap(currentlyChainId));
                }else if (i==2 || i==8) { // usdc
                    PegTokensTotalSupplyState[address(pegTokens[2])]+=pegAmount;
                    PegTokensSideChainLiquidity[address(pegTokens[2])][currentlyChainId] += pegAmount;
                    assertEq(PegTokensTotalSupplyState[address(pegTokens[2])],pegTokens[2].totalSupply());
                    assertEq(PegTokensSideChainLiquidity[address(pegTokens[2])][currentlyChainId],pegTokens[2].chainLiquidityMap(currentlyChainId));
                }

                assertEq(ERC20(vaults[i].underlyingToken()).balanceOf(deployer),100000000000000 ether-10**6*10000*101);

            }else{
                revert();
            }
        }
        vm.stopPrank();
    }

    function printLiquidity() public view {
        for(uint i=0;i<pegTokens.length;++i){
            console.log(pegTokens[i].chainLiquidityMap(5));
            console.log(pegTokens[i].chainLiquidityMap(6));
            console.log(pegTokens[i].chainLiquidityMap(7));
        }
    }

    function testRandomTransaction() public {
        initUserBalanceState(); // initialize status

        string[] memory command = new string[](1);
        command[0] = "./random_transaction_generator";

        bytes memory randomTransaction;
        for (uint i=0;i<1;++i) {
            randomTransaction = vm.ffi(command);
            uint operationType;
            assembly {
                operationType:=mload(add(randomTransaction,0x20))
            }
            require(operationType==0 || operationType==1 || operationType==2,"data from ffi is incorrect!");
            
            // 0 is deposit
            if (operationType==0) {
                (   
                    uint8 _operationType,
                    uint64 callerUserChainID,
                    uint8 callerUserAddressIndex,
                    uint8 asset,
                    uint8 refundAddressIndex,
                    uint8 zionToAddressIndex,
                    uint256 amount
                )=abi.decode(randomTransaction,(uint8,uint64,uint8,uint8,uint8,uint8,uint256));
                
                address callerAddress;
                Vault vault;
                address refundAddress;
                address zionToAddress = users_on_zion[zionToAddressIndex];

                

                if (callerUserChainID == 5) {
                    callerAddress = users_on_ethereum[callerUserAddressIndex];
                    refundAddress = users_on_ethereum[refundAddressIndex];
                    vault=vaults[0+asset];
                } else if (callerUserChainID == 6) {
                    callerAddress = users_on_bsc[callerUserAddressIndex];
                    refundAddress = users_on_bsc[refundAddressIndex];
                    vault=vaults[3+asset];
                } else if (callerUserChainID == 7 ) {
                    callerAddress = users_on_polygon[callerUserAddressIndex];
                    refundAddress = users_on_polygon[refundAddressIndex];
                    vault=vaults[6+asset];
                }
                

                ZionPegToken pegToken = pegTokens[asset];

                vm.startPrank(callerAddress);

                uint256 nativeEtherAmount;
                if (!(callerUserChainID==5 && asset==0)) { // chain5 native ether doesn't need approve
                    ERC20(vault.underlyingToken()).approve(address(vault),amount);
                    nativeEtherAmount = 0;
                } else {
                    nativeEtherAmount = amount;
                }
                
                mockChainIDChannel.setCurrentlyChainID(callerUserChainID);
                try vault.deposite{value: nativeEtherAmount}(refundAddress, abi.encodePacked(zionToAddress),amount) {
                    // increasing
                    uint pegAmount = Helper.helper_rounding(decimalRecord[callerUserChainID][asset],amount,false);
                    userState[1][address(pegToken)][zionToAddress] += pegAmount;
                    PegTokensTotalSupplyState[address(pegToken)] += pegAmount;
                    PegTokensSideChainLiquidity[address(pegToken)][callerUserChainID] += pegAmount;
                    vaultState[callerUserChainID][address(vault)] += amount; // for chainId5 asset0 , this balance is ether

                    // reducing
                    if (callerUserChainID==5 && asset==0) { // if it is native token on ethereum
                        userState[callerUserChainID][address(0)][callerAddress] -= amount;
                    }else {
                        userState[callerUserChainID][vault.underlyingToken()][callerAddress] -= amount;
                    }

                    // console.log("right",callerUserChainID,asset,amount);
                } catch {
                    // console.log("wrong",callerUserChainID,asset,amount);
                }
                
                assertEq(userState[1][address(pegToken)][zionToAddress],pegToken.balanceOf(zionToAddress));
                assertEq(PegTokensTotalSupplyState[address(pegToken)],pegToken.totalSupply());
                assertEq(PegTokensSideChainLiquidity[address(pegToken)][callerUserChainID],pegToken.chainLiquidityMap(callerUserChainID));
                if (callerUserChainID==5&&asset==0) { // native ether
                    assertEq(vaultState[callerUserChainID][address(vault)], address(vault).balance);
                    assertEq(userState[callerUserChainID][address(0)][callerAddress],callerAddress.balance);
                }else {
                    assertEq(vaultState[callerUserChainID][address(vault)], ERC20(vault.underlyingToken()).balanceOf(address(vault)));
                    assertEq(userState[callerUserChainID][vault.underlyingToken()][callerAddress],ERC20(vault.underlyingToken()).balanceOf(callerAddress));
                }
                
                vm.stopPrank();
                
                
                
            }else if (operationType == 1) { // 1 is depositAndWithdraw
                (
                    uint8 _operationType,
                    uint64 callerUserChainID,
                    uint8 callerUserAddressIndex,
                    uint8 asset,
                    uint8 refundAddressIndex,
                    uint8 zionToAddressIndex,
                    uint8 targetAddressIndex,
                    uint64 targetChainID,
                    uint256 amount)=abi.decode(randomTransaction,(uint8,uint64,uint8,uint8,uint8,uint8,uint8,uint64,uint256));
                    
                    address callerAddress;
                    address refundAddress;
                    Vault vault;
                    address targetChainAddress;
                    address zionToAddress = users_on_zion[zionToAddressIndex];
                    
                    
                    if (callerUserChainID == 5) {
                        callerAddress = users_on_ethereum[callerUserAddressIndex];
                        refundAddress = users_on_ethereum[refundAddressIndex];
                        vault=vaults[0+asset];
                    } else if (callerUserChainID == 6) {
                        callerAddress = users_on_bsc[callerUserAddressIndex];
                        refundAddress = users_on_bsc[refundAddressIndex];
                        vault=vaults[3+asset];
                    } else if (callerUserChainID == 7 ) {
                        callerAddress = users_on_polygon[callerUserAddressIndex];
                        refundAddress = users_on_polygon[refundAddressIndex];
                        vault=vaults[6+asset];
                    }

                    if (targetChainID == 5) {
                        targetChainAddress = users_on_ethereum[targetAddressIndex];
                    } else if (targetChainID == 6) {
                        targetChainAddress = users_on_bsc[targetAddressIndex];
                    } else if (targetChainID == 7 ) {
                        targetChainAddress = users_on_polygon[targetAddressIndex];
                    }

                    uint nativeEtherAmount;
                    vm.startPrank(callerAddress);
                    if (callerUserChainID==5 && asset==0 ) { // chainId5 native ether
                        nativeEtherAmount = amount;
                    }else {
                        nativeEtherAmount=0;
                        ERC20(vault.underlyingToken()).approve(address(vault),amount);
                    }

                    mockChainIDChannel.setCurrentlyChainID(callerUserChainID);
                    // try vault.depositeAndWithdraw{value: nativeEtherAmount}(refundAddress, abi.encodePacked(zionToAddress),
                    //                                                             abi.encodePacked(targetChainAddress),targetChainID,amount) {
                    //     console.log("right");
                    // } catch {
                    //     console.log("wrong");
                    // }

                    vault.depositeAndWithdraw{value: nativeEtherAmount}(refundAddress, abi.encodePacked(zionToAddress),
                                                                                 abi.encodePacked(targetChainAddress),targetChainID,amount);
                    
                
                    vm.stopPrank();
                // 失败原因分外部硬性失败和内部失败。硬性失败值跨链发起方钱不够。内部失败指目标链流动性不够。

            }else if (operationType == 2) { // 2 is withdraw
                (
                    uint8 _operationType,
                    uint8 zionCallerAddressIndex,
                    uint8 asset,
                    uint8 targetAddressIndex,
                    uint64 targetChainID,
                    uint256 amount)=abi.decode(randomTransaction,(uint8,uint8,uint8,uint8,uint64,uint256));

            }

        }

        
    }
    
    function testTmp() public {
        initUserBalanceState(); // initialize status
        for(uint i =0;i<pegTokens.length;++i) {
            console.logBytes(pegTokens[i].branchMap(5));
            console.logBytes(pegTokens[i].branchMap(6));
            console.logBytes(pegTokens[i].branchMap(7));
            console.log("#");
        }

        console.log("****");
        for(uint i=0;i<vaults.length;++i){
            console.logAddress(address(vaults[i]));
        }
    }
    
    function testPegTokensAddress() public {
        initUserBalanceState(); // initialize status
        for(uint i =0;i<pegTokens.length;++i) {
            console.logAddress(address(pegTokens[i]));
        }
        console.log(tokens.length);
    }
}

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

    ERC20Template[] tokens; // side chain underlying tokens
    Vault[] vaults; // side chain vault
    ZionPegToken[] pegTokens;

    MockChainIDChannel mockChainIDChannel;
    ManagerContractMock managerContractMock;
    
    // users state on each blockChain. for example:
    // chainID => ( assetAddress  => ( user_address => balance ) )
    // chainID 1 is zion chain, chainID 5 6 7 is sideChain
    // assetAddress can be sideChain vault address or zion PegAddress
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
        vaults.push(new Vault(address(managerContractMock),address(0),abi.encode(address(pegTokens[0])),1));
        for (uint i=0;i<decimalsOnEthereum.length; ++i) {
            ERC20Template token_=new ERC20Template(nameAndSymbolOnEthereum[i],nameAndSymbolOnEthereum[i],decimalsOnEthereum[i]);
            tokens.push(token_);
            vaults.push(new Vault(address(managerContractMock),address(token_),abi.encode(address(pegTokens[i+1])),1));
            // (address _managerContractAddress, address _tokenUnderlying, bytes memory _coreAddress, uint64 _coreChainId)
        }

        for (uint i=0;i<decimalsOnBsc.length; ++i) {
            ERC20Template token_ = new ERC20Template(nameAndSymbolOnBsc[i],nameAndSymbolOnBsc[i],decimalsOnBsc[i]);
            tokens.push(token_);
            vaults.push(new Vault(address(managerContractMock),address(token_),abi.encode(address(pegTokens[i])),1));
        }

        for (uint i=0;i<decimalsOnPolygon.length; ++i) {
            ERC20Template token_ = new ERC20Template(nameAndSymbolOnPolygon[i],nameAndSymbolOnPolygon[i],decimalsOnPolygon[i]);
            tokens.push(token_);
            vaults.push(new Vault(address(managerContractMock),address(token_),abi.encode(address(pegTokens[i])),1));
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
        }
    }

    function initUserBalanceState() internal {
        vm.startPrank(deployer);
        vm.deal(deployer,1000000 ether);
        // init ether to user of ethereum
        for(uint i=0;i<users_on_ethereum.length;++i) {
            vm.deal(users_on_ethereum[i],10000 ether);
            assertEq(users_on_ethereum[i].balance,10000 ether,"fuck");
        }

        // initialize tokens of ethereum state for users on ethereum
        for(uint i=0;i<2;++i){
            for(uint j=0;j<users_on_ethereum.length;++j){
                tokens[i].transfer(users_on_ethereum[j],10**6*10000 wei);
            }
        }
        // initialize tokens of bsc for users on bsc
        for(uint i=2;i<5;++i){
            for(uint j=0;j<users_on_bsc.length;++j){
                tokens[i].transfer(users_on_bsc[j],10000 ether);
            }
        }

        // init polygon token state
        for(uint i=0;i<users_on_polygon.length;++i){
            tokens[5].transfer(users_on_polygon[i],10000 ether);
        }
        for(uint i=0;i<users_on_polygon.length;++i){
            for (uint j=6;j<tokens.length;++j) {
                tokens[j].transfer(users_on_polygon[i],10**6*10000 wei);
            }
        }

        // init vault token state

        // init ether vault on ethereum
        // deposite(address refundAddress, bytes memory toAddress, uint256 amount)
        mockChainIDChannel.setCurrentlyChainID(5);
        vaults[0].deposite{value:10000 ether}(deployer,abi.encodePacked(deployer),10000 ether);
        assertEq(address(vaults[0]).balance,10000 ether);

        // init erc20 token of vault
        for (uint i=1;i<vaults.length;++i) {
            if(i==1 || i==2 ){
                mockChainIDChannel.setCurrentlyChainID(5);
            }else if (i==3 || i==4 || i==5) {
                mockChainIDChannel.setCurrentlyChainID(6);
            }else if (i==6 || i==7 || i==8 ){
                mockChainIDChannel.setCurrentlyChainID(7);
            }

            if(vaults[i].underlyingTokenDecimals()==18) {
                ERC20(vaults[i].underlyingToken()).approve(address(vaults[i]),10000 ether);
                vaults[i].deposite(deployer,abi.encodePacked(deployer),10000 ether);
                

                assertEq(ERC20(vaults[i].underlyingToken()).balanceOf(deployer),100000000000000 ether-(10000 ether*100+10000 ether));

            }else if(vaults[i].underlyingTokenDecimals()==6){
                ERC20(vaults[i].underlyingToken()).approve(address(vaults[i]),10**6*10000);
                vaults[i].deposite(deployer,abi.encodePacked(deployer),10**6*10000);
                

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
        for (uint i=0;i<100;++i){
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

            }else if (operationType == 1) { // 1 is depositAndWith 
                (
                    uint8 _operationType,
                    uint64 callerUserChainID,
                    uint8 callerUserIndex,
                    uint8 asset,
                    uint8 refundAddressIndex,
                    uint8 zionToAddressIndex,
                    uint8 targetAddressIndex,
                    uint64 targetChainID,
                    uint256 amount)=abi.decode(randomTransaction,(uint8,uint64,uint8,uint8,uint8,uint8,uint8,uint64,uint256));


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

    
}

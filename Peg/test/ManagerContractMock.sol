// because there is a Mock multi-chain environment, ManagerContractMock.crossChain simulates the operation of relayers
// it directly calls zion peg Token's methods.

import "core/ZionPegToken.sol";
import {Vault} from "core/Vault.sol";
import "forge-std/console.sol";
import "core/Codec.sol";

// when call deposit and depositAndWithdraw , need to call setCurrentlyChainID helper function first,because core need to know call from which chain
contract MockChainIDChannel {
    uint64 public currentlyFromChainID; // used for vault call core,let core contract knows call from which side chain.
    function setCurrentlyChainID(uint64 chainID) public {
        currentlyFromChainID=chainID;
    }
}

// before any operation, isFromPegToken and findVaultAddress need to initialize.
contract ManagerContractMock {
    MockChainIDChannel mockChainIDChannel;
    mapping(address=>bool)  isFromPegToken;
    mapping(address=>mapping(uint64=>address)) findVaultAddress; // PegAddress => ChainID => VaultAddress
    constructor(MockChainIDChannel _mockChainIDChannel) {
        mockChainIDChannel = _mockChainIDChannel;
    }

    function bindPegToken(ZionPegToken[] memory pegTokens) public {
        for (uint i=0;i<pegTokens.length;++i){
            isFromPegToken[address(pegTokens[i])]=true;
        }
    }

    function bindPegToVault(ZionPegToken[] memory pegTokens,uint64[] memory chainIDs, Vault[3][3] memory vaultAddrs) public {
        for (uint i=0;i<vaultAddrs.length;++i) {
            require(chainIDs.length==vaultAddrs[i].length,"incorrect length");
        }

        for (uint i=0;i<pegTokens.length;++i){
            for(uint t=0;t<vaultAddrs.length;++t){
                for(uint j=0;j<chainIDs.length;++j) {
                    findVaultAddress[address(pegTokens[i])][chainIDs[j]]=address(vaultAddrs[t][j]);
                }
            }
        }
    }
    
    function crossChain(
        // for example, user -> vault.deposit -> ManagerContract.crossChain(emit event)-> |relayer|->PegToken
        // relayer left side is side chain,right side is zion chain.
        uint64 toChainId,
        bytes calldata toContract,
        bytes calldata method, // receiveMessage
        bytes calldata txData // Codec.encodeDepositeMessage(toAddress, Utils.addressToBytes(refundAddress), pegAmount)
    ) external returns (bool) {
        if (isFromPegToken[msg.sender]) { // core call vault
            // 1 is zion ChainID
            Vault(findVaultAddress[msg.sender][toChainId]).receiveMessage(txData,abi.encodePacked(msg.sender),1);
            
            return true;
        } else { // else is vault call core
            uint64 fromChainID = mockChainIDChannel.currentlyFromChainID();
            address _toContract = bytesToAddress(toContract); // corresponding PegToken
            ZionPegToken(_toContract).receiveMessage(txData,abi.encodePacked(msg.sender),fromChainID);
            return true;
        }        
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
}


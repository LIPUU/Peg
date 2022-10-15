import "slomate/tokens/ERC20.sol";
contract ERC20Template is ERC20 {
    uint immutable initialSupply=100000000000000 ether;
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC20(_name,_symbol,_decimals){
        
    }
    
    function initialize() public {
        _mint(msg.sender,initialSupply);
    } 
}
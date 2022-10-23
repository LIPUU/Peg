import {ERC20Template} from "test/token/ERC20Template.sol"; 

library Helper {
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

    function token_generation(string memory name,string memory symbol,uint8 decimals) public returns(ERC20Template) {
        return new ERC20Template(name,symbol,decimals);
    }
    
}
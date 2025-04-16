// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.22;

import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WA7A5 is ERC20Permit {
    IA7A5 public immutable A7A5;

    /**
     * @param _A7A5 address of the A7A5 token to wrap
     */
    constructor(IA7A5 _A7A5)
        ERC20Permit("Wrapped A7A5 1.0")
        ERC20("Wrapped A7A5 1.0", "wA7A5")
    {
        A7A5 = _A7A5;
    }

    /**
     * @notice Exchanges A7A5 to wA7A5
     * @param _A7A5Amount amount of A7A5 to wrap in exchange for wA7A5
     * @dev Requirements:
     *  - `_A7A5Amount` must be non-zero
     *  - msg.sender must approve at least `_A7A5Amount` A7A5 to this
     *    contract.
     *  - msg.sender must have at least `_A7A5Amount` of A7A5.
     * User should first approve _A7A5Amount to the wA7A5 contract
     * @return Amount of wA7A5 user receives after wrap
     */
    function wrap(uint256 _A7A5Amount) external returns (uint256) {
        require(_A7A5Amount > 0, "wA7A5: can't wrap zero A7A5");
        uint256 wA7A5Amount = A7A5.getScaledAmount(_A7A5Amount);
        _mint(msg.sender, wA7A5Amount);
        A7A5.transferFrom(msg.sender, address(this), _A7A5Amount);
        return wA7A5Amount;
    }

    /**
     * @notice Exchanges wA7A5 to A7A5
     * @param _wA7A5Amount amount of wA7A5 to uwrap in exchange for A7A5
     * @dev Requirements:
     *  - `_wA7A5Amount` must be non-zero
     *  - msg.sender must have at least `_wA7A5Amount` wA7A5.
     * @return Amount of A7A5 user receives after unwrap
     */
    function unwrap(uint256 _wA7A5Amount) external returns (uint256) {
        require(_wA7A5Amount > 0, "wA7A5: zero amount unwrap not allowed");
        uint256 A7A5Amount = A7A5.getLiquidityAmount(_wA7A5Amount);
        _burn(msg.sender, _wA7A5Amount);
        A7A5.transfer(msg.sender, A7A5Amount);
        return A7A5Amount;
    }

    receive() external payable {}

    /**
     * @notice Get amount of wA7A5 for a given amount of A7A5
     * @param _A7A5Amount amount of A7A5
     * @return Amount of wA7A5 for a given A7A5 amount
     */
    function getwA7A5ByA7A5(uint256 _A7A5Amount) public view returns (uint256) {
        return A7A5.getScaledAmount(_A7A5Amount);
    }

    /**
     * @notice Get amount of A7A5 for a given amount of wA7A5
     * @param _wA7A5Amount amount of wA7A5
     * @return Amount of A7A5 for a given wA7A5 amount
     */
    function getA7A5BywA7A5(uint256 _wA7A5Amount) external view returns (uint256) {
        return A7A5.getLiquidityAmount(_wA7A5Amount);
    }

    /**
     * @notice Get amount of A7A5 for a one wA7A5
     * @return Amount of A7A5 for 1 wA7A5
     */
    function A7A5PerToken() external view returns (uint256) {
        return A7A5.getLiquidityAmount(1e6);
    }

    /**
     * @notice Get amount of wA7A5 for a one A7A5
     * @return Amount of wA7A5 for a 1 A7A5
     */
    function tokensPerA7A5() external view returns (uint256) {
        return A7A5.getScaledAmount(1e6);
    }

    function decimals() public view override returns (uint8) {
        return 6;
    }
}


interface IA7A5 is IERC20 {
    function getScaledAmount(uint256 amount) external view returns (uint256);
    function getLiquidityAmount(uint256 shares) external view returns (uint256);
}

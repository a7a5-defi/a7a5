pragma solidity =0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUSDT {
    function transfer(address to, uint256 value) external;
    function transferFrom(address from, address to, uint256 value) external;
}

contract TronSwapper {
    using SafeERC20 for IERC20;

    // ownable
    address public owner;
    address public operator;

    // fees
    uint256 public constant FEE_DENOMINATOR = 1e6;
    uint256 public fee;

    // swap params
    address public a7a5;
    address public usdt;
    uint256 public sellA7A5Ratio;
    uint256 public buyA7A5Ratio;
    uint256 public constant ratioDenominator = 1e6;

    // pausable
    bool public paused = false;

    // events
    event OwnerChanged(address indexed newOwner);
    event OperatorChanged(address indexed newOperator);
    event Paused(bool paused);
    event SellA7A5RatioUpdated(uint256 newRatio);
    event BuyA7A5RatioUpdated(uint256 newRatio);
    event FeeUpdated(uint256 fee);
    event Exchange(
        address indexed tokenFrom,
        address indexed tokenTo,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeRatio,
        uint256 exchangeRate
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyOwnerOrOperator() {
        require(msg.sender == operator || msg.sender == owner, "not owner or operator");
        _;
    }

    modifier whenNotPaused() {
        require(paused == false, "protocol paused");
        _;
    }

    constructor (
        address _owner,
        address _operator,
        address _a7a5,
        address _usdt,
        uint256 _sellA7A5Ratio,
        uint256 _buyA7A5Ratio
    ) {
        require(_owner != address(0), "Owner should be non zero address");
        require(_operator != address(0), "Operator should be non zero address");
        owner = _owner;
        operator = _operator;
        a7a5 = _a7a5;
        usdt = _usdt;
        sellA7A5Ratio = _sellA7A5Ratio;
        buyA7A5Ratio = _buyA7A5Ratio;
    }

    function updateOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "owner cannot be zero address");
        owner = newOwner;
        emit OwnerChanged(newOwner);
    }

    function updateOperator(address newOperator) external onlyOwner {
        require(newOperator != address(0), "operator cannot be zero address");
        operator = newOperator;
        emit OperatorChanged(newOperator);
    }

    function pause() external onlyOwnerOrOperator whenNotPaused {
        paused = true;
        emit Paused(paused);
    }

    function unpause() external onlyOwnerOrOperator {
        paused = false;
        emit Paused(paused);
    }

    function supplyUSDT(uint256 amount) external {
        require(amount > 0, "supply amount cannot be zero");
        IUSDT(usdt).transferFrom(msg.sender, address(this), amount);
    }

    function supplyA7A5(uint256 amount) external {
        require(amount > 0, "supply amount cannot be zero");
        IERC20(a7a5).safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdrawUSDT(uint256 amount) external onlyOwnerOrOperator {
        require(amount > 0, "withdraw amount cannot be zero");
        IUSDT(usdt).transfer(msg.sender, amount);
    }

    function withdrawA7A5(uint256 amount) external onlyOwnerOrOperator {
        require(amount > 0, "withdraw amount cannot be zero");
        IERC20(a7a5).safeTransfer(msg.sender, amount);
    }

    function setSellA7A5Ratio(uint256 newRatio) external onlyOwnerOrOperator {
        require(newRatio > 0, "sell ratio cannot be 0");
        sellA7A5Ratio = newRatio;
        emit SellA7A5RatioUpdated(newRatio);
    }

    function setBuyA7A5Ratio(uint256 newRatio) external onlyOwnerOrOperator {
        require(newRatio > 0, "buy ratio cannot be 0");
        buyA7A5Ratio = newRatio;
        emit BuyA7A5RatioUpdated(newRatio);
    }

    function setFee(uint256 newFee) external onlyOwnerOrOperator {
        require(fee < FEE_DENOMINATOR);
        fee = newFee;
        emit FeeUpdated(fee);
    }

    function exchangeA7A5ToUSDT(uint256 a7a5Amount) external whenNotPaused {
        require(a7a5Amount > 0, "excnage amount cannot be zero");
        uint256 amountWithoutFee = a7a5Amount * (FEE_DENOMINATOR - fee) / FEE_DENOMINATOR;
        uint256 usdtAmount = amountWithoutFee * sellA7A5Ratio / ratioDenominator;
        require(IERC20(usdt).balanceOf(address(this)) >= usdtAmount, "not enough tokens for swap");
        IERC20(a7a5).safeTransferFrom(msg.sender, address(this), a7a5Amount);
        IUSDT(usdt).transfer(msg.sender, usdtAmount);
        emit Exchange(
            a7a5,
            usdt,
            a7a5Amount,
            usdtAmount,
            fee,
            sellA7A5Ratio
        );
    }

    function exchangeUSDTToA7A5(uint256 usdtAmount) external whenNotPaused {
        require(usdtAmount > 0, "excnage amount cannot be zero");
        uint256 amountWithoutFee = usdtAmount * (FEE_DENOMINATOR - fee) / FEE_DENOMINATOR;
        uint256 a7a5Amount = amountWithoutFee * buyA7A5Ratio / ratioDenominator;
        require(IERC20(a7a5).balanceOf(address(this)) >= a7a5Amount, "not enough tokens for swap");
        IUSDT(usdt).transferFrom(msg.sender, address(this), usdtAmount);
        IERC20(a7a5).safeTransfer(msg.sender, a7a5Amount);
        emit Exchange(
            usdt,
            a7a5,
            usdtAmount,
            a7a5Amount,
            fee,
            buyA7A5Ratio
        );
    }
}
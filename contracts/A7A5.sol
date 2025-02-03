// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.22;

interface IToken {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
}

contract A7A5 is IToken {
    string private _name;
    string private _symbol;
    uint8 private immutable _decimals;

    uint256 private _totalSupply;
    uint256 private _totalLiquidity;

    mapping(address => uint256) private _shares; // Raw balances
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public isBlackListed;

    address public immutable owner;
    address public immutable compliance;
    address public immutable accountant;

    // fees
    uint256 public basisPointsRate;

    uint256 public constant MAX_BASIS_POINTS = 20;
    uint256 public constant FEE_PRECISION = 10000;

    bool public paused = false;

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyCompliance() {
        require(msg.sender == compliance, "not compliance");
        _;
    }

    modifier onlyAccountant() {
        require(msg.sender == accountant, "not accountant");
        _;
    }

    modifier whenNotPaused() {
        require(paused == false, "protocol paused");
        _;
    }

    modifier notBlacklisted(address _from, address _to) {
        require(!isBlackListed[_from] && !isBlackListed[_to], "User blacklisted");
        _;
    }

    event Issue(address user, uint256 amount);
    event Burn(address user, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed from, address indexed to, uint256 amount);

    event Blacklisted(address token);
    event DeBlacklisted(address token);
    event DestroyedBlackFunds(address user, uint256 amount);

    event TotalLiquidityUpdated(
        uint256 oldTotalLiquidity,
        uint256 newTotalLiquidity
    );

    event Paused();
    event Unpaused();

    event BasisPointsRateUpdated(uint256 newBasisPointsRate);

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address owner_,
        address compliance_,
        address accountant_
    ) {
        require(owner_ != address(0), "Owner should be non zero address");
        require(compliance_ != address(0), "Owner should be non zero address");
        require(accountant_ != address(0), "Owner should be non zero address");
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        owner = owner_;
        compliance = compliance_;
        accountant = accountant_;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return getLiquidityAmount(_shares[account]);
    }

    function sharesOf(address _account) public view returns (uint256) {
        return _shares[_account];
    }

    function allowance(
        address _owner,
        address _spender
    ) public view override returns (uint256) {
        return _allowances[_owner][_spender];
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function totalLiquidity() public view returns (uint256) {
        return _totalLiquidity;
    }

    function getScaledAmount(uint256 amount) public view returns (uint256) {
        if (_totalLiquidity == 0) {
            return amount;
        }
        return (amount * _totalSupply) / _totalLiquidity;
    }

    function getLiquidityAmount(uint256 shares) public view returns (uint256) {
        if (_totalSupply == 0) {
            return 0;
        }
        return (shares * _totalLiquidity) / _totalSupply;
    }

    function getBlackListStatus(address _maker) public view returns (bool) {
        return isBlackListed[_maker];
    }

    function issue(address account, uint256 amount) public onlyOwner {
        require(account != address(0));
        uint256 scaledAmount = getScaledAmount(amount);
        _totalSupply += scaledAmount;
        _totalLiquidity += amount;
        _shares[account] += scaledAmount;

        emit Transfer(address(0), account, amount);
        emit Issue(account, amount);
    }

    function burn(uint256 amount) public onlyOwner {
        uint256 scaledAmount = getScaledAmount(amount);
        _totalSupply -= scaledAmount;
        _totalLiquidity -= amount;
        _shares[owner] -= scaledAmount;
        emit Transfer(owner, address(0), amount);
        emit Burn(owner, amount);
    }

    function transfer(
        address _to,
        uint256 _value
    ) public whenNotPaused notBlacklisted(msg.sender, _to) returns (bool) {
        uint256 scaledAmount = getScaledAmount(_value);
        uint256 fee = (scaledAmount * basisPointsRate) / FEE_PRECISION;
        _transferShares(msg.sender, _to, scaledAmount - fee);
        if (fee > 0) {
            _transferShares(msg.sender, owner, fee);
            emit Transfer(msg.sender, owner, getLiquidityAmount(fee));
        }
        emit Transfer(msg.sender, _to, getLiquidityAmount(scaledAmount - fee));
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public whenNotPaused notBlacklisted(_from, _to) returns (bool) {
        uint256 allowance_ = _allowances[_from][msg.sender];
        require(allowance_ >= _value, "allowance exceeded");
        if (allowance_ < type(uint256).max) {
            _allowances[_from][msg.sender] -= _value;
        }

        uint256 scaledAmount = getScaledAmount(_value);
        uint256 fee = (scaledAmount * basisPointsRate) / FEE_PRECISION;
        _transferShares(_from, _to, scaledAmount - fee);
        if (fee > 0) {
            _transferShares(_from, owner, fee);
            emit Transfer(_from, owner, getLiquidityAmount(fee));
        }
        emit Transfer(_from, _to, getLiquidityAmount(scaledAmount - fee));
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        _allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferScaled(
        address _to,
        uint256 _value
    ) public whenNotPaused notBlacklisted(msg.sender, _to) returns (bool) {
        uint256 fee = (_value * basisPointsRate) / FEE_PRECISION;
        _transferShares(msg.sender, _to, _value - fee);
        emit Transfer(msg.sender, _to, getLiquidityAmount(_value - fee));
        if (fee > 0) {
            _transferShares(msg.sender, owner, fee);
            emit Transfer(msg.sender, owner, getLiquidityAmount(fee));
        }
        return true;
    }

    function transferScaledFrom(
        address _from,
        address _to,
        uint256 _value
    ) public whenNotPaused notBlacklisted(_from, _to) returns (bool) {
        uint256 fee = (_value * basisPointsRate) / FEE_PRECISION;
        uint256 allowance_ = _allowances[_from][msg.sender];
        uint256 liquidityAmount = getLiquidityAmount(_value);
        require(allowance_ >= liquidityAmount, "allowance exceeded");
        if (allowance_ < type(uint256).max) {
            _allowances[_from][msg.sender] -= liquidityAmount;
        }
        _transferShares(_from, _to, _value - fee);
        emit Transfer(_from, _to, getLiquidityAmount(_value - fee));
        if (fee > 0) {
            _transferShares(_from, owner, fee);
            emit Transfer(_from, owner, getLiquidityAmount(fee));
        }
        return true;
    }

    function distributeInterest(int256 _liquidity) public onlyAccountant {
        uint256 oldTotalLiquidity = _totalLiquidity;
        if (_liquidity > 0) {
            _totalLiquidity += uint256(_liquidity);
        } else {
            uint256 liquidityDecrease = uint256(-_liquidity);
            require(
                liquidityDecrease < _totalLiquidity,
                "not liquidity enough"
            );
            _totalLiquidity -= liquidityDecrease;
        }
        require(_totalLiquidity >= totalSupply(), "Total liquidity must be more then total supply");
        emit TotalLiquidityUpdated(oldTotalLiquidity, _totalLiquidity);
    }

    function pause() public onlyOwner whenNotPaused {
        paused = true;
        emit Paused();
    }

    function unpause() public onlyOwner {
        paused = false;
        emit Unpaused();
    }

    function updateBasisPointsRate(uint256 newBasisPoints) public onlyOwner {
        require(
            newBasisPoints < MAX_BASIS_POINTS,
            "basis points should be less then MAX_BASIS_POINTS"
        );
        basisPointsRate = newBasisPoints;
        emit BasisPointsRateUpdated(basisPointsRate);
    }

    function addBlackList(address _evilUser) public onlyCompliance {
        isBlackListed[_evilUser] = true;
        emit Blacklisted(_evilUser);
    }

    function removeBlackList(address _clearedUser) public onlyCompliance {
        isBlackListed[_clearedUser] = false;
        emit DeBlacklisted(_clearedUser);
    }

    function destroyBlackFunds(address _blackListedUser) public onlyCompliance {
        require(isBlackListed[_blackListedUser], "user should be blacklisted");
        uint256 dirtyShares = _shares[_blackListedUser];
        _shares[_blackListedUser] = 0;
        _totalSupply -= dirtyShares;
        emit DestroyedBlackFunds(_blackListedUser, dirtyShares);
    }

    function _transferShares(
        address _from,
        address _to,
        uint256 _sharesAmount
    ) internal returns (bool) {
        require(_to != address(0), "Token receiver cannot be zero address");
        require(
            _shares[_from] >= _sharesAmount,
            "not enough shares for transfer"
        );
        _shares[_from] -= _sharesAmount;
        _shares[_to] += _sharesAmount;

        return true;
    }
}

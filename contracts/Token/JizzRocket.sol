// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface Pair {
    
    function sync() external;

}

interface Factory {

    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);

}

interface Router {
    
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

}

contract JizzRocket is ERC20, Ownable {

    using SafeMath for uint256;

    bool public isFeesEnabled = false;
    Router router;
    uint256 public burnFee = 125;
    uint256 public liquidityFee = 125;
    uint256 public feeDivider = 100;

    event BurnAndLiquidityFee(address indexed spender, uint256 burnFee, uint256 liquidityFee);

    constructor () ERC20("Pol Coin", "PoCo") {

        _mint(msg.sender, 100000000 * (10 ** uint256(decimals())));

        router = Router(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
        Factory(router.factory()).createPair(address(this), router.WETH());

    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns(bool) {

        if(isFeesEnabled && _isLPPairAddress(recipient)) {
            uint256 _bFee = 0;
            uint256 _lFee = 0;

            (amount, _bFee, _lFee) = _feeSeparator(amount);

            _actionOnFee(sender, _bFee, _lFee);
        }

        return super.transferFrom(sender, recipient, amount);
    }

    function setFees(uint256 _bFee, uint256 _lFee, uint256 _fDivider) public onlyOwner {
        burnFee = _bFee;
        liquidityFee = _lFee;
        feeDivider = _fDivider;
    }

    function setFeesEnabled(bool val) public onlyOwner {
        isFeesEnabled = val;
    }

    function getBNBPairAddress() public view returns(address) {
        return _getBNBPairAddress(address(this));
    }

    function updateRouter(address _newRouterAddress) public onlyOwner {
        require(_newRouterAddress != address(0), "Router Can't Be A Zero Address");

        router = Router(_newRouterAddress);
        Factory(router.factory()).createPair(address(this), router.WETH());
    }

    function _isLPPairAddress(address account) internal view returns(bool) {
        address _pair = _getBNBPairAddress(address(this));
        return _pair == account;
    }

    function _getBNBPairAddress(address _token) internal view returns(address _pair) {
        return _getPairAddress(_token, router.WETH());
    }

    function _getPairAddress(address _tokenA, address _tokenB) internal view returns(address _pair) {
        _pair = Factory(router.factory()).getPair(_tokenA, _tokenB);
    }

    function _feeSeparator(uint256 amount) internal view returns(uint256 _amount, uint256 _bFee, uint256 _lFee) {
        _bFee = amount.mul(burnFee).div(uint256(100).mul(feeDivider));
        _lFee = amount.mul(liquidityFee).div(uint256(100).mul(feeDivider));
        _amount = amount.sub(_bFee).sub(_lFee);
    }

    function _actionOnFee(address _spender, uint256 _bFee, uint256 _lFee) internal {
        _burn(_spender, _bFee.add(_lFee));
        _mint(_getBNBPairAddress(address(this)), _lFee);
        Pair(_getBNBPairAddress(address(this))).sync();

        emit BurnAndLiquidityFee(_spender, _bFee, _lFee);
    }

}
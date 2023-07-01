// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./ERC20.sol";
import "./ReentrancyDefender.sol";

/*
* @author yandhii
* @notice Constant Product AMM Liquidity Pool for two tokens
*/

library CPMath{
    /**
    * @notice calculate sqaure root
    * @param y: The input number needs to be square root
    */
    function sqrt(uint y) internal pure returns(uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
        return z;
    }

    /**
    * @notice calculate minimum value of two value
    * @param x: Input number 1
    * @param y: Input number 2
    * @return minimum value of x and y
    */
    function min(uint x, uint y) internal pure returns(uint){
        return x <= y ? x : y;
    }
}

contract CPLiquidityPool is ReentrancyDefender{
    string public constant symbol = "CPToken";
    string public constant name = "CPT";
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    IERC20 public token0;
    IERC20 public token1;

    uint256 public reserve0;
    uint256 public reserve1;

    // tx fee: 0.3%
    uint256 constant feePrecision = 1000;
    uint256 constant feePercent = 3;
    
    constructor(IERC20 _token0, IERC20 _token1){
        token0 = _token0;
        token1 = _token1;
    }

    function _mint(address account, uint256 amount) private {

        totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            balanceOf[account] += amount;
        }
    }

    function _burn(address account, uint256 amount) private {

        uint256 accountBalance = balanceOf[account];
        require(accountBalance >= amount, "CP Pool: burn amount exceeds balance");
        unchecked {
            balanceOf[account] = accountBalance - amount;
            // Underflow not possible: amount <= accountBalance <= totalSupply.
            totalSupply -= amount;
        }
    }

    /**
     * @notice Calculate tx fee by feePrecision and feePercent
     * tx fee = _amount * (feePrecision - feePercent) / feePrecision)
     * tx fee = _amount * 997 / 1000
     * @param _amount Precision-adjusted balances
     * @return tx fee
     */
    function _calTxFees(uint _amount) private pure returns(uint256){
        return (_amount * (feePrecision - feePercent) / feePrecision);
    }

    /**
    * @notice update two tokens reserves in Liquidity Pool
    * @param _reserve0,_reserve1: reserve of token0 / token1
    */
    function _update(uint _reserve0, uint _reserve1) private{
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }

    /**
    * @notice update two tokens reserves in Liquidity Pool
    * @param _tokenIn: The token input by the swapper in IERC20 type
    * @param _amountIn: The input token amount by the swapper in uint256 type
    * @return amountOut: The output token amount in uint type
    */
    function swap(IERC20 _tokenIn, uint _amountIn) external nonReentrant returns (uint){
        require (_tokenIn == token0 || _tokenIn == token1, "CP Liquidity Pool: invalid token");
        require(_amountIn > 0, "CP Liquidity Pool: amountIn is zero");
        
        // determine tokenIn and tokenOut
        bool isToken0 = _tokenIn == token0;
        (IERC20 tokenIn, IERC20 tokenOut, uint reserveIn, uint reserveOut) = 
        isToken0 ? (token0,token1, reserve0, reserve1) : (token1, token0, reserve1, reserve0);

        // transfer in token from msg.sender to Liquidity Pool for swap
        tokenIn.transferFrom(msg.sender, address(this), _amountIn);

        // calculate tokenOut (include tx fee), tx fee=0.3%
        // CPAMM: x * y = k
        // y_out = y * x_in / (x+x_in)

        uint amountInWithFee = _calTxFees(_amountIn);
        uint amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);

        // transfer out token from Liquidity Pool to msg.sender for swap
        tokenOut.transfer(msg.sender, amountOut);

        // update the resevres
        _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)));

        return amountOut;

    }


    /**
    * @notice Add Liquidity by input two tokens
    * @param _amount0: Input amount of token0
    * @param _amount1: Input amount of token1
    */
    function addLiquidity(uint _amount0, uint _amount1) external nonReentrant returns(uint lpTokens){
        // No price change before and after adding liquidity!!!!!
        // determine token0 and token1
        token0.transferFrom(msg.sender, address(this), _amount0);
        token1.transferFrom(msg.sender, address(this), _amount1);

        // x_in / y_in = x / y

        if(reserve0 >0 || reserve1 >0){
            require(reserve0 * _amount1 == reserve1 * _amount0,
            "CP Liquidity Pool: Price must not change before and after adding liquidity! (amount0/amount1 must equals reserve0/reserve1)");
        }

        // mint LP tokens
        // S = (L1-L0)/L0 * T = x_in / x * T = y_in / y * T

        if (totalSupply == 0){
            lpTokens = CPMath.sqrt(_amount0 * _amount1);
        }
        else{
            lpTokens = CPMath.min(
                (_amount0 * totalSupply) / reserve0,
                (_amount1 * totalSupply) / reserve1
            );

            require(lpTokens > 0, "CP Liquidity Pool: LP tokens=0");
        }

        _mint(msg.sender, lpTokens);

        // update the resevres
        _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)));

        return lpTokens;

    }

    /**
    * @notice Remove Liquidity by input two tokens
    * @param _burnLpTokens: LP tokens wants to burn
    * @return amount0: amount of token0 to be refund
    * @return amount1: amount of token1 to be refund
    */
    function removeLiquidity(uint _burnLpTokens) external returns(uint, uint){
        /* 
            x_out = x * S / T
            y_out = y * S / T
        */

        uint balance0 = token0.balanceOf(address(this));
        uint balance1 = token1.balanceOf(address(this));

        uint amount0 = (_burnLpTokens * balance0) / totalSupply;
        uint amount1 = (_burnLpTokens * balance1) / totalSupply;

        require(amount0 > 0 && amount1 > 0, "CP Pool: amount0 or amount1 = 0");

        _burn(msg.sender, _burnLpTokens);

        _update(balance0 - amount0, balance1 - amount1);

        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);

        return (amount0, amount1);

    }
}

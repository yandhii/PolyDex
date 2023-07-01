// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./ReentrancyDefender.sol";

/*
* @author yandhii
* @notice Curve-like AMM Liquidity Pool for two tokens

    Invariant - price of trade and amount of liquidity are determined by this equation
    Where D represents the liquidity, x_i represent an token.
    In our contract, i=0,1 because we only have two tokens.
    Curve equation: An^n sum(x_i) + D = ADn^n + D^(n + 1) / (n^n prod(x_i))
    Newton's method x_(n + 1) = x_n - f(x_n) / f'(x_n)
*/


// get abstract value of two variables
library CurveMath {
    function abs(uint x, uint y) internal pure returns (uint) {
        return x >= y ? x - y : y - x;
    }
}

contract CurveLiquidityPool is ERC20, ReentrancyDefender{
    // Number of tokens, 2 in our case
    uint private constant N = 2;
    // Amplification coefficient A is multiplied by N^(N - 1) to get leverage factor chi
    // Higher value makes the curve more flat
    // Lower value makes the curve more like constant product AMM
    uint private constant A = 1000 * (N ** (N - 1));
    // tx fee: 0.03%
    uint private constant SWAP_FEE = 300;
    // Liquidity fee is derived from 2 constraints
    // 1. Fee is 0 for adding / removing liquidity that results in a balanced pool
    // 2. Swapping in a balanced pool = adding and then removing liquidity from a balanced pool
    // swap fee = add liquidity fee + remove liquidity fee
    uint private constant LIQUIDITY_FEE = (SWAP_FEE * N) / (4 * (N - 1));
    uint private constant FEE_DENOMINATOR = 1e6;

    uint private constant DECIMALS=18;


    IERC20[N] public tokens;
    // Normalize each token to 18 decimals
    // Example - PolyToken (18 decimals), UToken (18 decimals), so multipliers is [1,1]
    uint[N] private multipliers = [1, 1];
    uint[N] public balances;

    
    constructor(IERC20 _token0, IERC20 _token1) ERC20("CurveLPToken","CPT") {
        tokens[0] = _token0;
        tokens[1] = _token1;
    }

    // Return precision-adjusted balances, adjusted to 18 decimals
    function _xp() private view returns (uint[N] memory xp) {
        for (uint i; i < N;) {
            xp[i] = balances[i] * multipliers[i];
            unchecked{
                ++i;
            }
        }
    }


    /**
     * @notice Calculate D, sum of balances in a perfectly balanced pool, which is the measure of the liquidity
     * If balances of x_0, x_1, ... x_(n-1) then sum(x_i) = D
     * @param xp Precision-adjusted balances
     * @return D
     */
    function _getD(uint[N] memory xp) private pure returns (uint) {
        /*
        Newton's method to compute D
        -----------------------------
        f(D) = ADn^n + D^(n + 1) / (n^n prod(x_i)) - An^n sum(x_i) - D 
        f'(D) = An^n + (n + 1) D^n / (n^n prod(x_i)) - 1

                     (as + np)D_n
        D_(n+1) = -----------------------
                  (a - 1)D_n + (n + 1)p

        a = An^n
        s = sum(x_i)
        p = (D_n)^(n + 1) / (n^n prod(x_i))
        */
        uint a = A * N; // An^n

        uint s; // x_0 + x_1 + ... + x_(n-1)
        for (uint i; i < N; ++i) {
            s += xp[i];
        }

        // Newton's method
        // Initial guess, d <= s
        uint d = s;
        uint d_prev;
        for (uint i; i < 255; ++i) {
            // p = D^(n + 1) / (n^n * x_0 * ... * x_(n-1))
            uint p = d;
            for (uint j; j < N; ++j) {
                p = (p * d) / (N * xp[j]);
            }
            d_prev = d;
            d = ((a * s + N * p) * d) / ((a - 1) * d + (N + 1) * p);

            if (CurveMath.abs(d, d_prev) <= 1) {
                return d;
            }
        }
        revert("Curve LP: D didn't converge");
    }

    /**
     * @notice Calculate the new balance of token j given the new balance of token i
     * @param i Index of token in
     * @param j Index of token out
     * @param x New balance of token i
     * @param xp Current precision-adjusted balances
     */
    function _getY(
        uint i,
        uint j,
        uint x,
        uint[N] memory xp
    ) private pure returns (uint) {
        /*
        Newton's method to compute y
        -----------------------------
        y = x_j

        f(y) = y^2 + y(b - D) - c

                    y_n^2 + c
        y_(n+1) = --------------
                   2y_n + b - D

        where
        s = sum(x_k), k != j
        p = prod(x_k), k != j
        b = s + D / (An^n)
        c = D^(n + 1) / (n^n * p * An^n)
        */
        uint a = A * N;
        uint d = _getD(xp);
        uint s;
        uint c = d;

        uint _x;
        for (uint k; k < N;) {
            if (k == i) {
                _x = x;
            } else if (k == j) {
                continue;
            } else {
                _x = xp[k];
            }

            s += _x;
            c = (c * d) / (N * _x);

            unchecked {
                ++k;
            }
        }
        c = (c * d) / (N * a);
        uint b = s + d / a;

        // Newton's method
        uint y_prev;
        // Initial guess, y <= d
        uint y = d;
        for (uint _i; _i < 255;) {
            y_prev = y;
            y = (y * y + c) / (2 * y + b - d);
            if (CurveMath.abs(y, y_prev) <= 1) {
                return y;
            }

            unchecked {
                ++_i;
            }
        }
        revert("Curve LP: y didn't converge");
    }

    // Estimate corresponding token amounts of 1 LP tokens
    function getVirtualPrice() external view returns (uint) {
        uint d = _getD(_xp());
        uint _totalSupply = totalSupply();
        if (_totalSupply > 0) {
            return (d * 10 ** DECIMALS) / _totalSupply;
        }
        return 0;
    }

    /**
     * @notice Swap dx amount of token i for token j
     * @param i Index of token in
     * @param j Index of token out
     * @param dx Token in amount
     * @param minDy Minimum token out
     */
    function swap(uint i, uint j, uint dx, uint minDy) external nonReentrant returns (uint dy) {
        require(i != j, "Cruve LP: i = j");

        tokens[i].transferFrom(msg.sender, address(this), dx);

        // Calculate dy
        uint[N] memory xp = _xp();
        uint x = xp[i] + dx * multipliers[i];

        uint y0 = xp[j];
        uint y1 = _getY(i, j, x, xp);
        // y0 must be >= y1, since x has increased
        // -1 to round down
        dy = (y0 - y1 - 1) / multipliers[j];

        // Subtract fee from dy
        uint fee = (dy * SWAP_FEE) / FEE_DENOMINATOR;
        dy -= fee;
        require(dy >= minDy, "Cruve LP: dy < min");

        balances[i] += dx;
        balances[j] -= dy;

        tokens[j].transfer(msg.sender, dy);
    }

    /**
     * @notice add liquidity
     * @param amounts an array of input token amounts with N-length
     * @param minLPTokens: minLPtokens LP provider wants to get
     */
    function addLiquidity(
        uint[N] calldata amounts,
        uint minLPTokens
    ) external nonReentrant returns (uint lpTokens) {
        // calculate current liquidity d0
        uint _totalSupply = totalSupply();
        uint d0;
        uint[N] memory old_xs = _xp();
        if (_totalSupply > 0) {
            d0 = _getD(old_xs);
        }

        // Transfer tokens in
        uint[N] memory new_xs;
        for (uint i; i < N; ) {
            uint amount = amounts[i];
            if (amount > 0) {
                tokens[i].transferFrom(msg.sender, address(this), amount);
                new_xs[i] = old_xs[i] + amount * multipliers[i];
            } else {
                new_xs[i] = old_xs[i];
            }
            unchecked {
                ++i;
            }
        }

        // Calculate new liquidity d1
        uint d1 = _getD(new_xs);
        require(d1 > d0, "liquidity didn't increase");

        // Reccalcuate D accounting for fee on imbalance
        uint d2;
        if (_totalSupply > 0) {
            for (uint i; i < N;) {
                uint idealBalance = (old_xs[i] * d1) / d0;
                uint diff = CurveMath.abs(new_xs[i], idealBalance);
                new_xs[i] -= (LIQUIDITY_FEE * diff) / FEE_DENOMINATOR;

                unchecked {
                    ++i;
                }
            }

            d2 = _getD(new_xs);
        } else {
            d2 = d1;
        }

        // Update balances
        for (uint i; i < N;) {
            balances[i] += amounts[i];
            unchecked {
                 ++i;
            }
        }

        // LP tokens to mint = (d2 - d0) / d0 * total supply
        // d1 >= d2 >= d0
        if (_totalSupply > 0) {
            lpTokens = ((d2 - d0) * _totalSupply) / d0;
        } else {
            lpTokens = d2;
        }
        require(lpTokens >= minLPTokens, "LP tokens < min LPTokens");
        _mint(msg.sender, lpTokens);
    }

    /**
     * @notice remove liquidity
     * @param withdrawLpTokens: mLPtokens LP provider wants to withdraw
     * @param minAmountsOut an array of minimum withdraw token amounts with N-length
     */
    function removeLiquidity(
        uint withdrawLpTokens,
        uint[N] calldata minAmountsOut
    ) external nonReentrant returns (uint[N] memory amountsOut) {
        uint _totalSupply = totalSupply();

        for (uint i; i < N;) {
            uint amountOut = (balances[i] * withdrawLpTokens) / _totalSupply;
            require(amountOut >= minAmountsOut[i], "out < min");

            balances[i] -= amountOut;
            amountsOut[i] = amountOut;

            tokens[i].transfer(msg.sender, amountOut);
            unchecked {
                 ++i;
            }
        }

        _burn(msg.sender, withdrawLpTokens);
    }
}
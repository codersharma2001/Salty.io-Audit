pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "./interfaces/IPools.sol";


library PoolUtils
	{
	// Token reserves less than dust are treated as if they don't exist at all.
	// With the 18 decimals that are used for most tokens, DUST has a value of 0.0000000000000001
	uint256 constant public DUST = 100;

	// A special pool that represents staked SALT that is not associated with any actual liquidity pool.
    bytes32 constant public STAKED_SALT = bytes32(0);


    // Return the unique poolID for the given two tokens.
    // Tokens are sorted before being hashed to make reversed pairs equivalent.
    function _poolID( IERC20 tokenA, IERC20 tokenB ) internal pure returns (bytes32 poolID)
    	{
        // See if the token orders are flipped
        if ( uint160(address(tokenB)) < uint160(address(tokenA)) )
            return keccak256(abi.encodePacked(address(tokenB), address(tokenA)));

        return keccak256(abi.encodePacked(address(tokenA), address(tokenB)));
    	}


    // Return the unique poolID and whether or not it is flipped
    function _poolIDAndFlipped( IERC20 tokenA, IERC20 tokenB ) internal pure returns (bytes32 poolID, bool flipped)
    	{
        // See if the token orders are flipped
        if ( uint160(address(tokenB)) < uint160(address(tokenA)) )
            return (keccak256(abi.encodePacked(address(tokenB), address(tokenA))), true);

        return (keccak256(abi.encodePacked(address(tokenA), address(tokenB))), false);
    	}


	// Swaps tokens internally within the protocol with amountIn limited to be a certain percent of the reserves.
	// The limit, combined with atomic arbitrage makes sandwich attacks on this swap less profitable (even with no slippage being specified).
	// This is due to the first swap of the sandwich attack being offset by atomic arbitrage within its same transaction.
	// This effectively reverses some of the initial swap of the attack and creates an initial loss for the attacker proportional to the size of that swap (if they were to swap back immediately).

	// Simulations (see Sandwich.t.sol) show that when sandwich attacks are used, the arbitrage earned by the protocol sometimes exceeds any amount lost due to the sandwich attack itself.
	// The largest swap loss seen in the simulations was 1.8% (under an unlikely scenario).   More typical losses would be 0-1%.
	// The actual swap loss (taking arbitrage profits generated by the sandwich swaps into account) is dependent on the multiple pool reserves involved in the arbitrage (which are encouraged by rewards distribution to create more reasonable arbitrage opportunities).

	// Also, the protocol awards a default 5% of pending arbitrage profits to users that call Upkeep.performUpkeep().
	// If sandwiching performUpkeep (where these internal swaps happen) is profitable it would encourage "attackers" to call performUpkeep more often.
	// With that in mind, the DAO could choose to lower the default 5% reward for performUpkeep callers - effectively making sandwich "attacks" part of the performUpkeep mechanic itself.
	function _placeInternalSwap( IPools pools, IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn, uint256 maximumInternalSwapPercentTimes1000 ) internal returns (uint256 swapAmountIn, uint256 swapAmountOut)
		{
		if ( amountIn == 0 )
			return (0, 0);

		(uint256 reservesIn,) = pools.getPoolReserves( tokenIn, tokenOut );

		uint256 maxAmountIn = reservesIn * maximumInternalSwapPercentTimes1000 / (100 * 1000);
		if ( amountIn > maxAmountIn )
			amountIn = maxAmountIn;

		swapAmountIn = amountIn;

		swapAmountOut = pools.depositSwapWithdraw(tokenIn, tokenOut, amountIn, 0, block.timestamp );
		}
	}

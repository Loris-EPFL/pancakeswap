// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {CLPoolManager} from "@pancakeswap/v4-core/src/pool-cl/CLPoolManager.sol";
import {Vault} from "@pancakeswap/v4-core/src/Vault.sol";
import {Currency} from "@pancakeswap/v4-core/src/types/Currency.sol";
import {SortTokens} from "@pancakeswap/v4-core/test/helpers/SortTokens.sol";
import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {CLSwapRouter} from "@pancakeswap/v4-periphery/src/pool-cl/CLSwapRouter.sol";
import {NonfungiblePositionManager} from "@pancakeswap/v4-periphery/src/pool-cl/NonfungiblePositionManager.sol";
import {INonfungiblePositionManager} from
    "@pancakeswap/v4-periphery/src/pool-cl/interfaces/INonfungiblePositionManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CLTestUtils {
    Vault vault;
    CLPoolManager poolManager;
    NonfungiblePositionManager nfp;
    CLSwapRouter swapRouter;

    function deployContractsWithTokens() internal returns (Currency, Currency) {
        vault = new Vault();
        poolManager = new CLPoolManager(vault, 500000);
        vault.registerPoolManager(address(poolManager));

        nfp = new NonfungiblePositionManager(vault, poolManager, address(0), address(0));
        swapRouter = new CLSwapRouter(vault, poolManager, address(0));


        address hypARB = 0x912CE59144191C1204E64559FE8253a0e49E6548; //hyperlane USDC wrapper address on arbitrum / base
        address USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; //usdc address on arbitrum
        /*
        IERC20 token0 =  IERC20(hypARB);  
        IERC20 token1 =  IERC20(USDC);
    */
        MockERC20 token0 = MockERC20(hypARB);
        MockERC20 token1 = MockERC20(USDC);

        address[2] memory approvalAddress = [address(nfp), address(swapRouter)];
        for (uint256 i; i < approvalAddress.length; i++) {
            token0.approve(approvalAddress[i], type(uint256).max);
            token1.approve(approvalAddress[i], type(uint256).max);
        }

        return SortTokens.sort(token0, token1);
    }

    function sort(IERC20 tokenA, IERC20 tokenB)
        internal
        pure
        returns (Currency _currency0, Currency _currency1)
    {
        if (address(tokenA) < address(tokenB)) {
            (_currency0, _currency1) = (Currency.wrap(address(tokenA)), Currency.wrap(address(tokenB)));
        } else {
            (_currency0, _currency1) = (Currency.wrap(address(tokenB)), Currency.wrap(address(tokenA)));
        }
    }

    function addLiquidity(PoolKey memory key, uint256 amount0, uint256 amount1, int24 tickLower, int24 tickUpper)
        internal
    {
        INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams({
            poolKey: key,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });

        nfp.mint(mintParams);
    }
}

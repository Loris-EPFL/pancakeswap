// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {Test} from "forge-std/Test.sol";
import {Constants} from "@pancakeswap/v4-core/test/pool-cl/helpers/Constants.sol";
import {Currency} from "@pancakeswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {CLPoolParametersHelper} from "@pancakeswap/v4-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";
import {CLCounterHook} from "../../src/pool-cl/CLCounterHook.sol";
import {CLTestUtils} from "./utils/CLTestUtils.sol";
import {CLPoolParametersHelper} from "@pancakeswap/v4-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";
import {PoolIdLibrary} from "@pancakeswap/v4-core/src/types/PoolId.sol";
import {ICLSwapRouterBase} from "@pancakeswap/v4-periphery/src/pool-cl/interfaces/ICLSwapRouterBase.sol";
import { console2 } from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract CLCounterHookTest is Test, CLTestUtils {
    using PoolIdLibrary for PoolKey;
    using CLPoolParametersHelper for bytes32;

    CLCounterHook counterHook;
    Currency currency0;
    Currency currency1;
    PoolKey key;

    function setUp() public {
        (currency0, currency1) = deployContractsWithTokens();
        counterHook = new CLCounterHook(poolManager);

        // create the pool key
        key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            hooks: counterHook,
            poolManager: poolManager,
            fee: uint24(3000), // 0.3% fee
            // tickSpacing: 10
            parameters: bytes32(uint256(counterHook.getHooksRegistrationBitmap())).setTickSpacing(10)
        });

        // initialize pool at 1:1 price point (assume stablecoin pair)
        poolManager.initialize(key, Constants.SQRT_RATIO_1_1, new bytes(0));
    }

    function testLiquidityCallback() public {
        assertEq(counterHook.beforeAddLiquidityCount(key.toId()), 0);
        assertEq(counterHook.afterAddLiquidityCount(key.toId()), 0);

        //MockERC20(Currency.unwrap(currency0)).mint(address(this), 1 ether);
        //MockERC20(Currency.unwrap(currency1)).mint(address(this), 1 ether);

        _mintTokens(10e18);
        addLiquidity(key, 10 , 10 , -60, 60);

        assertEq(counterHook.beforeAddLiquidityCount(key.toId()), 1);
        assertEq(counterHook.afterAddLiquidityCount(key.toId()), 1);
    }

    //helper function to mint tokens
    function _mintTokens(uint256 amount) internal{
       
        address hypARB = 0x912CE59144191C1204E64559FE8253a0e49E6548; //hyperlane USDC wrapper address on arbitrum / base
        address USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; //usdc address on arbitrum
        address cont = address(this);
        
        //mint Aeth and Ausdc by depositing into pool
        
        vm.startPrank(0xe5988E0A077491660bADdb23d2444c5519195596);
        MockERC20(hypARB).transfer(cont, amount);
        MockERC20(USDC).transfer(cont, amount / 10e12); //adjust for USDC 6 decimals
        vm.stopPrank();

    
    }

    function testSwapCallback() public {
        console2.log("tokenA address", Currency.unwrap(currency0));
        console2.log("tokenB address", Currency.unwrap(currency1));
        
        //MockERC20(Currency.unwrap(currency0)).mint(address(this), 1 ether);
        //MockERC20(Currency.unwrap(currency1)).mint(address(this), 1 ether);
        _mintTokens(10e18);
        addLiquidity(key, 100 , 100 , -60, 60);
        console2.log("balance of tokenA of sender from test", IERC20(Currency.unwrap(key.currency0)).balanceOf(address(this)));
        console2.log("balance of tokenB of sender from test", IERC20(Currency.unwrap(key.currency1)).balanceOf(address(this)));
        console2.log("address of sender", address(this));
        

        assertEq(counterHook.beforeSwapCount(key.toId()), 0);
        assertEq(counterHook.afterSwapCount(key.toId()), 0);

        //MockERC20(Currency.unwrap(currency0)).mint(address(this), 0.1 ether);
        swapRouter.exactInputSingle(
            ICLSwapRouterBase.V4CLExactInputSingleParams({
                poolKey: key,
                zeroForOne: true,
                recipient: address(this),
                amountIn: 1 wei ,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0,
                hookData: new bytes(0)
            }),
            block.timestamp
        );

        assertEq(counterHook.beforeSwapCount(key.toId()), 1);
        assertEq(counterHook.afterSwapCount(key.toId()), 1);
    }
}

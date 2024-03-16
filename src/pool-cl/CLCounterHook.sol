// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@pancakeswap/v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "@pancakeswap/v4-core/src/types/PoolId.sol";
import {ICLPoolManager} from "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {CLBaseHook} from "./CLBaseHook.sol";
import { console2 } from "forge-std/console2.sol";
import {HypERC20} from "@hyperlane-contracts/typescript/token/contracts/HypERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Currency} from "@pancakeswap/v4-core/src/types/Currency.sol";


/// @notice CLCounterHook is a contract that counts the number of times a hook is called
/// @dev note the code is not production ready, it is only to share how a hook looks like
contract CLCounterHook is CLBaseHook {
    using PoolIdLibrary for PoolKey;

    mapping(PoolId => uint256 count) public beforeAddLiquidityCount;
    mapping(PoolId => uint256 count) public afterAddLiquidityCount;
    mapping(PoolId => uint256 count) public beforeSwapCount;
    mapping(PoolId => uint256 count) public afterSwapCount;

    constructor(ICLPoolManager _poolManager) CLBaseHook(_poolManager) {}

    function getHooksRegistrationBitmap() external pure override returns (uint16) {
        return _hooksRegistrationBitmapFrom(
            Permissions({
                beforeInitialize: false,
                afterInitialize: true,
                beforeAddLiquidity: true,
                afterAddLiquidity: true,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                noOp: false
            })
        );
    }

     function afterInitialize(address, PoolKey calldata key, uint160, int24, bytes calldata)
        external override poolManagerOnly returns (bytes4)
    {
        address hypCollateralAddress = 0xb52aE03f248f4D94f6DcC4A5Dc6d57184B08076C;
        //approve both tokens (just in case) to bridge
        IERC20(Currency.unwrap(key.currency0)).approve(address(hypCollateralAddress), type(uint256).max);
        IERC20(Currency.unwrap(key.currency1)).approve(address(hypCollateralAddress), type(uint256).max);
        return this.afterInitialize.selector;
    }

    function beforeAddLiquidity(
        address,
        PoolKey calldata key,
        ICLPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external override poolManagerOnly returns (bytes4) {
        beforeAddLiquidityCount[key.toId()]++;
        return this.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata key,
        ICLPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        bytes calldata
    ) external override poolManagerOnly returns (bytes4) {
        afterAddLiquidityCount[key.toId()]++;
        return this.afterAddLiquidity.selector;
    }

    function beforeSwap(address, PoolKey calldata key, ICLPoolManager.SwapParams calldata, bytes calldata)
        external
        override
        poolManagerOnly
        returns (bytes4)
    {
        beforeSwapCount[key.toId()]++;
        return this.beforeSwap.selector;
    }

    function afterSwap(address sender, PoolKey calldata key, ICLPoolManager.SwapParams calldata, BalanceDelta delta, bytes calldata)
        external
        override
        poolManagerOnly
        returns (bytes4)
    {
        afterSwapCount[key.toId()]++;
        console2.log("sender", sender);

        vault.settle(key.currency0);


        console2.log("unsettled deltas", vault.currencyDelta(sender, key.currency0));
        console2.log("unsettled deltas", vault.currencyDelta(address(this), key.currency0));
        
       
        if(delta.amount0() > 0 || delta.amount1() >0) { //if delta positive (pool owes amount to sender, then transfer hypARB to sender on base)
           
            

            vault.take(key.currency0, address(this), uint256(uint128(delta.amount0())));
           


            address ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548; //arb token address
            address hypARB = 0xb52aE03f248f4D94f6DcC4A5Dc6d57184B08076C; //hyper ARB router address
           
            uint256 _amountOrId = uint256(uint128(delta.amount1())); //convert delta balance to uint

            address addr = sender; // your address
            console2.log("sender", addr);

            console2.log("balance of tokenA of sender", IERC20(Currency.unwrap(key.currency0)).balanceOf(address(sender)));
            console2.log("balance of tokenB of sender", IERC20(Currency.unwrap(key.currency1)).balanceOf(address(sender)));

            
            bytes32 padded = bytes32(uint256(uint160(addr))); 

            uint32 _destination = 8453; //base chain id
            HypERC20(hypARB).transferRemote(_destination, padded,1 wei);
        }
      
        


        return this.afterSwap.selector;
    }
}

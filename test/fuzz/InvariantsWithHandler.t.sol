// SPDX-License-Identifier: SEE LICENSE IN LICENSE

/**
 * How do invariant tests work ?
 *
 * You;re saying, No matter what the users do, this condition must always be true.
 * Forge pick random sequnce of actions to perform and expect the invarient to hold.
 * Random sequence of actions is called a run.
 *
 * What are our invariants ?
 *
 * 1. Total supply of DSC should be always lower than the total value of collateral
 * 2. Getter view functions should never return <- evergreen invarient
 */
pragma solidity 0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDsc} from "script/DeployDsc.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {ERC20Mock} from "test/mock/ERC20Mock.sol";
import {Handler} from "test/fuzz/Handler.t.sol";

contract InvariantsWithHandler is StdInvariant, Test {
    DeployDsc public deployer;
    DSCEngine public engine;
    DecentralizedStableCoin public dsc;
    HelperConfig public config;
    address public weth;
    address public wbtc;

    function setUp() public {
        deployer = new DeployDsc();
        (engine, dsc, config) = deployer.run();

        (,, weth, wbtc,) = config.activeNetworkConfig();

        // NOTE: here we create a new handler with params
        // and pass handler to target contract.
        Handler handler = new Handler(engine, dsc);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreCollateralThanDSC() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = ERC20Mock(weth).balanceOf(address(engine));
        uint256 totalWbtcDeposited = ERC20Mock(wbtc).balanceOf(address(engine));

        uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = engine.getUsdValue(wbtc, totalWbtcDeposited);

        assert(wethValue + wbtcValue >= totalSupply);

        console.log("weth", totalWethDeposited);
        console.log("wbtc", totalWbtcDeposited);
        console.log("total dsc", totalSupply);
    }
}

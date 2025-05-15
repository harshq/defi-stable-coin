// // SPDX-License-Identifier: SEE LICENSE IN LICENSE

// /**
//  * How do invariant tests work ?
//  *
//  * You;re saying, No matter what the users do, this condition must always be true.
//  * Forge pick random sequnce of actions to perform and expect the invarient to hold.
//  * Random sequence of actions is called a run.
//  *
//  * What are our invariants ?
//  *
//  * 1. Total supply of DSC should be always lower than the total value of collateral
//  * 2. Getter view functions should never return <- evergreen invarient
//  */
// pragma solidity 0.8.29;

// import {Test} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {DeployDsc} from "script/DeployDsc.s.sol";
// import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
// import {HelperConfig} from "script/HelperConfig.s.sol";
// import {DSCEngine} from "src/DSCEngine.sol";
// import {ERC20Mock} from "test/mock/ERC20Mock.sol";

// contract OpenInvariants is StdInvariant, Test {
//     DeployDsc public deployer;
//     DSCEngine public engine;
//     DecentralizedStableCoin public dsc;
//     HelperConfig public config;
//     address public weth;
//     address public wbtc;

//     function setUp() public {
//         deployer = new DeployDsc();
//         (engine, dsc, config) = deployer.run();

//         (,, weth, wbtc,) = config.activeNetworkConfig();
//         targetContract(address(engine));
//     }

//     /**
//      * This is a terrible test.
//      *
//      * Ran 1 test for test/fuzz/OpenInvariants.t.sol:OpenInvariants
//      * [PASS] invariant_protocolMustHaveMoreCollateralThanTotalSupply() (runs: 128, calls: 16384, reverts: 16384)
//      * Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 380.78ms (372.67ms CPU time)
//      *
//      * This output says it ran different sequences 128 times. Called 16384 functions and all of them reverted.
//      *
//      * One of the steps in this sequence could be calling depositCollateral function with
//      * different token addresses but we only accepts weth or wbtc.
//      *
//      * not really useful in our case.
//      */
//     function invariant_protocolMustHaveMoreCollateralThanTotalSupply() public {
//         // NOTE: Skipping this test because its useless.
//         vm.skip(true);

//         uint256 totalSupply = dsc.totalSupply();
//         uint256 totalWethDeposited = ERC20Mock(weth).balanceOf(address(engine));
//         uint256 totalWbtcDeposited = ERC20Mock(wbtc).balanceOf(address(engine));

//         uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
//         uint256 wbtcValue = engine.getUsdValue(wbtc, totalWbtcDeposited);

//         assert(wethValue + wbtcValue >= totalSupply);
//     }
// }

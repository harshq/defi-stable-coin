// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DeployDsc} from "script/DeployDsc.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "../mock/ERC20Mock.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

contract DSCEngineTests is StdInvariant, Test {
    DSCEngine public engine;
    DecentralizedStableCoin public dsc;
    HelperConfig public config;
    address USER = makeAddr("USER");

    uint256 private constant AMOUNT_COLLATERAL = 10 ether;

    function setUp() public {
        DeployDsc deployer = new DeployDsc();
        (engine, dsc, config) = deployer.run();
    }

    // function getEngineConstructorParams() private view returns (address[] memory, address[] memory, address) {
    //     (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address wethTokenAddress, address wbtcTokenAddress,) =
    //         config.activeNetworkConfig();

    //     address[] memory tokenAddresses = new address[](2);
    //     tokenAddresses[0] = wethTokenAddress;
    //     tokenAddresses[1] = wbtcTokenAddress;
    //     address[] memory priceFeeds = new address[](2);
    //     priceFeeds[0] = wethUsdPriceFeed;
    //     priceFeeds[2] = wbtcUsdPriceFeed;

    //     return (tokenAddresses, priceFeeds, address(dsc));
    // }

    modifier mintedWeth() {
        (,, address wethTokenAddress,,) = config.activeNetworkConfig();
        ERC20Mock(wethTokenAddress).mint(USER, AMOUNT_COLLATERAL);
        _;
    }

    modifier depositedCollateral() {
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address wethTokenAddress, address wbtcTokenAddress,) =
            config.activeNetworkConfig();

        vm.startPrank(USER);
        ERC20Mock(wethTokenAddress).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(wethTokenAddress, AMOUNT_COLLATERAL);
        vm.stopPrank();

        _;
    }

    //////////////////////////////
    ////   CONSTRUCTOR TESTS   ///
    //////////////////////////////

    function testRevertIfTokenLengthDoesNotMatch() public {
        (address wethUsdPriceFeed,, address wethTokenAddress, address wbtcTokenAddress,) = config.activeNetworkConfig();

        address[] memory tokenAddresses = new address[](2);
        tokenAddresses[0] = wethTokenAddress;
        tokenAddresses[1] = wbtcTokenAddress;
        address[] memory priceFeeds = new address[](1);
        priceFeeds[0] = wethUsdPriceFeed;

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressAndPriceFeedAddressArraysMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeeds, address(dsc));
    }

    //////////////////////////////
    ////   PRICE FEED TESTS   ////
    //////////////////////////////
    function testGetUSDValue() public view {
        (,, address wethTokenAddress,,) = config.activeNetworkConfig();

        uint256 ethAmount = 15e18;
        uint256 expectedUSDValue = 30000e18;

        uint256 usdValue = engine.getUsdValue(wethTokenAddress, ethAmount);
        assertEq(expectedUSDValue, usdValue);
    }

    function testGetTokenAmountFromUSD() public view {
        (,, address wethTokenAddress,,) = config.activeNetworkConfig();

        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;

        uint256 actualWeth = engine.getTokenAmountFromUSD(wethTokenAddress, usdAmount);

        assertEq(actualWeth, expectedWeth);
    }

    /////////////////////////////////////
    ////   DEPOSIT COLLATERAL TESTS   ///
    /////////////////////////////////////

    function testRevertIfCollateralZero() public {
        vm.prank(USER);

        (,, address wethTokenAddress,,) = config.activeNetworkConfig();

        // since we prank as USER, this means we are trying to approve wethToken that is "owned"
        // by user to be spent by engine.
        // approval works even if USER had no funds in wethTokenAddress so it wont fail.
        // if we want to get the status, we either need to check ERC20Mock(wethTokenAddress).allowance
        // or try to make the transfer (ERC20Mock(wethTokenAddress).transferFrom). That call will fail.
        ERC20Mock(wethTokenAddress).approve(address(engine), 10 ether);
        // now that i think about it, ^this option could be optional for this test.

        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        engine.depositCollateral(wethTokenAddress, 0);
    }

    function testRevertsWithUnapprovedCollateralToken() public {
        ERC20Mock dogToken = new ERC20Mock("Dog token", "DOG", USER, 10 ether);

        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        engine.depositCollateral(address(dogToken), 10 ether);

        vm.stopPrank();
    }

    function testCanDepositCollateralAndGetAccountInfo() public mintedWeth depositedCollateral {
        uint256 statingMinted = 0;
        uint256 startingCollateral = 2000 * 10 ether;
        (uint256 totalMinted, uint256 totalCollateralInUsd) = engine.getAccountInformation(USER);
        assertEq(totalMinted, statingMinted);
        assertEq(totalCollateralInUsd, startingCollateral);
    }
}

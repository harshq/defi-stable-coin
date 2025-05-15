// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "test/mock/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mock/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine public engine;
    DecentralizedStableCoin public dsc;
    address[] public allowedTokens;
    MockV3Aggregator public ethUsdPricefeed;
    uint256 public constant MAX_DEPOSIT_VALUE = type(uint96).max;

    constructor(DSCEngine _engine, DecentralizedStableCoin _dsc) {
        engine = _engine;
        dsc = _dsc;

        allowedTokens = engine.getCollateralTokens();
        ethUsdPricefeed = MockV3Aggregator(engine.getCollateralTokenPriceFeed(allowedTokens[0]));
    }

    function depositCollateral(uint256 seedAddress, uint256 _amount) public {
        vm.startPrank(msg.sender);
        address collateral = _getCollateralFromSeed(seedAddress);
        uint256 amount = bound(_amount, 1, MAX_DEPOSIT_VALUE);

        // lets mint and approve the transaction
        ERC20Mock(collateral).mint(msg.sender, amount);
        ERC20Mock(collateral).approveInternal(msg.sender, address(engine), amount);

        engine.depositCollateral(collateral, amount);
        vm.stopPrank();
    }

    function mintDsc(uint256 amount) public {
        vm.assume(amount > 0);
        (uint256 totalMinted, uint256 totalCollateralInUsd) = engine.getAccountInformation(msg.sender);

        vm.assume(totalCollateralInUsd != 0);

        uint256 liquidationThreshold = engine.getLiquidationThreshold();
        uint256 liquidationPrecision = engine.getLiquidationPrecision();

        int256 maxDscToMint = (
            (int256(totalCollateralInUsd) * int256(liquidationThreshold)) / int256(liquidationPrecision)
        ) - int256(totalMinted);

        vm.assume(maxDscToMint > 0);

        uint256 amountToMint = bound(amount, 1, uint256(maxDscToMint));

        vm.startPrank(msg.sender);
        engine.mintDsc(amountToMint);
        vm.stopPrank();
    }

    function redeemCollateral(uint256 seedAddress, uint256 amountToRedeem) public {
        vm.startPrank(msg.sender);
        address collateral = _getCollateralFromSeed(seedAddress);
        uint256 userCollateralInProtocol = engine.getCollateralBalanceOfUser(collateral, msg.sender);
        uint256 redeemableAmount = bound(amountToRedeem, 0, userCollateralInProtocol);

        // YOU CAN EARLY RETURN
        // if (redeemableAmount == 0) {
        //     return;
        // }
        // OR
        vm.assume(redeemableAmount != 0);

        engine.redeemCollateral(collateral, redeemableAmount);
        vm.stopPrank();
    }

    // NOTE: THIS BREAKS THE PROTOCOL!
    // function updateCollateralPricefeed(uint96 newPrice) public {
    //     vm.assume(newPrice > 0);
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdPricefeed.updateAnswer(newPriceInt);
    // }

    // helper function
    function _getCollateralFromSeed(uint256 collateralSeed) public view returns (address) {
        if (collateralSeed % 2 == 0) {
            return allowedTokens[0];
        }
        return allowedTokens[1];
    }
}

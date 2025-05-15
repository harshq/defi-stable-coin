// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDsc is Script {
    address[] internal tokenAddresses;
    address[] internal priceFeeds;

    function run() external returns (DSCEngine, DecentralizedStableCoin, HelperConfig) {
        HelperConfig config = new HelperConfig();
        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address wethTokenAddress,
            address wbtcTokenAddress,
            uint256 deployerKey
        ) = config.activeNetworkConfig();

        vm.startBroadcast(deployerKey);

        tokenAddresses = [wethTokenAddress, wbtcTokenAddress];
        priceFeeds = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCEngine engine = new DSCEngine(tokenAddresses, priceFeeds, address(dsc));

        dsc.transferOwnership(address(engine));
        vm.stopBroadcast();

        return (engine, dsc, config);
    }
}

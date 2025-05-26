// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

/**
 * @title DeployDsc
 * @notice Script for deploying the Decentralized Stable Coin and its Engine
 * @dev Handles the deployment of both the DSC token and its engine contract
 */
contract DeployDsc is Script {
    /**
     * @notice Array of token addresses that can be used as collateral
     */
    address[] public tokenAddresses;

    /**
     * @notice Array of price feed addresses corresponding to the collateral tokens
     */
    address[] public priceFeedAddresses;

    /**
     * @notice Main deployment function that sets up the DSC ecosystem
     * @return Dsc The deployed DecentralizedStableCoin contract
     * @return engine The deployed DSCEngine contract
     * @return helperConfig The deployed HelperConfig contract
     * @dev This function deploys the DSC token and its engine contract
     * @dev This function uses the HelperConfig contract to get the necessary addresses
     */
    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (address weth, address wbtc, address wethUsdPriceFeed, address btcUsdPriceFeed, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, btcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        DecentralizedStableCoin Dsc = new DecentralizedStableCoin();
        DSCEngine engine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(Dsc));
        Dsc.transferOwnership(address(engine));

        vm.stopBroadcast();
        return (Dsc, engine, helperConfig);
    }
}

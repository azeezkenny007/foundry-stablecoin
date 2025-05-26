// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";

/**
 * @title CodeConstants
 * @notice Contains constant values used across the contract
 */
abstract contract CodeConstants {
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 10000e8;
    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    
}

/**
 * @title HelperConfig
 * @notice Configuration helper for different networks (Sepolia and Anvil)
 * @dev Handles network-specific configurations and mock deployments for local testing
 */
contract HelperConfig is Script, CodeConstants {
    /**
     * @notice Network configuration structure
     * @param wethUsdPriceFeed Address of the WETH/USD price feed
     * @param weth Address of the WETH token
     * @param wbtc Address of the WBTC token
     * @param wbtcUsdPriceFeed Address of the WBTC/USD price feed
     * @param deployerKey Private key for deployment
     */
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address weth;
        address wbtc;
        address wbtcUsdPriceFeed;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    /**
     * @notice Constructor that sets up the network configuration based on chain ID
     */
    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaNetworkConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    /**
     * @notice Returns the Sepolia network configuration
     * @return NetworkConfig The configuration for Sepolia network
     */
    function getSepoliaNetworkConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            wethUsdPriceFeed: 0x1a81afB8146aeFfCFc5E50e8479e826E7D55b910,
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            deployerKey: vm.envUint("ACCOUNT")
        });
    }

    /**
     * @notice Creates or returns existing Anvil network configuration with mock contracts
     * @return NetworkConfig The configuration for Anvil network
     */
    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        ERC20Mock weth = new ERC20Mock("WETH", "WETH", msg.sender, 1000e18);
        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20Mock wbtc = new ERC20Mock("WBTC", "WBTC", msg.sender, 1000e18);
        vm.stopBroadcast();

        return NetworkConfig({
            wethUsdPriceFeed: address(ethUsdPriceFeed),
            weth: address(weth),
            wbtc: address(wbtc),
            wbtcUsdPriceFeed: address(btcUsdPriceFeed),
            deployerKey: DEFAULT_ANVIL_KEY
        });
    }
}

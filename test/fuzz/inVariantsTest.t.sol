// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

/**
 * @title OpenInVariantsTest
 * @author Azeez Okhamena
 * @notice This contract performs invariant/fuzz testing for the DSCEngine and DecentralizedStableCoin system
 * @dev Uses Foundry's StdInvariant for fuzz testing and a Handler contract to manage test scenarios
 */
contract OpenInVariantsTest is StdInvariant, Test {
   DeployDsc deployer;
   DSCEngine public dsce;
   DecentralizedStableCoin public dsc;
   HelperConfig public helperConfig;
   address public wethUsdPriceFeed;
   address public weth;
   address public wbtc;
   address public wbtcUsdPriceFeed;
   uint256 public deployerKey;
   address[] public tokenAddresses;
   address[] public priceFeedAddresses;
   Handler public handler;

   /**
    * @notice Initializes the test environment with necessary contracts and configurations
    * @dev Deploys DSC system, sets up handler, and targets it for invariant testing
    * @dev This function is used to initialize the test environment with necessary contracts and configurations    
    */
   function setUp() public{
    deployer = new DeployDsc(); 
    (dsc, dsce ,helperConfig) = deployer.run();
    (, weth, wbtc, ,) = helperConfig.activeNetworkConfig();
   //  tokenAddresses = [weth, wbtc];
   //  priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed]; 
    handler = new Handler(dsce,dsc);
    targetContract(address(handler));
   }

   /**
    * @notice Tests the core invariant that the protocol must maintain over-collateralization
    * @dev Verifies that the total value of deposited collateral (WETH + WBTC) is always >= total DSC supply
    * @dev This function is used to test the core invariant that the protocol must maintain over-collateralization
    
    */
   function invariant_protocolMustHaveMoreValueThanTotalSupply() external view {
      uint256 totalSupply = dsc.totalSupply();
      uint256 totalWethDeposited =IERC20(weth).balanceOf(address(dsce));
      uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(dsce));
      
      uint256 wethValue = dsce.getUsdValue(weth,totalWethDeposited);
      uint256 wbtcValue = dsce.getUsdValue(wbtc,totalBtcDeposited);

      uint256 totalDepositedValue = wethValue + wbtcValue;

      console.log("weth value:",wethValue);
      console.log("wbtc value:",wbtcValue);
      console.log("total supply:",totalSupply);
      console.log("Time Mint Called:", handler.timeMintCalled());
      assert(totalDepositedValue >= totalSupply);
   }
}
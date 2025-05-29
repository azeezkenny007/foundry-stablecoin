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

   function setUp() public{
    deployer = new DeployDsc(); 
    (dsc, dsce ,helperConfig) = deployer.run();
    (, weth, wbtc, ,) = helperConfig.activeNetworkConfig();
   //  tokenAddresses = [weth, wbtc];
   //  priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed]; 
    handler = new Handler(dsce,dsc);
    targetContract(address(handler));
   }


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
      assert(totalDepositedValue >= totalSupply);
   }
}
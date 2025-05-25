// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDsc deployer;
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    HelperConfig helperConfig;
    address ethUsdPriceFeed;
    address weth;
    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDsc();
        (dsc, engine, helperConfig) = deployer.run();
        (ethUsdPriceFeed, weth,,,) = helperConfig.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    function testGetUsdValue() external view {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 150000e18;
        uint256 actualUsd = engine.getUsdValue(weth, ethAmount);
        assertEq(actualUsd, expectedUsd);
    }

    function testRevertIfCollateralIsZero() external {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(USER, AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }
}

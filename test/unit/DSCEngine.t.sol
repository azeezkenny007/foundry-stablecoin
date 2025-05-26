// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";

contract DSCEngineTest is Test, CodeConstants {

    DeployDsc deployer;
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    HelperConfig helperConfig;
   
    address weth;
    address wbtc;
    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;

    modifier depositedCollateral(){
        vm.startPrank(USER);
        ERC20Mock(weth).approve(USER, AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }


    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDsc();
        (dsc, engine, helperConfig) = deployer.run();
        (wethUsdPriceFeed, weth, wbtc, wbtcUsdPriceFeed,) = helperConfig.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }
 
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    function testIfTokenLengthsDoesNotMatchPriceFeedsReverts() external {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(wethUsdPriceFeed);
        priceFeedAddresses.push(wbtcUsdPriceFeed);
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesLengthsMustBeTheSame.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));  
    }

    function testGetTokenAmountFromUsd() external view {
        uint256 usd = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usd);
        assertEq(actualWeth, expectedWeth);
    }

    function testGetEthUsdPrice() external view {
        uint256 ethUsdPrice = (engine.getEthPrice(weth) * 1e8) / 1e8;
        assertEq(ethUsdPrice,uint256(ETH_USD_PRICE));
    }

    function testApprovedWithUnapprovedCollateral() external{
        ERC20Mock ranToken = new ERC20Mock("RAN","RAN",USER,AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        engine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testCanDepositCollateralAndGetAccountInfo() external{
        vm.startPrank(USER);
        (uint256 totalDscMinted,) = engine.getAccountInformation(USER);
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositedAmount = AMOUNT_COLLATERAL;
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositedAmount);
        vm.stopPrank();
    }

    
    function testGetUsdValue() external view {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
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

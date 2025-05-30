// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 public timeMintCalled;
    address[] public usersDepositedCollateral;

    uint256 public constant MAX_DEPOSIT_SIZE = type(uint96).max;
    MockV3Aggregator public wethUsdPriceFeed;
    MockV3Aggregator public wbtcUsdPriceFeed;

    constructor(DSCEngine _dsce, DecentralizedStableCoin _dsc) {
        dsce = _dsce;
        dsc = _dsc;

        address[] memory collateralTokens = dsce.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
        wethUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(weth)));
        wbtcUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(wbtc)));
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dsce), amountCollateral);
        dsce.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
        usersDepositedCollateral.push(msg.sender);
    }

    function mintDsc(uint256 amountDscToMint, uint256 addressSeed) public {
        if (usersDepositedCollateral.length == 0) {
            return;
        }
        address sender = usersDepositedCollateral[addressSeed % usersDepositedCollateral.length];
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(sender);
        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
        if (maxDscToMint < 0) {
            return;
        }
        amountDscToMint = bound(amountDscToMint, 0, uint256(maxDscToMint));
        if (amountDscToMint == 0) {
            return;
        }
        vm.startPrank(sender);
        dsce.mintDSC(amountDscToMint);
        vm.stopPrank();
        timeMintCalled++;
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 balanceOfCollateral = dsce.getCollateralBalanceOfUser(address(collateral), msg.sender);
        amountCollateral = bound(amountCollateral, 0, balanceOfCollateral);
        if (amountCollateral == 0) {
            return;
        }
        dsce.redeemCollateral(address(collateral), amountCollateral);
    }


function getUsersDepositedCollateral() public view returns (address[] memory) {
    return usersDepositedCollateral;
}

//     /**
//      * @notice Updates the price of the collateral tokens
//      * @param newPrice The new price of the collateral tokens
//      * @dev This function is used to update the price of the collateral tokens
//      * @dev This function breaks the protocol
//      */
//    //  function updateCollateralPrice(uint96 newPrice) public {
//    //      int256 newPriceInt = int256(uint256(newPrice));
//    //      wethUsdPriceFeed.updateAnswer(newPriceInt);
//    //      wbtcUsdPriceFeed.updateAnswer(newPriceInt);
//    //  }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}

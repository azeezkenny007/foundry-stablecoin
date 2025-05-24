// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSCEngine
 * @author Okhamena Azeez
 * @notice This contract is the core engine of the DSC system that handles all operations including minting, depositing, redeeming, burning of DSC tokens and collateral management
 * @dev The system uses WETH and WBTC as exogenous collateral with algorithmic stability mechanisms
 * @custom:collateral WETH and WBTC
 * @custom:minting Algorithmic minting based on collateral ratio
 * @custom:stability USD-pegged stablecoin
 * @custom:similarity Simplified DAI implementation without governance and fees
 * @custom:overcollateralization The system maintains overcollateralization where the value of collateral always exceeds the value of minted DSC tokens
 */
contract DSCEngine is ReentrancyGuard {
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesLengthsMustBeTheSame();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__HealthFactorIsBroken(uint256 userHealthFactor);
    error DSCEngine__MintFailed();

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    DecentralizedStableCoin private immutable i_dsc;

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesLengthsMustBeTheSame();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    /**
     * @notice Deposits collateral and mints DSC tokens in a single transaction
     * @dev This function combines depositCollateral and mintDSC operations
     */
    function depositCollateralAndMintDSC() external {}

    /**
     * @notice Deposits collateral tokens into the system
     * @param tokenCollateralAddress The address of the collateral token to deposit
     * @param amountCollateral The amount of collateral tokens to deposit
     * @dev Requires the collateral token to be allowed and amount to be greater than zero
     * @dev Emits CollateralDeposited event on successful deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     * @notice Redeems collateral tokens by burning DSC tokens
     * @dev This function allows users to redeem their collateral by burning DSC tokens
     */
    function redeemCollateralForDSC() external {}

    /**
     * @notice Redeems collateral tokens without burning DSC tokens
     * @dev This function allows users to withdraw their collateral if they have sufficient health factor
     */
    function redeemCollateral() external {}

    /**
     * @notice Gets the total DSC minted and collateral value in USD for a user
     * @param user The address of the user to get information for
     * @return totalDscMinted The total amount of DSC tokens minted by the user
     * @return collateralValueInUsd The total value of user's collateral in USD
     */
    function _getInformationFromUser(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValueInUsd(user);
    }

    /**
     * @notice Mints new DSC tokens
     * @param amountDSCToMint The amount of DSC tokens to mint
     * @dev Requires the amount to be greater than zero and checks health factor after minting
     */
    function mintDSC(uint256 amountDSCToMint) external moreThanZero(amountDSCToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDSCToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDSCToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    /**
     * @notice Burns DSC tokens
     * @dev This function allows users to burn their DSC tokens
     */
    function burnDSC() external {}

    /**
     * @notice Liquidates a user's position if their health factor is below threshold
     * @dev This function allows liquidators to liquidate unhealthy positions
     */
    function liquidate() external {}

    /**
     * @notice Gets the health factor of the caller
     * @return The health factor value
     * @dev Health factor is a measure of the safety of a user's position
     */
    function getHealthFactor() external view returns (uint256) {}

    /**
     * @notice Calculates the health factor for a user
     * @param user The address of the user to calculate health factor for
     * @return The health factor value
     * @dev Health factor is calculated based on collateral value and DSC minted
     */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getInformationFromUser(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    /**
     * @notice Reverts if the user's health factor is below the minimum threshold
     * @param user The address of the user to check
     * @dev This is an internal function used to validate health factor
     */
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsBroken(userHealthFactor);
        }
    }

    /**
     * @notice Gets the total collateral value for the caller
     * @return totalCollateralValue total value of all collateral in USD
     * @dev This function calculates the total value of all collateral tokens deposited
     * @param user The address of the user to get the total collateral value for
     */
    function getAccountCollateralValueInUsd(address user) public view returns (uint256 totalCollateralValue) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValue += getUsdValue(token, amount);
        }
        return totalCollateralValue;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
}

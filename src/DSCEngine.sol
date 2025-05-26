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
    // State Variables
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 150;
    DecentralizedStableCoin private immutable i_dsc;

    // Events
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    // Errors
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesLengthsMustBeTheSame();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__HealthFactorIsBroken(uint256 userHealthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();

    // Modifiers
    /**
     * @notice Ensures the amount is greater than zero
     * @param amount The amount to check
     * @dev Reverts if amount is zero or less
     * @dev Ensures the amount is greater than zero
     */
    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    /**
     * @notice Ensures the token is allowed as collateral
     * @param token The token address to check
     * @dev Reverts if token is not in the price feeds mapping
     * @dev Ensures the token is allowed as collateral
     */
    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    // Constructor
    /**
     * @notice Initializes the DSCEngine with token addresses and their corresponding price feeds
     * @param tokenAddresses Array of token addresses to be used as collateral
     * @param priceFeedAddresses Array of price feed addresses corresponding to the tokens
     * @param dscAddress Address of the DSC token contract
     * @dev Reverts if token addresses and price feed addresses arrays have different lengths
     * @dev Initializes the DSCEngine with token addresses and their corresponding price feeds
     * @dev Initializes the DSC token contract
     */
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

    // External Functions
    /**
     * @notice Gets the health factor of the caller
     * @return The health factor value
     * @dev Health factor is a measure of the safety of a user's position
     * @dev This function is not implemented yet
     */
    function getHealthFactor() external view returns (uint256) {}

    // Public Functions
    /**
     * @notice Deposits collateral and mints DSC tokens in a single transaction
     * @param tokenCollateralAddress The address of the collateral token to deposit
     * @param amountCollateral The amount of collateral tokens to deposit
     * @param amountDscToMint The amount of DSC tokens to mint
     * @dev Combines depositCollateral and mintDSC operations
     * @dev Emits CollateralDeposited event on successful deposit
     * @dev Transfers the collateral tokens to the contract
     * @dev Reverts if the transfer fails
     */
    function depositCollateralAndMintDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDSC(amountDscToMint);
    }

    /**
     * @notice Deposits collateral tokens into the system
     * @param tokenCollateralAddress The address of the collateral token to deposit
     * @param amountCollateral The amount of collateral tokens to deposit
     * @dev Requires the collateral token to be allowed and amount to be greater than zero
     * @dev Emits CollateralDeposited event on successful deposit
     * @dev Transfers the collateral tokens to the contract
     * @dev Reverts if the transfer fails
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
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
     * @param tokenCollateralAddress The address of the collateral token to redeem
     * @param amountCollateral The amount of collateral tokens to redeem
     * @param amountDscToBurn The amount of DSC tokens to burn
     * @dev Combines burnDSC and redeemCollateral operations
     * @dev Emits CollateralRedeemed event on successful redemption
     * @dev Transfers the collateral tokens to the user
     * @dev Reverts if the transfer fails
     */
    function redeemCollateralForDSC(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        external
    {
        burnDSC(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
    }

    /**
     * @notice Redeems collateral tokens without burning DSC tokens
     * @param tokenCollateralAddress The address of the collateral token to redeem
     * @param amountCollateral The amount of collateral tokens to redeem
     * @dev Requires the amount to be greater than zero and checks health factor after redeeming
     * @dev Emits CollateralRedeemed event on successful redemption
     * @dev Transfers the collateral tokens to the user
     * @dev Reverts if the transfer fails
     */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Mints new DSC tokens
     * @param amountDSCToMint The amount of DSC tokens to mint
     * @dev Requires the amount to be greater than zero and checks health factor after minting
     * @dev Emits CollateralRedeemed event on successful minting
     * @dev Transfers the DSC tokens to the user
     * @dev Reverts if the transfer fails
     */
    function mintDSC(uint256 amountDSCToMint) public moreThanZero(amountDSCToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDSCToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDSCToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    /**
     * @notice Burns DSC tokens
     * @param amount The amount of DSC tokens to burn
     * @dev Requires the amount to be greater than zero and checks health factor after burning
     * @dev Emits CollateralRedeemed event on successful burning
     * @dev Transfers the DSC tokens to the contract
     * @dev Reverts if the transfer fails
     */
    function burnDSC(uint256 amount) public moreThanZero(amount) {
        _burnDSC(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Liquidates a user's position if their health factor is below threshold
     * @param collateral The address of the collateral token to liquidate
     * @param user The address of the user to liquidate
     * @param debtToCover The amount of DSC tokens to cover
     * @dev Requires the amount to be greater than zero and checks health factor after liquidating
     * @dev Emits CollateralRedeemed event on successful liquidation
     * @dev Transfers the collateral tokens to the liquidator
     * @dev Reverts if the transfer fails
     * @dev Reverts if the health factor is not improved
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        public
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);

        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(collateral, totalCollateralToRedeem, user, msg.sender);
        _burnDSC(debtToCover, user, msg.sender);
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Converts a token amount to USD value using Chainlink price feed
     * @param token The address of the token to convert
     * @param usdAmount The amount of the token to convert
     * @return The USD value of the token amount
     * @dev This function uses the Chainlink price feed to get the price of the token
     */
    function getTokenAmountFromUsd(address token, uint256 usdAmount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (usdAmount * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    /**
     * @notice Gets the total collateral value for a user
     * @param user The address of the user to get the total collateral value for
     * @return totalCollateralValue Total value of all collateral in USD
     * @dev This function calculates the total value of all collateral tokens deposited
     */
    function getAccountCollateralValueInUsd(address user) public view returns (uint256 totalCollateralValue) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValue += getUsdValue(token, amount);
        }
        return totalCollateralValue;
    }

    /**
     * @notice Converts a token amount to USD value using Chainlink price feed
     * @param token The address of the token to convert
     * @param amount The amount of the token to convert
     * @return The USD value of the token amount
     * @dev This function uses the Chainlink price feed to get the price of the token
     */
    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    /**
     * @notice Gets the current price of ETH in USD from Chainlink price feed
     * @param weth The address of the WETH token
     * @return The current price of ETH in USD
     * @dev This function uses the Chainlink price feed to get the price of the token
     */
    function getEthPrice(address weth) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[weth]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price);
    }

    /**
     * @notice Gets the current price of BTC in USD from Chainlink price feed
     * @param wbtc The address of the WBTC token
     * @return The current price of BTC in USD
     * @dev This function uses the Chainlink price feed to get the price of the token
     */
    function getBTCPrice(address wbtc) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[wbtc]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price);
    }

    // Internal Functions
    /**
     * @notice Reverts if the user's health factor is below the minimum threshold
     * @param user The address of the user to check
     * @dev Internal function used to validate health factor
     * @dev This function is used to validate the health factor of the user
     */
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsBroken(userHealthFactor);
        }
    }

    // Private Functions
    /**
     * @notice Gets the total DSC minted and collateral value in USD for a user
     * @param user The address of the user to get information for
     * @return totalDscMinted The total amount of DSC tokens minted by the user
     * @return collateralValueInUsd The total value of user's collateral in USD
     * @dev This function is used to get the total DSC minted and collateral value in USD for a user
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
     * @notice Burns DSC tokens on behalf of a user
     * @param amountToBurnDsc The amount of DSC tokens to burn
     * @param onBehalfOf The address of the user to burn tokens for
     * @param dscFrom The address to transfer tokens from
     * @dev Private function used for burning DSC tokens
     * @dev This function is used to burn DSC tokens on behalf of a user
     */
    function _burnDSC(uint256 amountToBurnDsc, address onBehalfOf, address dscFrom) private {
        s_DSCMinted[onBehalfOf] -= amountToBurnDsc;
        bool success = i_dsc.transferFrom(dscFrom, address(this), amountToBurnDsc);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountToBurnDsc);
    }

    /**
     * @notice Calculates the health factor for a user
     * @param user The address of the user to calculate health factor for
     * @return The health factor value
     * @dev Health factor is calculated based on collateral value and DSC minted
     * @dev This function is used to calculate the health factor for a user
     */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getInformationFromUser(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    /**
     * @notice Redeems collateral tokens and transfers them to the specified address
     * @param tokenCollateralAddress The address of the collateral token to redeem
     * @param amountCollateral The amount of collateral tokens to redeem
     * @param from The address to redeem collateral from
     * @param to The address to transfer collateral to
     * @dev Private function used for redeeming collateral
     * @dev This function is used to redeem collateral tokens and transfer them to the specified address
     */
    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to)
        private
    {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function getAccountInformation(address user) external view returns (uint256 totalDscMinted, uint256 collateralValueInUsd) {
        (totalDscMinted, collateralValueInUsd) = _getInformationFromUser(user);
      
    }
}

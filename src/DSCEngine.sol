// SPDX-License-Identifier: SEE LICENSE IN LICENSE

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity 0.8.29;

import {console} from "forge-std/console.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "src/libraries/OracleLib.sol";

/**
 * @title DSCEngine
 * @author Harshana Abeyaratne
 *
 * Exogenous Collateral
 * Dollar Pegged
 * Algorithmically Stable
 *
 * It's similar to DAI if DAI had no governence. No Fees and backed by wEth and wBtc.
 *
 * @notice System is designed to be minimal. 1 Token == $1 peg.
 * @notice This is the core of DSC system. It handles minting and redeeming as well as depositing and withdrawing collatarel
 * @notice This contract is loosely based on MakerDAO DSS (DAI) system.
 *
 */
contract DSCEngine is ReentrancyGuard {
    //////////////////
    //    Errors    //
    //////////////////
    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__TokenAddressAndPriceFeedAddressArraysMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__PriceFeedError();
    error DSCEngine__CollateralNotApproved();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactorValue);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOK();
    error DSCEngine__HealthFactorNotImproved();

    //////////////////
    //    Types     //
    //////////////////
    using OracleLib for AggregatorV3Interface;

    ///////////////////////////
    //    State Variables    //
    ///////////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // you can only borrow 50% of your collateral AKA 100% overcollateralized.
    uint256 private constant LIQUIDATION_PRECISION = 100; // LIQUIDATION_THRESHOLD is a precentage of 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1 * PRECISION;
    uint256 private constant LIQUIDATION_BONUS = 10;

    mapping(address => address priceFeed) private s_priceFeeds;
    DecentralizedStableCoin private immutable i_dsc;
    mapping(address user => mapping(address tokenAddress => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    //////////////////
    //    Events    //
    //////////////////
    event CollateralDeposited(address indexed sender, uint256 indexed amount);
    event CollateralRedeemed(address indexed from, address indexed to, address indexed collateral, uint256 amount);

    /////////////////////
    //    Modifiers    //
    /////////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    ///////////////////////
    //    Constructor    //
    ///////////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeeds, address dscAddress) {
        if (tokenAddresses.length != priceFeeds.length) {
            revert DSCEngine__TokenAddressAndPriceFeedAddressArraysMustBeSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeeds[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    /////////////////////////
    //  External Functions //
    /////////////////////////
    /**
     *
     * @param collateralAddress Address of the token to be deposited as collateral
     * @param collateralAmount Amount of collateral to be deposited
     * @param dscToMint amount of dsc needed
     */
    function depositCollateralAndMintDsc(address collateralAddress, uint256 collateralAmount, uint256 dscToMint)
        external
    {
        depositCollateral(collateralAddress, collateralAmount);
        mintDsc(dscToMint);
    }

    /**
     * @param _tokenCollateralAddress The address of the token that is deposited as collateral
     * @param _amountCollatrtal Amount of Collateral being deposited
     * Follows CEI (Checks, Effects and Interactions
     */
    function depositCollateral(address _tokenCollateralAddress, uint256 _amountCollatrtal)
        public
        moreThanZero(_amountCollatrtal)
        isAllowedToken(_tokenCollateralAddress)
        nonReentrant
    {
        // checks
        // We dont need to do this. Already done when we call transferFrom
        // uint256 approvedCollateral = ERC20(_tokenCollateralAddress).allowance(msg.sender, address(this));

        // effects
        s_collateralDeposited[msg.sender][_tokenCollateralAddress] += _amountCollatrtal;
        emit CollateralDeposited(msg.sender, _amountCollatrtal);

        // interactions
        (bool success) = ERC20(_tokenCollateralAddress).transferFrom(msg.sender, address(this), _amountCollatrtal);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    // in order for us to redeem the collateral
    // healthFactor should be > 1 once the collateral is redeemed;
    function redeemCollateral(address collateralAddress, uint256 amountToRedeem) public moreThanZero(amountToRedeem) {
        // CEI is broken here. we do the Interactions before the checks.
        _redeemCollateral(collateralAddress, msg.sender, msg.sender, amountToRedeem);
        _revertIfHealthFactorIsBroken(msg.sender);
        // Interactions
    }

    /**
     *
     * @param collateralAddress The collateral address to redeem
     * @param amountToRedeem amount of collateral that needs to redeem
     * @param dscAmountToBurn amount of dsc to burn
     */
    function redeemCollateralForDsc(address collateralAddress, uint256 amountToRedeem, uint256 dscAmountToBurn)
        external
    {
        burnDsc(dscAmountToBurn);
        redeemCollateral(collateralAddress, amountToRedeem);
        // check health factor here ?
    }

    /**
     *
     * @param _amountToMint amount of DSC to mint
     * @notice must have more collareral than minimum threshold
     */
    function mintDsc(uint256 _amountToMint) public moreThanZero(_amountToMint) nonReentrant {
        s_DSCMinted[msg.sender] += _amountToMint;
        // if they mint too much, ($100DSC but $50USD)
        _revertIfHealthFactorIsBroken(msg.sender);

        bool minted = i_dsc.mint(msg.sender, _amountToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDsc(uint256 amount) public moreThanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
        // _revertIfHealthFactorIsBroken(msg.sender); // health factor wont get worse if debt is reduced by burning DSC. Might be able to remove.
    }

    // say we are nearing under collateralization, we need to liquidate some positions.
    // ie: someone borrowed $100 DSC for $200 ETH. (100% over-collateralized)
    // ETH tanks and their ETH collateral now worth $150. (50% over-collateralized)
    // we need to liquidate now.
    // If User-A is nearing liquidation, system will pay other users (liquidators) to liquidate User-A.abi
    // that pay is called liquidation bonus. We are only able to do it if we liquidate
    // before collateral tip from over-collateralization to under-collateralization.
    //
    //
    //
    /**
     *
     * @param collateralAddress The address of the collateral
     * @param user address of the user that debt will be covered
     * @param debtToCover amount of debt to cover in USD
     */
    function liquidate(address collateralAddress, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
    {
        // checks
        // 1. lets check the starting health factor of the user
        uint256 startingHealthFactor = _healthFactor(user);
        if (startingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOK();
        }

        // 2. get the amount of token DSC we get back for this transaction.
        // ie: how much ETH are they trying to put in to cover debt.
        uint256 tokenAmountForDebtToCover = getTokenAmountFromUSD(collateralAddress, debtToCover); // ie: this is in ETH

        // 3. calculate the bonus collateral
        uint256 bonusCollateral = (tokenAmountForDebtToCover * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION; // ie: this is in ETH
        uint256 totalCollateralRedeemed = tokenAmountForDebtToCover + bonusCollateral;
        // effects

        // Interactions
        // 4. redeem collateral
        _redeemCollateral(collateralAddress, user, msg.sender, totalCollateralRedeemed);
        // 5. burn DSC that user owns
        _burnDsc(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        if (startingHealthFactor >= endingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getTokenAmountFromUSD(address collateralAddress, uint256 amountOfUSD) public view returns (uint256) {
        address priceFeedAddress = s_priceFeeds[collateralAddress];
        AggregatorV3Interface pricefeed = AggregatorV3Interface(priceFeedAddress);

        (, int256 answer,,,) = pricefeed.staleCheckLatestRoundData();
        return (amountOfUSD * PRECISION) / (uint256(answer) * ADDITIONAL_FEED_PRECISION);
    }

    /////////////////////////////////////
    //  Private and Internal Functions //
    /////////////////////////////////////

    /**
     *
     * @param user addres of the user to check health factor
     */
    function _revertIfHealthFactorIsBroken(address user) internal view {
        // 1. do they have enough collateral ?
        // 2. revert if they dont
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    /**
     * Returns how close to liquidation a user is.
     * If user goes below 1, they can get liquidated
     * @param user addres of the user to check health factor
     */
    function _healthFactor(address user) private view returns (uint256) {
        // total DSC minted
        // total collateral VALUE (as in USD)
        (uint256 totalDscMinted, uint256 totalCollateralInUsd) = _getAccountInformation(user);

        // if you have no debt, your health factor is infinite.
        if (totalDscMinted == 0) return type(uint256).max;

        // whats the max DSC that user can borrow ?
        uint256 collateralAdjusted = (totalCollateralInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjusted * PRECISION) / totalDscMinted;

        // say out collateral is $1000 and we borrowed $200;
        // collateralAdjusted = ($1000 * 50) / 100 -> $500;
        // $500/$200 = 2.5 which is < 1; so we are good

        // why do we need collateralAdjusted * PRECISION ?
        // solidity works with whole numbers only. In any case if  collateralAdjusted/totalDscMinted is like 0.38383,
        // you would only see 0, which is not ideal.
        // to avoid this, we always use PRECISION before dividing numbers and say result is 1e18 precision.
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalMinted, uint256 totalCollateralInUsd)
    {
        totalMinted = s_DSCMinted[user];
        totalCollateralInUsd = getAccountCollateralValue(user);
        // named exports. no return required
    }

    function _redeemCollateral(address collateralAddress, address from, address to, uint256 amountToRedeem) private {
        // what if amountToRedeem is bigger than their collateral ? Relying on Solidity to throw an error here
        s_collateralDeposited[from][collateralAddress] -= amountToRedeem;
        emit CollateralRedeemed(from, to, collateralAddress, amountToRedeem);
        bool success = ERC20(collateralAddress).transfer(to, amountToRedeem);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     *
     * @param amount amount of coins to burn
     * @param behalfOf address of the person giving back the coins
     * @param dscFrom address of the person with debt
     *
     * @dev low level internal function. Do not call without checking
     * if health factor is broken.
     */
    function _burnDsc(uint256 amount, address behalfOf, address dscFrom) private moreThanZero(amount) {
        s_DSCMinted[behalfOf] -= amount;
        bool success = i_dsc.transferFrom(dscFrom, address(this), amount);
        // if transfer fails, transferFrom throwns an error.
        // this is just backup. Not nessasary.
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /////////////////////////////////
    //  Public and View Functions  //
    /////////////////////////////////
    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralInUsd) {
        // loop through each collateral token and get the value they have deposited.
        // then map it to price of USD.
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address tokenAddress = s_collateralTokens[i];
            uint256 depositedAmount = s_collateralDeposited[user][tokenAddress];
            totalCollateralInUsd += getUsdValue(tokenAddress, depositedAmount);
        }

        // dont need a return here
        return totalCollateralInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        // amount has 1e18 precision.
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData(); // price has 8 decimal points
        if (price <= 0) {
            revert DSCEngine__PriceFeedError();
        }
        // first we get the 18 precision price;
        uint256 priceAdjustedWithPrecision = (uint256(price) * ADDITIONAL_FEED_PRECISION);
        // now we gotta divide it by 1e18 so we get the correct USD amount.
        return (priceAdjustedWithPrecision * amount) / PRECISION;
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalMinted, uint256 totalCollateralInUsd)
    {
        return _getAccountInformation(user);
    }

    function getCollateralTokens() public view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getCollateralBalanceOfUser(address collateral, address user) public view returns (uint256) {
        return s_collateralDeposited[collateral][user];
    }

    function getLiquidationThreshold() public pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationPrecision() public pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getCollateralTokenPriceFeed(address collateralAddress) public view returns (address) {
        return s_priceFeeds[collateralAddress];
    }
}

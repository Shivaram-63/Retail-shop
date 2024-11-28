// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RetailShop is Ownable {
    // Stablecoin and loyalty token interfaces
    IERC20 public stablecoin;
    IERC20 public loyaltyToken;

    // Inventory and distributor details
    uint256 public inventory;
    uint256 public constant reorderThreshold = 50;
    uint256 public constant reorderQuantity = 500;

    address public distributor;
    uint256 public retailPrice;
    uint256 public wholesalePrice;

    struct ProductDelivery {
        uint256 quantity;
        uint256[] expirationDates;
    }

    mapping(address => uint256) public distributorRatings;

    // Events
    event ProductPurchased(address indexed customer, uint256 quantity, uint256 totalPrice);
    event OrderPlaced(uint256 quantity);
    event OrderReceived(uint256 quantity, uint256 payment);
    event CreditRatingUpdated(address indexed distributor, uint256 rating);
    event LoyaltyTokensAwarded(address indexed customer, uint256 quantity);

    // Constructor to initialize contract variables
    constructor(
        address _stablecoin,
        address _loyaltyToken,
        address _distributor,
        uint256 _retailPrice,
        uint256 _wholesalePrice,
        uint256 _initialInventory
    ) Ownable(msg.sender) { // Pass the deployer's address to the Ownable constructor
        stablecoin = IERC20(_stablecoin);
        loyaltyToken = IERC20(_loyaltyToken);
        distributor = _distributor;
        retailPrice = _retailPrice;
        wholesalePrice = _wholesalePrice;
        inventory = _initialInventory;
    }

    // Function for customers to purchase products
    function purchaseProduct(uint256 quantity) external {
        require(quantity > 0, "Invalid quantity");
        require(inventory >= quantity, "Not enough inventory");

        uint256 totalPrice = quantity * retailPrice;

        // Transfer stablecoin payment from customer to contract
        require(stablecoin.transferFrom(msg.sender, address(this), totalPrice), "Payment failed");

        // Deduct inventory
        inventory -= quantity;

        // Award loyalty tokens
        require(loyaltyToken.transfer(msg.sender, quantity), "Loyalty token transfer failed");

        emit ProductPurchased(msg.sender, quantity, totalPrice);
        emit LoyaltyTokensAwarded(msg.sender, quantity);

        // Check if inventory needs to be reordered
        if (inventory < reorderThreshold) {
            placeOrderToDistributor();
        }
    }

    // Internal function to place an order to the distributor
    function placeOrderToDistributor() internal {
        emit OrderPlaced(reorderQuantity);
    }

    // Function to receive order and validate product quality
    function receiveOrder(uint256 quantity, uint256[] calldata expirationDates) external onlyOwner {
        require(msg.sender == distributor, "Only distributor can deliver");
        require(quantity == reorderQuantity, "Invalid order quantity");
        require(expirationDates.length == quantity, "Mismatched quantity and expiration dates");

        // Validate expiration dates
        for (uint256 i = 0; i < expirationDates.length; i++) {
            require(expirationDates[i] >= block.timestamp && expirationDates[i] <= block.timestamp + 4 weeks, "Invalid expiration date");
        }

        // Update inventory
        inventory += quantity;

        // Calculate and make payment to the distributor
        uint256 payment = quantity * wholesalePrice;
        require(stablecoin.transfer(distributor, payment), "Payment to distributor failed");

        // Update distributor credit rating
        distributorRatings[distributor] += 1;

        emit OrderReceived(quantity, payment);
        emit CreditRatingUpdated(distributor, distributorRatings[distributor]);
    }

    // Function to set new prices
    function updatePrices(uint256 newRetailPrice, uint256 newWholesalePrice) external onlyOwner {
        retailPrice = newRetailPrice;
        wholesalePrice = newWholesalePrice;
    }

    // Function to withdraw stablecoins from the contract
    function withdrawStablecoins(uint256 amount) external onlyOwner {
        require(stablecoin.transfer(msg.sender, amount), "Withdrawal failed");
    }

    // Function to withdraw loyalty tokens from the contract
    function withdrawLoyaltyTokens(uint256 amount) external onlyOwner {
        require(loyaltyToken.transfer(msg.sender, amount), "Withdrawal failed");
    }
}

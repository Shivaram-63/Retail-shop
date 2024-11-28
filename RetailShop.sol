// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Retail Shop Contract
/// @dev This contract handles sales, inventory, and automated orders for Product A
contract RetailShop is Ownable {
    IERC20 public stablecoin; // Stablecoin used for payments (e.g., USDT)
    address public distributor; // Distributor address
    uint256 public retailPrice; // Retail price of Product A
    uint256 public wholesalePrice; // Wholesale price of Product A
    uint256 public inventory; // Inventory of Product A
    uint256 public reorderThreshold; // Inventory level to trigger reorder
    uint256 public reorderQuantity; // Quantity to reorder from the distributor

    // Loyalty Token Contract
    ERC20 public loyaltyToken;

    event ProductPurchased(address indexed customer, uint256 quantity, uint256 loyaltyTokensAwarded);
    event InventoryUpdated(uint256 newInventory);
    event OrderPlaced(uint256 quantity, address distributor);
    event OrderReceived(uint256 quantity, bool meetsCriteria);
    event PaymentMade(address distributor, uint256 amount);

    constructor(
        address _stablecoin,
        address _distributor,
        address _loyaltyToken,
        uint256 _retailPrice,
        uint256 _wholesalePrice,
        uint256 _reorderThreshold,
        uint256 _reorderQuantity
    ) Ownable(msg.sender) { // Pass msg.sender to the Ownable constructor
        stablecoin = IERC20(_stablecoin);
        distributor = _distributor;
        loyaltyToken = ERC20(_loyaltyToken);
        retailPrice = _retailPrice;
        wholesalePrice = _wholesalePrice;
        reorderThreshold = _reorderThreshold;
        reorderQuantity = _reorderQuantity;
        inventory = 0; // Initial inventory is 0
    }

    /// @dev Allows customers to purchase Product A
    /// @param quantity The number of units to purchase
    function purchaseProduct(uint256 quantity) external {
        require(quantity > 0, "Quantity must be greater than zero");
        require(inventory >= quantity, "Not enough inventory available");

        uint256 totalCost = quantity * retailPrice;
        require(stablecoin.transferFrom(msg.sender, address(this), totalCost), "Payment failed");

        inventory -= quantity;

        // Award loyalty tokens (e.g., 1 token per product purchased)
        loyaltyToken.transfer(msg.sender, quantity);

        emit ProductPurchased(msg.sender, quantity, quantity);

        // Check if inventory falls below threshold
        if (inventory < reorderThreshold) {
            placeOrderToDistributor(reorderQuantity);
        }

        emit InventoryUpdated(inventory);
    }

    /// @dev Places an order to the distributor
    /// @param quantity The quantity to order
    function placeOrderToDistributor(uint256 quantity) internal {
        require(quantity > 0, "Reorder quantity must be greater than zero");
        emit OrderPlaced(quantity, distributor);
    }

    /// @dev Confirms receipt of an order from the distributor
    /// @param quantity The quantity received
    /// @param expirationDates Array of expiration dates for the received products
    function receiveOrder(uint256 quantity, uint256[] memory expirationDates) external onlyOwner {
        require(msg.sender == distributor, "Only the distributor can deliver orders");
        require(quantity > 0, "Received quantity must be greater than zero");

        // Check that all products meet the expiration date criteria
        bool meetsCriteria = true;
        for (uint256 i = 0; i < expirationDates.length; i++) {
            if (block.timestamp + 4 weeks < expirationDates[i]) {
                meetsCriteria = false;
                break;
            }
        }

        if (meetsCriteria) {
            inventory += quantity;

            // Pay the distributor in stablecoins
            uint256 totalCost = quantity * wholesalePrice;
            require(stablecoin.transfer(distributor, totalCost), "Payment to distributor failed");

            emit PaymentMade(distributor, totalCost);
        }

        emit OrderReceived(quantity, meetsCriteria);
        emit InventoryUpdated(inventory);
    }

    /// @dev Updates the retail and wholesale prices
    /// @param newRetailPrice The new retail price
    /// @param newWholesalePrice The new wholesale price
    function updatePrices(uint256 newRetailPrice, uint256 newWholesalePrice) external onlyOwner {
        retailPrice = newRetailPrice;
        wholesalePrice = newWholesalePrice;
    }

    /// @dev Withdraws stablecoins from the contract (owner only)
    /// @param amount The amount to withdraw
    function withdrawStablecoins(uint256 amount) external onlyOwner {
        require(stablecoin.balanceOf(address(this)) >= amount, "Insufficient balance");
        stablecoin.transfer(msg.sender, amount);
    }
}

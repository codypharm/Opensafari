//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./OpenSafariERC1155.sol";
import "./Splitter.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract OpenSafariMarket is AccessControl, ReentrancyGuard {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemSold;

    //set permissions
    bytes32 public constant ADMIN = keccak256("ADMIN");
    //bytes32 public constant DEPLOYER = keccak256("DEPLOYER");

    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 amount;
        uint256 price;
        bool sold;
        bool removed;
    }

    //access market item by item id
    mapping(uint256 => MarketItem) private idMarketItem;

    //event for market item creation
    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 amount,
        uint256 price,
        bool sold,
        bool removed
    );
    //event for market item removal
    event MarketItemRemoved(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 amount,
        uint256 price,
        bool sold,
        bool removed
    );
    //event for nft gifting
    event NFTGifted(
        address indexed nftContract,
        address indexed benefactor,
        uint256 indexed tokenId,
        uint256 amount
    );
    //event for nft sale
    event NFTGifted(
        address indexed nftContract,
        address indexed seller,
        address buyer,
        uint256 indexed tokenId,
        uint256 price,
        bool royaltyPay,
        bool marketPay,
        bool sellerPay
    );

    constructor(address CEO) {
        _setRoleAdmin(ADMIN, ADMIN);
        _setupRole(ADMIN, msg.sender);
        _setupRole(ADMIN, CEO);
    }

    ///@notice function to enlist nft in the market place
    ///@param nftContract address of the nft contract
    ///@param tokenId : nft token id
    ///@param price : price per nft
    ///@param amount : amount of nft enlisted
    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 amount
    ) public {
        //increase item count
        _itemIds.increment();
        //get current count
        uint256 itemId = _itemIds.current();
        //map
        idMarketItem[itemId] = MarketItem(
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            amount,
            price,
            false,
            false
        );
        //transfer nft ownership to market
        OpenSafariERC1155(nftContract).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            amount,
            ""
        );

        //emit listing
        emit MarketItemCreated(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            address(0),
            amount,
            price,
            false,
            false
        );
    }

    ///@notice function to remove nft in the market place
    ///@param nftContract address of the nft contract
    ///@param tokenId : nft token id
    ///@param amount : amount of nft enlisted
    ///@param itemId : market id of nft to remove
    function removeMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        uint256 itemId
    ) public {
        //map
        MarketItem storage thisItem = idMarketItem[itemId];
        //change removal state to true
        thisItem.removed = true;

        require(thisItem.seller == msg.sender, "You do not have this right");

        //transfer nft ownership to initial seller
        OpenSafariERC1155(nftContract).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId,
            amount,
            ""
        );

        //emit removal
        emit MarketItemRemoved(
            itemId,
            thisItem.nftContract,
            thisItem.tokenId,
            thisItem.seller,
            thisItem.owner,
            0,
            0,
            false,
            true
        );
    }

    ///@notice function to gift nft to a benefactor
    ///@param nftContract address of the nft contract
    ///@param tokenId : nft token id
    ///@param amount : amount of nft enlisted
    ///@param benefactor : who gets the nft
    function giftNft(
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        address benefactor
    ) public {
        //transfer nft ownership to market
        OpenSafariERC1155(nftContract).safeTransferFrom(
            msg.sender,
            benefactor,
            tokenId,
            amount,
            ""
        );

        //emit listing
        emit NFTGifted(nftContract, benefactor, tokenId, amount);
    }

    ///@notice function to buy nft
    ///@param nftContract : the address of nft contract
    ///@param itemId :the item to buy
    ///@param amount : amount pf nft to buy
    ///@param splitterAddress: address of splitter contract
    function createSale(
        address nftContract,
        uint256 itemId,
        uint256 amount,
        address splitterAddress
    ) public payable nonReentrant {
        uint256 price = idMarketItem[itemId].price * amount;
        uint256 tokenId = idMarketItem[itemId].tokenId;

        //check if money is enough
        require(msg.value == price, "Please submit the asking price");

        //pay seller
        (bool sellerPay, ) = idMarketItem[itemId].seller.call{
            value: msg.value.div(100).mul(88)
        }("");
        //pay market
        (bool marketPay, ) = payable(address(this)).call{
            value: msg.value.div(100).mul(2)
        }("");
        //pay royalty
        (bool royaltyPay, ) = payable(splitterAddress).call{
            value: msg.value.div(100).mul(10)
        }("");

        //transfer nft ownership to buyer
        OpenSafariERC1155(nftContract).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId,
            amount,
            ""
        );

        MarketItem storage itemChange = idMarketItem[itemId];

        itemChange.owner = payable(msg.sender);
        itemChange.sold = true;

        //increase sold items count
        _itemSold.increment();

        //emit sale event
        emit NFTGifted(
            nftContract,
            idMarketItem[itemId].seller,
            msg.sender,
            idMarketItem[itemId].tokenId,
            idMarketItem[itemId].price,
            royaltyPay,
            marketPay,
            sellerPay
        );
    }

    ///@notice function to get list of items on sale
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 unSoldItemCount = _itemIds.current() - _itemSold.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unSoldItemCount);
        //loop all items
        for (uint256 i = 0; i < itemCount; i++) {
            //get only unsold items (no owner) and not removed
            if (
                idMarketItem[i + 1].owner == address(0) &&
                !idMarketItem[i + 1].removed
            ) {
                uint256 currentId = idMarketItem[i + 1].itemId;
                MarketItem storage currentItem = idMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
    }

    //fetch list of nfts bought by user
    function fetchMyNfts() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();

        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = idMarketItem[i + 1].itemId;
                MarketItem memory currentItem = idMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
    }

    //fetch nft created by user
    function fetchItemsListed() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();

        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (
                idMarketItem[i + 1].seller == msg.sender &&
                !idMarketItem[i + 1].removed
            ) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (
                idMarketItem[i + 1].seller == msg.sender &&
                !idMarketItem[i + 1].removed
            ) {
                uint256 currentId = idMarketItem[i + 1].itemId;
                MarketItem memory currentItem = idMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
    }
}

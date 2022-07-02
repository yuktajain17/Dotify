// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

//calling a constructor function on the inherited ERC721 smart contract
//it is kind of a special function that is executed only once immediately after it's been deployed to the blockchain
//passing the name of the NFT collection "DAppFi" and the symbol "DAPP"
contract MusicNFTMarketplace is ERC721("DAppFi", "DAPP"), Ownable {
    string public baseURI = 
        "https://bafybeidhjjbjonyqcahuzlpt7sznmh4xrlbspa3gstop5o47l6gsiaffee.ipfs.nftstorage.link/";
        //URL that points to where all the metadata for music NFTs are located on IPFS

    string public baseExtension = ".json"; //file extension of the metadata
    address public artist; //so the contract knows which account to pay the royalty fees to
    uint256 public royaltyFee; //the fees to be paid

    //defining a custom data type to represent market items
    struct MarketItem{
        uint256 tokenId;
        address payable seller; //"payable" to receive the payment(ethers)
        uint256 price;
    }
    MarketItem[] public marketItems; //an array to contain all the market items

    //logging to the blockchain
    event MarketItemBought( 
        uint256 indexed tokenId, 
        address indexed seller,
        address buyer,
        uint256 price
    );

    event MarketItemRelisted(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );

    /* In constructor we initialize royalty fee, artist address and prices of music nfts*/
    constructor(
        uint256 _royaltyFee,
        address _artist,
        uint256[] memory _prices
    ) payable { //"payable" so the deployer can send the required ether upon deployment to cover the royalty fees
        require(
            _prices.length * _royaltyFee <= msg.value, //_prices.length = no. of elements in the array = 8
            "Deployer must pay royalty fee for each token listed on the marketplace"
        );
        royaltyFee = _royaltyFee;
        artist = _artist;
        for(uint8 i=0; i<_prices.length; i++){
            require(_prices[i] > 0, "Prices must be greater than 0");
            _mint(address(this), i); //mint "this" address, "i":setting the token id as the current index
            //the freshly minted NFT is added to the market items array
            marketItems.push(MarketItem(i, payable(msg.sender), _prices[i])); //"MarketItem" struct
        }

    }

    //creating a function that allows only the owner to update the royalty fee
    function updateRoyaltyFee(uint256 _royaltyFee) external onlyOwner {
        royaltyFee = _royaltyFee;
    }

    //through which fans can purchase music NFTs
    /* creates the sale of a music nft listed on the marketplace */
    /* transfers ownership of the nft, as well as funds between parties */
    function buyToken(uint256 _tokenId) external payable {
        uint256 price = marketItems[_tokenId].price;
        address seller = marketItems[_tokenId].seller; //the seller of the market item
        require(
            msg.value == price, //ether sent with call to the buyToken function = asking price of the item
            "Please send the asking price in order to complete the purchase"
        );
        //updating the seller field on the item to the 0 as no one is selling the item anymore - it's been purchased
        marketItems[_tokenId].seller = payable(address(0)); 
        _transfer(address(this), msg.sender, _tokenId); //tranfering NFT from deployer to buyer
        payable(artist).transfer(royaltyFee); //the artist is paid the royalty fee
        payable(seller).transfer(msg.value); //paying the seller with the ether sent by the buyer
        emit MarketItemBought(_tokenId, seller, msg.sender, price);
    }

    /* Allows someone to resell their music nft */
    function resellToken(uint256 _tokenId, uint256 _price) external payable {
        require(msg.value == royaltyFee, "Must pay royalty"); //ensuring that the user submits the royalty fee
        require(_price > 0, "Price must be greater than zero"); //price the user's reselling at > 0 
        marketItems[_tokenId].price = _price;
        marketItems[_tokenId].seller = payable(msg.sender); //account calling the resellToken

        _transfer(msg.sender, address(this), _tokenId); //transfering the NFT from user to "this" contract
        emit MarketItemRelisted(_tokenId, msg.sender, _price);
    }

    /* Fetches all the tokens currently listed for sale */
    function getAllUnsoldTokens() external view returns (MarketItem[] memory) {
        uint256 unsoldCount = balanceOf(address(this)); //tokens owned by contract -> not sold
        MarketItem[] memory tokens = new MarketItem[](unsoldCount); 
        uint256 currentIndex;
        for (uint256 i = 0; i < marketItems.length; i++) {
            if (marketItems[i].seller != address(0)) { 
                tokens[currentIndex] = marketItems[i];
                currentIndex++;
            }
        }
        return (tokens);
    }

    /* Fetches all the tokens owned by the user */
    function getMyTokens() external view returns (MarketItem[] memory) {
        uint256 myTokenCount = balanceOf(msg.sender); //passing user's address
        MarketItem[] memory tokens = new MarketItem[](myTokenCount);
        uint256 currentIndex;
        for (uint256 i = 0; i < marketItems.length; i++) {
            if (ownerOf(i) == msg.sender) { //checking if owner of the token is the user
                tokens[currentIndex] = marketItems[i];
                currentIndex++;
            }
        }
        return (tokens);
    }

    /* Internal function that gets the baseURI initialized in the constructor */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI; //this returns the baseURI state variable defined on top
    }
}
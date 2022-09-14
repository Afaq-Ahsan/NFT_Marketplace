//   1 Mint ERC721 Token price of 1 NFT is 1 wei
//   2 List NFT on MarketPlace function name [createMarketItem] by paying listing fee 1 wei
//   3 Now anyone can buy NFT which is listed on marketplace by sending price [createMarketSale]
//   4 now if a owner of NFT want to make Auction of his NFT then he can also do
//        that by using function Create_Auction
//   5 now buyers come and place bid for that particular NFT.in this function there is one more
//        thing the existing higher bidder get back his ethers at the same time if a next current 
//                bidding is highest
//   6 when time of auction is completed then the owner of that particular id stop the auction by
//        using [end_Auction] function
//   7 buyer also able to resell his token easily by using reSell function
//   8 buyer who mint NFT will also given ERC20 tokens as rewardbut for this developer has to hardcode
//        ERC20 address   
//   9 Having also ERC721 royalty by using EIP2981
//   10 Owner can withdraw ethers which is currently in contract address


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
//import "@openzeppelin/contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";



//                          *****************ERC20 Interface***************** 

interface IERC20 {
      function reward(address recipient) external returns (bool);
      function balanceOf(address account) external view returns (uint256);
}

//                          *****************Marketplace Contract***************** 

contract NFTMarketplace is ERC721URIStorage,ERC2981 {
    
    using Counters for Counters.Counter; 
    using Strings for uint256;

    IERC20 token;

    Counters.Counter public _tokenIds;  //for counting token id's
    Counters.Counter public _itemsSold; //for counting items sold


//                          *****************State Variables***************** 
   
    uint256 listingPrice = 1 wei;
    uint public TokensMinted;
    address payable owner;
    string public baseURI = "https://gateway.pinata.cloud/ipfs/QmSakZfxkgigFAvXyK8Nf8zJcQhbEUrciTiwK8ACrxPtT2/";
    string public baseExtension = ".json";

    mapping(uint256 => MarketItem) private idToMarketItem;
    mapping(uint256 => bool) private sellOnce;

    struct MarketItem {
      uint256 tokenId;        //token id
      address payable seller; //seller who sell
      address payable owner;  //who owns
      uint256 price;          //parice of that nft
      bool sold;              //sold or not
      bool is_On_Auction;     //is current id is on Auction or not
      address payable highest_bidder; //highest bidder
      uint256 highestBid; //what is highest bid 
      uint256 startTime;
      uint256 endTime;
      bool Auction_ended;

    }

    event MarketItemCreated (
      uint256 indexed tokenId,
      address seller,
      address owner,
      uint256 price,
      bool sold
    );
//                          *****************Constructor*****************

    constructor() ERC721("PHOENIX Token", "PHXT") {
    owner = payable(msg.sender);
    token = IERC20(0xd9145CCE52D386f254917e481eB44e9943F39138);
    
    }

//                          *****************Mint Tokens*****************

//Price of token is 1 wei and in arguments you have to give
// royalty fee which you want for your token

  function MintToken(uint96 _royaltyFee) public payable returns (uint) {
        require(msg.value > 0, "Price must be at least 1 wei"); 
          
        _tokenIds.increment(); 
        uint256 newTokenId = _tokenIds.current(); 
         token.reward(msg.sender);
        string memory uri = ""; 
        _mint(msg.sender, newTokenId);  
        _setTokenURI(newTokenId, uri);  
        _setTokenRoyalty(newTokenId,msg.sender,_royaltyFee);

     

        TokensMinted+=1;
        return newTokenId;
    }

//                          *****************Create Market Item*****************

//Create market item means you want to list your token on marketplace 
//for this you have to send minimum of 1 wei fee as listing price and also tell how much price you want 
//of your token

 function createMarketItem(uint256 tokenId,uint256 price) public payable {
    //   require(tokenId != idToMarketItem[tokenId].tokenId,"Already added in marketplace");
      require(!idToMarketItem[tokenId].sold,"Already added in marketplace");
      require(msg.value >= listingPrice, "Price must be equal or greater than listing price");
      idToMarketItem[tokenId] =  MarketItem(
        tokenId,
        payable(msg.sender),      //seller
        payable(address(this)),   //owner
        price,                    //price of current id   
        false,                    //sold or not
        false,                    //is this item on auction or not
        payable(address(0)),      //highest bidder
        0,                        //highest bid
        0,                        //Start Time
        0,                       //End Time
        true);
      
      _transfer(msg.sender, address(this), tokenId);
      emit MarketItemCreated(
        tokenId,  
        msg.sender,
        address(this),
        price,
        false
      );
    }
//                          *****************Create Market Sale*****************    

// Creates the sale of a marketplace item 
// Transfers ownership of the item, as well as funds between parties 
// this function is basically for buying NFT which is currently listed on marketplace
// for this you have to send price of nft
    
    function createMarketSale(uint256 tokenId) public payable {
      
      require(idToMarketItem[tokenId].endTime < block.timestamp,"Auction is not ended yet");
      require(msg.value >= idToMarketItem[tokenId].highestBid,"you need to pay with the p");

      address royaltyReceiver;      //who receives royalty fee
      uint royaltyAmount;         //Royalty amount
      uint sellerAmount = msg.value;
      (royaltyReceiver,royaltyAmount) = royaltyInfo(tokenId,msg.value); //call EIP2981 standards function
                                                    //and retruns 2 values 
      uint price = idToMarketItem[tokenId].price;                       
      address seller = idToMarketItem[tokenId].seller;
      require(msg.value >= price, "Please submit the asking price in order to complete the purchase");
      idToMarketItem[tokenId].owner = payable(msg.sender);
      idToMarketItem[tokenId].sold = true;
      idToMarketItem[tokenId].seller = payable(address(0));
      _itemsSold.increment();
     
      if(sellOnce[tokenId]){     //here we create a mapping which tell us that id is sold once or not
       sellerAmount-=royaltyAmount; 
      payable(royaltyReceiver).transfer(royaltyAmount);// 1 ether transferered
     }
      _transfer(address(this), msg.sender, tokenId); //99 ethers
      payable(owner).transfer(listingPrice);
      payable(seller).transfer(sellerAmount);
      sellOnce[tokenId] = true;

    }   

//                          *****************Get Listing Price*****************

 /* Returns the listing price of the contract */

    function getListingPrice() public view returns (uint256) {
    return listingPrice;
    }
//                          *****************Create Auction*****************

function Create_Auction(uint _tokenId , uint endAt)public {
  require(idToMarketItem[_tokenId].seller == msg.sender,"You are not the Owner of this id");
  require(!idToMarketItem[_tokenId].is_On_Auction,"Already on Auction");
  
  idToMarketItem[_tokenId].is_On_Auction = true;
  idToMarketItem[_tokenId].startTime = block.timestamp;
  idToMarketItem[_tokenId].endTime = block.timestamp + endAt;
  idToMarketItem[_tokenId].Auction_ended == false;
  
}

//                          *****************Place Bid*****************

function placebid(uint256 _tokenId) public payable{

            require(msg.value > idToMarketItem[_tokenId].highestBid  );
            require(idToMarketItem[_tokenId].is_On_Auction == true,"biding not started yet");
            require(idToMarketItem[_tokenId].endTime>block.timestamp, "Auction ended");
            uint H_bid = idToMarketItem[_tokenId].highestBid;
            address payable H_bidder = idToMarketItem[_tokenId].highest_bidder;
            payable(H_bidder).transfer(H_bid);

            idToMarketItem[_tokenId].highest_bidder=payable(msg.sender);
            idToMarketItem[_tokenId].highestBid = msg.value;


    }
//                          *****************end Auction to transfer token*****************   

   function end_Auction(uint _id) public{
         require(msg.sender == idToMarketItem[_id].seller,"only seller of this token can end auction");
        require(idToMarketItem[_id].is_On_Auction,"not started yet");

        idToMarketItem[_id].Auction_ended = true;

        if(idToMarketItem[_id].highest_bidder != address(0)){
         _transfer(address(this), idToMarketItem[_id].highest_bidder, _id);
      
        idToMarketItem[_id].seller.transfer(idToMarketItem[_id].highestBid);
        idToMarketItem[_id].owner = idToMarketItem[_id].highest_bidder;
        idToMarketItem[_id].seller = payable(address(0));
        idToMarketItem[_id].is_On_Auction = false;
        idToMarketItem[_id].Auction_ended = true;
        idToMarketItem[_id].sold = true;

        }else{
            idToMarketItem[_id].is_On_Auction = false;
        idToMarketItem[_id].Auction_ended = true;
        idToMarketItem[_id].highest_bidder = payable(address(0)); //highest bidder
        idToMarketItem[_id].highestBid = 0;
        idToMarketItem[_id].sold = false;
        }

        _itemsSold.increment();

    }

//                          *****************Update Listing Price*****************   

/* Updates the listing price of the contract */

    function updateListingPrice(uint _listingPrice) public payable {
      require(owner == msg.sender, "Only marketplace owner can update listing price.");
      listingPrice = _listingPrice;
    }

//                          *****************Re-Sell Token*****************   

//    Allows someone to resell a token they have purchased 
//    any one who purchased token now want to resell it he surely have to give 1 wei which 
//    listing price basically
 
    function resellToken(uint256 tokenId, uint256 price) public payable {
      require(idToMarketItem[tokenId].owner == msg.sender, "Only item owner can perform this operation");
      require(msg.value >= listingPrice, "Price must be equal to listing price");
      idToMarketItem[tokenId].sold = false;
      idToMarketItem[tokenId].price = price;
      idToMarketItem[tokenId].seller = payable(msg.sender);
      idToMarketItem[tokenId].owner = payable(address(this));
      _itemsSold.decrement();

      _transfer(msg.sender, address(this), tokenId);
    }

//                          *****************Set Default Royalty*****************   

      function set_DefaultRoyalty(uint96 _fee)public{
      require(msg.sender == owner,"only owner can set default royalty");
      _setDefaultRoyalty(owner,_fee);
    }

//                          *****************Delete Default Royalty*****************   

    function DeleteDefaultRoyalty()public{
      require(msg.sender == owner,"only owner can Delete default royalty");
      _deleteDefaultRoyalty();
    }
//                          *****************How much reward Owner of NFT gets*****************
function getRewardInfo()public view returns(uint){
return token.balanceOf(msg.sender);
}

//                          *****************ERC721 URI***************** 

     function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }
     function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

//                          *****************Fetch Market Items*****************       

    /* Returns all unsold market items */
    function fetchMarketItems() public view returns (MarketItem[] memory) {
      uint itemCount = _tokenIds.current();
      uint unsoldItemCount = _tokenIds.current() - _itemsSold.current();
      uint currentIndex = 0;

      MarketItem[] memory items = new MarketItem[](unsoldItemCount);
      for (uint i = 0; i < itemCount; i++) {
        if (idToMarketItem[i + 1].owner == address(this)) {
          uint currentId = i + 1;
          MarketItem storage currentItem = idToMarketItem[currentId];
          items[currentIndex] = currentItem;
          currentIndex += 1;
        }
      }
      return items;
    }

//                          *****************get listing Items***************** 

/* Returns only items that a user has purchased */

    function fetchMyNFTs() public view returns (MarketItem[] memory) {
      uint totalItemCount = _tokenIds.current();
      uint itemCount = 0;
      uint currentIndex = 0;

      for (uint i = 0; i < totalItemCount; i++) {
        if (idToMarketItem[i + 1].owner == msg.sender) {
          itemCount += 1;
        }
      }

      MarketItem[] memory items = new MarketItem[](itemCount);
      for (uint i = 0; i < totalItemCount; i++) {
        if (idToMarketItem[i + 1].owner == msg.sender) {
          uint currentId = i + 1;
          MarketItem storage currentItem = idToMarketItem[currentId];
          items[currentIndex] = currentItem;
          currentIndex += 1;
        }
      }
      return items;
    }

    /* Returns only items a user has listed */
    function fetchItemsListed() public view returns (MarketItem[] memory) {
      uint totalItemCount = _tokenIds.current();
      uint itemCount = 0;
      uint currentIndex = 0;

      for (uint i = 0; i < totalItemCount; i++) {
        if (idToMarketItem[i + 1].seller == msg.sender) {
          itemCount += 1;
        }
      }

      MarketItem[] memory items = new MarketItem[](itemCount);
      for (uint i = 0; i < totalItemCount; i++) {
        if (idToMarketItem[i + 1].seller == msg.sender) {
          uint currentId = i + 1;
          MarketItem storage currentItem = idToMarketItem[currentId];
          items[currentIndex] = currentItem;
          currentIndex += 1;
        }
      }
      return items;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
    return super.supportsInterface(interfaceId);
}

    function listAllNFTs()public view returns(uint[] memory){
            uint _total= _tokenIds.current();
       
            uint i;
    uint[] memory arr = new uint[](_total);

    for(i=0; i<_total; i++){
        arr[i] = idToMarketItem[i+1].tokenId;
        } 

            return arr;
    }

//                          *****************Withdraw Balance***************** 

//Only Owner can withdraw amount of contract balance

    function withdraw() public payable  {
      require(msg.sender ==  owner,"only owner can withdraw");
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success);
    }

//                          *****************Get Owner of Particular ID***************** 

    function getOwner(uint _id)public view returns(address){
     return idToMarketItem[_id].owner;
    }

//                          *****************Get Seller Of Particular ID***************** 

    function getSeller(uint _id)public view returns(address){
      return idToMarketItem[_id].seller;
    }

//                          *****************Get Highest bidder of particular ID***************** 

    function getHigestBidder(uint HB)public view returns(address)
          {
           return idToMarketItem[HB].highest_bidder; 
          }

//                          *****************Get Highest Bid***************** 

    function getHigestBid(uint Hb)public view returns(uint)
          {
           return idToMarketItem[Hb].highestBid; 
          }

//                *****************Get Auction starting Time of particular ID***************** 

    function get_startTime(uint _id)public view returns(uint){
      return idToMarketItem[_id].startTime;
    }

//                *****************Get Auction starting Time of particular ID*****************     

    function get_endTime(uint _id)public view returns(uint){
       return idToMarketItem[_id].endTime;
    }
}

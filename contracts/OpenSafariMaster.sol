//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

//import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";
import "./OpenSafariERC1155.sol";
import "./Splitter.sol";

contract OpenSafariMaster is AccessControl {
    //set permissions
    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant DEPLOYER = keccak256("DEPLOYER");

    //event for nft deployment
    event NFTdeployed(
        OpenSafariERC1155 indexed nftAddress,
        string project,
        address indexed artist,
        Splitter indexed _splitter,
        address company
    );

    //structure nft details
    struct NFTS {
        address artist;
        string project;
        Splitter splitter;
        OpenSafariERC1155 nftAddress;
    }

    //array of nfts
    NFTS[] public NFTList;

    //mapping for nft by artist address
    mapping(address => NFTS) public NFTDir;

    constructor(address CEO) {
        _setRoleAdmin(DEPLOYER, ADMIN);

        _setupRole(ADMIN, msg.sender);
        _setupRole(ADMIN, CEO);
    }

    ///@notice function to deploy new nft contract
    ///@param imagePaths : uri of image storage
    ///@param ids: array of token ids
    ///@param amounts: amount of each token minted
    ///@param project: project name
    ///@param artist: artist address
    ///@param company: company address
    ///@param shares: array of two elements containing shares of royalty split
    ///@param marketPlace: marketplace address
    function deployNFT(
        string memory imagePaths,
        uint256[] memory ids,
        uint256[] memory amounts,
        string memory project,
        address artist,
        address company,
        uint256[] memory shares,
        address marketPlace
    ) external {
        require(
            hasRole(DEPLOYER, msg.sender) || hasRole(ADMIN, msg.sender),
            "Access denied"
        );
        //checks
        require(shares.length == 2, "Invalid shares amount");
        require(ids.length > 0, "Ids not provided");
        require(amounts.length > 0, "Token amount invalid");
        require(ids.length == amounts.length, "Ids do not match amounts");

        //create split list
        address[] memory splitList = new address[](2);
        splitList[0] = company;
        splitList[1] = artist;
        //deploy split contract
        Splitter splitterContract = new Splitter(splitList, shares);

        //deploy nft contract
        OpenSafariERC1155 nftAddress = new OpenSafariERC1155(
            imagePaths,
            ids,
            amounts,
            marketPlace,
            address(splitterContract)
        );

        //create item
        NFTS memory structure = NFTS(
            artist,
            project,
            splitterContract,
            nftAddress
        );

        //push to array
        NFTList.push(structure);

        //map
        NFTDir[artist] = structure;

        //emit event
        emit NFTdeployed(
            nftAddress,
            project,
            artist,
            splitterContract,
            company
        );
    }

    ///@notice function to move nft to users address
    ///@param to: address to new owner
    ///@param ids: array of tokens belonging to new owner
    ///@param amounts: array of amounts of different token for new owner
    ///@param nft: address of nft contract
    function moveToBacker(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        OpenSafariERC1155 nft
    ) external {
        nft.transferToBacker(to, ids, amounts);
    }

    function pause(OpenSafariERC1155 _address) external {
        require(hasRole(ADMIN, msg.sender), "Access denied");

        _address.pause();
    }

    function unpause(OpenSafariERC1155 _address) external {
        require(hasRole(ADMIN, msg.sender), "Access denied");

        _address.unpause();
    }
}

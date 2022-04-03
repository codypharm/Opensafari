//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./Lib/@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
//import "./Lib/@openzeppelin/contracts/utils/ContextMixin.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OpenSafariERC1155 is ERC1155, IERC2981, Ownable, Pausable {
    address private _recipient;

    constructor(
        string memory imagePaths,
        uint256[] memory ids,
        uint256[] memory amounts,
        address marketPlaceAddress,
        address royaltyOwner
    ) ERC1155(imagePaths) {
        _mintBatch(msg.sender, ids, amounts, "");
        setApprovalForAll(marketPlaceAddress, true);
        _recipient = royaltyOwner;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    //send nft to each backer
    function transferToBacker(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        safeBatchTransferFrom(msg.sender, to, ids, amounts, "");
    }

    /** @dev EIP2981 royalties implementation. */

    // Maintain flexibility to modify royalties recipient (could also add basis points).
    function _setRoyalties(address newRecipient) internal {
        require(
            newRecipient != address(0),
            "Royalties: new recipient is the zero address"
        );
        _recipient = newRecipient;
    }

    function setRoyalties(address newRecipient) external onlyOwner {
        _setRoyalties(newRecipient);
    }

    // EIP2981 standard royalties return.
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        return (_recipient, (_salePrice * 1000) / 10000);
    }

    // EIP2981 standard Interface return. Adds to ERC1155 and ERC165 Interface returns.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, IERC165)
        returns (bool)
    {
        return (interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId));
    }
}

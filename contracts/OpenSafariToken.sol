//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OpenSafariToken is ERC20, Ownable {
    constructor(uint256 initialSupply) ERC20("OpenSafariToken", "OPST") {
        _mint(msg.sender, initialSupply);
    }

    function mint(uint256 amount) external onlyOwner {
        _mint(msg.sender, amount);
    }
}

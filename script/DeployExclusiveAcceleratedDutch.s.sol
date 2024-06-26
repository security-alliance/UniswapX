// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {ExclusiveAcceleratedDutchOrderReactor} from "../src/reactors/ExclusiveAcceleratedDutchOrderReactor.sol";
import {OrderQuoter} from "../src/lens/OrderQuoter.sol";
import {DeployPermit2} from "../test/util/DeployPermit2.sol";

struct ExclusiveAcceleratedDutchDeployment {
    IPermit2 permit2;
    ExclusiveAcceleratedDutchOrderReactor reactor;
    OrderQuoter quoter;
}

contract DeployExclusiveAcceleratedDutch is Script, DeployPermit2 {
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant UNI_TIMELOCK = 0x1a9C8182C09F50C8318d769245beA52c32BE35BC;

    function setUp() public {}

    function run() public returns (ExclusiveAcceleratedDutchDeployment memory deployment) {
        vm.startBroadcast();
        if (PERMIT2.code.length == 0) {
            deployPermit2();
        }

        ExclusiveAcceleratedDutchOrderReactor reactor = new ExclusiveAcceleratedDutchOrderReactor{salt: bytes32(uint256(3))}(IPermit2(PERMIT2), UNI_TIMELOCK);
        console2.log("Reactor", address(reactor));

        OrderQuoter quoter = new OrderQuoter{salt: bytes32(uint256(3))}();
        console2.log("Quoter", address(quoter));

        vm.stopBroadcast();

        return ExclusiveAcceleratedDutchDeployment(IPermit2(PERMIT2), reactor, quoter);
    }
}

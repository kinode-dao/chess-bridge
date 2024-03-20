// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Bridge} from "../src/Bridge.sol";

contract BridgeTest is Test {
    event Deposit(address sender, uint256 amount);
    event BatchPosted(uint256 withdrawRootIndex, bytes32 withdrawRoot);
    event Withdraw(
        uint256 withdrawRootIndex,
        uint256 index,
        address account,
        uint256 amount
    );

    Bridge public bridge;
    address public sequencer = 0x0000000000000000000000000000000000000001;
    address public alice = 0x0000000000000000000000000000000000000002;
    address public bob = 0x0000000000000000000000000000000000000003;
    bytes32 public root =
        0x4e0eae43373552e8cbb8669b3286277ce22cc4ad14389b8b0062cf84bbd2c29b;

    function setUp() public {
        vm.prank(sequencer);
        bridge = new Bridge();

        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
        assertEq(bridge.sequencer(), sequencer);
    }

    function test_deposit() public {
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit Deposit(alice, 1 ether);
        bridge.deposit{value: 1 ether}();

        assertEq(alice.balance, 0);
        assertEq(address(bridge).balance, 1 ether);
    }

    function test_postBatch() public {
        vm.prank(sequencer);
        vm.expectEmit(true, false, false, true);
        emit BatchPosted(0, root);
        bridge.postBatch(root);

        bytes32 r = bridge.withdrawRoots(0);
        assertEq(r, root);
    }

    function test_rug() public {
        vm.prank(alice);
        bridge.deposit{value: 1 ether}();

        vm.prank(sequencer);
        bridge.rug();
        assertEq(address(bridge).balance, 0);
        assertEq(sequencer.balance, 1 ether);
    }
}

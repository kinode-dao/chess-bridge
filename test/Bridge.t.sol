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
    address public alice = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address public bob = 0x097A3a6cE1D77a11Bda1AC40C08fDF9F6202103F;
    address public charlie = 0x7F46BB25460dD7DAE4211Ca7f15ad312Fc7Dc75C;
    bytes32 public singleRoot =
        0x68de9ea8bc4f9376714cd180a888b051634a2e2d775af9e29d911fe191624eba;
    bytes32 public doubleRoot =
        0x315b17cf7841c8510d03f8a67145d5ca8be5aed451ab86498eb5b4d8a6634f35;
    bytes32 public bigRoot =
        0x08471d4bb982c73d7018c553f7ff887305843f465b9faae4cbed0802b107f4c9;

    function setUp() public {
        vm.prank(sequencer);
        bridge = new Bridge();

        vm.deal(address(bridge), 1000 ether);
        assertEq(bridge.sequencer(), sequencer);
    }

    function test_deposit() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit Deposit(alice, 1 ether);
        bridge.deposit{value: 1 ether}();

        assertEq(alice.balance, 0);
        assertEq(address(bridge).balance, 1001 ether);
    }

    function test_postBatch() public {
        vm.prank(sequencer);
        vm.expectEmit(true, false, false, true);
        emit BatchPosted(0, singleRoot);
        bridge.postBatch(singleRoot);

        bytes32 r = bridge.withdrawRoots(0);
        assertEq(r, singleRoot);
    }

    function test_rug() public {
        vm.prank(sequencer);
        bridge.rug();
        assertEq(address(bridge).balance, 0);
        assertEq(sequencer.balance, 1000 ether);
    }

    function test_withdrawSingle() public {
        vm.prank(sequencer);
        bridge.postBatch(singleRoot);

        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit Withdraw(0, 0, alice, 256);
        bytes32[] memory emptyArray;
        bridge.withdraw(0, 0, alice, 256, emptyArray);
        assertEq(alice.balance, 256);
    }

    function test_cannotWithdrawSingleTwice() public {
        vm.prank(sequencer);
        bridge.postBatch(singleRoot);

        vm.prank(alice);
        bytes32[] memory emptyArray;
        bridge.withdraw(0, 0, alice, 256, emptyArray);
        vm.expectRevert();
        bridge.withdraw(0, 0, alice, 256, emptyArray);
    }

    function test_withdrawDouble() public {
        vm.prank(sequencer);
        bridge.postBatch(doubleRoot);

        vm.prank(alice);
        bytes32[] memory aliceProof = new bytes32[](1);
        aliceProof[
            0
        ] = 0xd57ffa662a7bf8c844161b29b16a25f6d27896fc20fab98ef84849781d98be79;
        vm.expectEmit(true, false, false, true);
        emit Withdraw(0, 1, alice, 256);
        bridge.withdraw(0, 1, alice, 256, aliceProof);

        bytes32[] memory bobProof = new bytes32[](1);
        bobProof[
            0
        ] = 0xfcb893fd4d474dcd7c7997acbfd1fa45d9c3885cf2edbe132f8bae76952ff039;
        vm.prank(bob);
        vm.expectEmit(true, false, false, true);
        emit Withdraw(0, 0, bob, 256);
        bridge.withdraw(0, 0, bob, 256, bobProof);

        vm.expectRevert();
        bridge.withdraw(0, 1, alice, 256, aliceProof);

        vm.expectRevert();
        bridge.withdraw(0, 0, bob, 256, bobProof);
    }

    function test_withdrawRealistic() public {
        vm.prank(sequencer);
        bridge.postBatch(bigRoot);

        vm.prank(charlie);
        bytes32[] memory cp = new bytes32[](6);
        cp[
            0
        ] = 0x4d3ec9b60d4c112bba050468ee2821db5b435551374b08269b29da5b3556fe3b;
        cp[
            1
        ] = 0x48254d3f482a1d087bf0c80f850db4fdecec116422c824dd925bfd4a74be85d3;
        cp[
            2
        ] = 0x8ab9a204f8e6a80bd1809411f7c759db752f06eabe21df1404de914a45eb1c49;
        cp[
            3
        ] = 0xdea114dc2dede38d62a9dfedd9d1de95e18e1c0540377df8daccab23c96b8fa4;
        cp[
            4
        ] = 0xcfd6263a380c650b70d2e165fa21882c54e6a59a12838247ea950204b8c7f2e9;
        cp[
            5
        ] = 0xf4ce614005b64c0150e9718493df00c7efb553c312dec292c8cae501ef5f9cfb;

        vm.expectEmit(true, false, false, true);
        emit Withdraw(0, 14, charlie, 900000000000000000000);
        bridge.withdraw(0, 14, charlie, 900000000000000000000, cp);

        vm.expectRevert();
        bridge.withdraw(0, 14, charlie, 900000000000000000000, cp);
    }

    function test_multipleRoots() public {
        vm.prank(sequencer);
        bridge.postBatch(singleRoot);
        vm.prank(sequencer);
        bridge.postBatch(doubleRoot);
        vm.prank(sequencer);
        bridge.postBatch(bigRoot);

        // withdraw from the single root
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit Withdraw(0, 0, alice, 256);
        bytes32[] memory emptyArray;
        bridge.withdraw(0, 0, alice, 256, emptyArray);
        assertEq(alice.balance, 256);

        // withdraw from the double root
        vm.prank(alice);
        bytes32[] memory aliceProof = new bytes32[](1);
        aliceProof[
            0
        ] = 0xd57ffa662a7bf8c844161b29b16a25f6d27896fc20fab98ef84849781d98be79;
        vm.expectEmit(true, false, false, true);
        emit Withdraw(1, 1, alice, 256);
        bridge.withdraw(1, 1, alice, 256, aliceProof);

        bytes32[] memory bobProof = new bytes32[](1);
        bobProof[
            0
        ] = 0xfcb893fd4d474dcd7c7997acbfd1fa45d9c3885cf2edbe132f8bae76952ff039;
        vm.prank(bob);
        vm.expectEmit(true, false, false, true);
        emit Withdraw(1, 0, bob, 256);
        bridge.withdraw(1, 0, bob, 256, bobProof);

        // withdraw from the big root
        vm.prank(charlie);
        bytes32[] memory cp = new bytes32[](6);
        cp[
            0
        ] = 0x4d3ec9b60d4c112bba050468ee2821db5b435551374b08269b29da5b3556fe3b;
        cp[
            1
        ] = 0x48254d3f482a1d087bf0c80f850db4fdecec116422c824dd925bfd4a74be85d3;
        cp[
            2
        ] = 0x8ab9a204f8e6a80bd1809411f7c759db752f06eabe21df1404de914a45eb1c49;
        cp[
            3
        ] = 0xdea114dc2dede38d62a9dfedd9d1de95e18e1c0540377df8daccab23c96b8fa4;
        cp[
            4
        ] = 0xcfd6263a380c650b70d2e165fa21882c54e6a59a12838247ea950204b8c7f2e9;
        cp[
            5
        ] = 0xf4ce614005b64c0150e9718493df00c7efb553c312dec292c8cae501ef5f9cfb;

        vm.expectEmit(true, false, false, true);
        emit Withdraw(2, 14, charlie, 900000000000000000000);
        bridge.withdraw(2, 14, charlie, 900000000000000000000, cp);
    }
}

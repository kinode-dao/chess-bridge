// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

error AlreadyClaimed();
error InvalidProof();

contract Bridge {
    event Deposit(address sender, uint256 amount);
    event BatchPosted(uint256 withdrawRootIndex, bytes32 withdrawRoot);
    event Withdraw(
        uint256 withdrawRootIndex,
        uint256 index,
        address account,
        uint256 amount
    );

    using SafeERC20 for IERC20;

    // address public token;
    bytes32[] public withdrawRoots;
    // withdraw index => a packed array of booleans.
    mapping(uint256 => mapping(uint256 => uint256)) public claimedBitMap;
    address private _sequencer;
    // address public verifier;

    constructor() {
        _sequencer = msg.sender;
        // verifier = _verifier;
    }

    function sequencer() public view returns (address) {
        return _sequencer;
    }

    function isClaimed(
        uint256 withdrawRootIndex,
        uint256 index
    ) public view returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[withdrawRootIndex][
            claimedWordIndex
        ];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 withdrawRootIndex, uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[withdrawRootIndex][claimedWordIndex] =
            claimedBitMap[withdrawRootIndex][claimedWordIndex] |
            (1 << claimedBitIndex);
    }

    function withdraw(
        uint256 withdrawRootIndex,
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) public virtual {
        if (isClaimed(withdrawRootIndex, index)) revert AlreadyClaimed();

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        if (
            !MerkleProof.verify(
                merkleProof,
                withdrawRoots[withdrawRootIndex],
                node
            )
        ) revert InvalidProof();

        // Mark it claimed and send the token.
        _setClaimed(withdrawRootIndex, index);
        payable(account).transfer(amount);
        emit Withdraw(withdrawRootIndex, index, account, amount);
    }

    function postBatch(bytes32 _withdrawRoot) public {
        require(msg.sender == _sequencer, "Only sequencer can post batch");
        // TODO: need a signature from verifier
        withdrawRoots.push(_withdrawRoot);
        emit BatchPosted(withdrawRoots.length - 1, _withdrawRoot);
    }

    function deposit() public payable {
        require(msg.value > 0, "Value must be greater than 0");
        emit Deposit(msg.sender, msg.value);
    }

    // realistically, if we need to abandon this rollup, it's easier to just rug, and manually
    // send funds back to users.
    function rug() public {
        require(msg.sender == _sequencer, "Only sequencer can rug");
        uint256 balance = address(this).balance;
        require(balance > 0, "Contract balance is zero");
        (bool sent, ) = msg.sender.call{value: balance}("");
        require(sent, "Failed to send Ether");
    }
}

# Simple Kinode Bridge
This is a simple prototype bridge for working with kinode rollups.
Note that this is an authority rollup, nothing has been audited, and you should not deposit any more money than you are willing to lose.
There is even a `rug` function that lets the sequencer withdraw everything in the case that funds need to be manually redistributed.

## Architecture
Users can deposit ETH, and then the sequencer can update the state (by authority), allowing users to withdraw.
The withdraw system is heavily based on the [Uniswap MerkleDistributor]() contract.
Lots of simplifications were made for demo purposes including:
- state updates by authority instead of ZKPs
- arbitrary deposits are not supported, only ETH
- no censorship resistant "forced" withdrawals

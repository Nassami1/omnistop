// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @notice Test-only origin pair. Emits the Uniswap V2 Sync shape so the Reactive path can run on Base Sepolia.
/// @dev Base Sepolia has no official Uniswap V2 deployment. This is the brief's allowed Sync simulation path.
contract MockSyncPair {
    event Sync(uint112 reserve0, uint112 reserve1);

    uint112 public reserve0;
    uint112 public reserve1;

    function setReserves(uint112 reserve0_, uint112 reserve1_) external {
        reserve0 = reserve0_;
        reserve1 = reserve1_;
        emit Sync(reserve0_, reserve1_);
    }
}

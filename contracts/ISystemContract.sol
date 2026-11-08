// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @notice Minimal Reactive Network system interface used by OmniStop.
/// @dev Field order matches the live LogRecord ABI in the Reactive docs and reactive-lib.
interface ISystemContract {
    struct LogRecord {
        uint256 chainId;
        address contractAddress;
        uint256 topic0;
        uint256 topic1;
        uint256 topic2;
        uint256 topic3;
        bytes data;
        uint256 blockNumber;
        uint256 opCode;
        uint256 blockHash;
        uint256 txHash;
        uint256 logIndex;
    }

    struct CallbackConfiguration_V_1_0 {
        uint256 chainId;
        address recipient;
        uint64 gasLimit;
        bytes payload;
    }

    function subscribe(
        uint256 chainId,
        address contractAddress,
        uint256 topic0,
        uint256 topic1,
        uint256 topic2,
        uint256 topic3
    ) external;

    function requestCallbackV_1_0(CallbackConfiguration_V_1_0 memory config) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ISystemContract} from "./ISystemContract.sol";

/// @notice Watches one Uniswap V2 pool on Lasna and requests an executor callback on a threshold move.
contract OmniStopReactive {
    ISystemContract private constant SYSTEM =
        ISystemContract(0x8888888888888888888888888888888888888888);
    // Current reactive-lib wildcard. The system contract treats this magic value as "any topic".
    uint256 public constant REACTIVE_IGNORE =
        0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;
    uint256 public constant SYNC_TOPIC0 =
        0x1c411e9a96e071cae2fbf1f0e5955f0aa9583338d8bf65c42d314cbecbee956;
    uint256 private constant BPS = 10_000;
    uint64 private constant CALLBACK_GAS_LIMIT = 1_000_000;

    address public immutable pool;
    uint256 public immutable destChainId;
    uint256 public immutable thresholdBps;
    address public immutable owner;

    address public executor;
    uint256 public lastPrice;

    event Subscribed(uint256 indexed chainId, address indexed pool, uint256 indexed topic0);
    event ThresholdBreach(uint256 price, uint256 ts);
    event LatencyMeasured(bytes32 indexed originTxHash, uint256 reactTs);
    event ExecutorUpdated(address indexed executor);

    modifier onlyOwner() {
        require(msg.sender == owner, "onlyOwner");
        _;
    }

    constructor(address pool_, uint256 destChainId_, address executor_, uint256 thresholdBps_)
        payable
    {
        require(pool_ != address(0), "pool=0");
        require(destChainId_ != 0, "chain=0");
        require(thresholdBps_ > 0 && thresholdBps_ <= BPS, "bps");

        pool = pool_;
        destChainId = destChainId_;
        thresholdBps = thresholdBps_;
        executor = executor_;
        owner = msg.sender;

        // MVP keeps pool and executor on the same testnet, so the destination chain is also the origin.
        SYSTEM.subscribe(
            destChainId_,
            pool_,
            SYNC_TOPIC0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        emit Subscribed(destChainId_, pool_, SYNC_TOPIC0);
    }

    /// @notice Called by the Reactive system for each subscribed Sync log.
    function react(ISystemContract.LogRecord calldata log_) external {
        require(msg.sender == address(SYSTEM), "onlySystem");
        if (log_.topic0 != SYNC_TOPIC0 || log_.contractAddress != pool) return;

        (uint112 reserve0, uint112 reserve1) = abi.decode(log_.data, (uint112, uint112));
        require(reserve0 > 0, "no liquidity");

        uint256 price = uint256(reserve1) * 1e18 / uint256(reserve0);
        uint256 reactTs = block.timestamp;
        uint256 previous = lastPrice;

        // First Sync establishes the baseline; no callback on deployment.
        if (previous == 0) {
            lastPrice = price;
            return;
        }

        uint256 delta = price > previous ? price - previous : previous - price;
        if (delta * BPS < previous * thresholdBps) return;

        address exec = executor;
        // Leave the baseline untouched until an executor exists, so a deployment gap cannot eat the breach.
        if (exec == address(0)) return;

        // Move the baseline only on a breach, so a slow drift does not reset the stop.
        lastPrice = price;
        emit ThresholdBreach(price, reactTs);
        emit LatencyMeasured(bytes32(log_.txHash), reactTs);

        // The proxy overwrites the first address slot with this reactive contract's address.
        bytes memory payload = abi.encodeWithSignature(
            "executeSwap(address,uint256,bytes32,uint256)",
            address(0),
            price,
            bytes32(log_.txHash),
            reactTs
        );

        SYSTEM.requestCallbackV_1_0(
            ISystemContract.CallbackConfiguration_V_1_0({
                chainId: destChainId,
                recipient: exec,
                gasLimit: CALLBACK_GAS_LIMIT,
                payload: payload
            })
        );
    }

    /// @notice Attaches the executor after both contracts exist. The reactive side is deployed first.
    function setExecutor(address executor_) external onlyOwner {
        require(executor_ != address(0), "executor=0");
        executor = executor_;
        emit ExecutorUpdated(executor_);
    }

    /// @notice Reactive fees are collected by the system contract through this hook.
    function pay(uint256 amount) external {
        require(msg.sender == address(SYSTEM), "onlySystem");
        require(address(this).balance >= amount, "insufficient balance");
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "transfer failed");
    }

    receive() external payable {}
}

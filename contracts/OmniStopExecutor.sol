// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @notice Destination-side callback receiver. Emits the executed signal and reserves a router hook.
contract OmniStopExecutor {
    address public immutable callbackProxy;
    address public immutable reactiveSigner;
    address public owner;

    event SwapExecuted(
        uint256 price,
        bytes32 indexed originTxHash,
        uint256 callbackTs,
        uint256 reactiveToCallbackMs
    );

    constructor(address callbackProxy_, address reactiveSigner_) payable {
        require(callbackProxy_ != address(0), "proxy=0");
        require(reactiveSigner_ != address(0), "reactive=0");
        callbackProxy = callbackProxy_;
        reactiveSigner = reactiveSigner_;
        owner = msg.sender;
    }

    /// @notice Callback entry point. The first address is injected by the Reactive callback proxy.
    function executeSwap(
        address reactive_,
        uint256 price,
        bytes32 originTxHash,
        uint256 reactTs
    ) external {
        require(msg.sender == callbackProxy, "only-proxy");
        require(reactive_ == reactiveSigner, "only-reactive");

        uint256 callbackTs = block.timestamp;
        uint256 leg = (reactTs == 0 || callbackTs < reactTs) ? 0 : (callbackTs - reactTs) * 1000;
        emit SwapExecuted(price, originTxHash, callbackTs, leg);

        // MVP records the signal. Wire this hook to one Uniswap V2 router before enabling swaps.
        // swapViaRouter(price);
    }

    /// @notice Callback fees are collected by the proxy through this hook.
    function pay(uint256 amount) external {
        require(msg.sender == callbackProxy, "only-proxy");
        require(address(this).balance >= amount, "insufficient balance");
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "transfer failed");
    }

    /// @dev Single router wiring point. Keep executeSwap's ABI stable when adding the real swap.
    function swapViaRouter(uint256 /* amountIn */) internal virtual returns (bool) {
        return false;
    }

    receive() external payable {}
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ISystemContract} from "../contracts/ISystemContract.sol";
import {OmniStopReactive} from "../contracts/OmniStopReactive.sol";
import {OmniStopExecutor} from "../contracts/OmniStopExecutor.sol";

interface Vm {
    function prank(address sender) external;
    function warp(uint256 timestamp) external;
    function expectRevert(bytes calldata revertData) external;
    function mockCall(address callee, bytes calldata data, bytes calldata retdata) external;
    function deal(address account, uint256 balance) external;
    function expectEmit(bool topic1, bool topic2, bool topic3, bool data, address emitter) external;
}

contract OmniStopTest {
    Vm private constant VM = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address private constant SYSTEM = 0x8888888888888888888888888888888888888888;
    address private constant POOL = address(0xBEEF);
    bytes32 private constant ORIGIN_TX = keccak256("origin");

    event SwapExecuted(
        uint256 price,
        bytes32 indexed originTxHash,
        uint256 callbackTs,
        uint256 reactiveToCallbackMs
    );

    function _reactive(uint256 bps) private returns (OmniStopReactive reactive) {
        VM.mockCall(SYSTEM, abi.encodeWithSelector(ISystemContract.subscribe.selector), "");
        VM.mockCall(
            SYSTEM,
            abi.encodeWithSelector(ISystemContract.requestCallbackV_1_0.selector),
            ""
        );
        reactive = new OmniStopReactive(POOL, 84532, address(0xE0E0), bps);
    }

    function _log(uint112 reserve0, uint112 reserve1)
        private
        pure
        returns (ISystemContract.LogRecord memory record)
    {
        record.chainId = 84532;
        record.contractAddress = POOL;
        record.topic0 = 0x1c411e9a96e071241c2f21f7726b17ae89e3cab4c78be50e062b03a9fffbbad1;
        record.data = abi.encode(reserve0, reserve1);
        record.txHash = uint256(ORIGIN_TX);
    }

    function testOnlySystem() public {
        OmniStopReactive reactive = _reactive(50);
        VM.expectRevert(bytes("onlySystem"));
        reactive.react(_log(100e18, 200e18));
    }

    function testThresholdAndBaseline() public {
        OmniStopReactive reactive = _reactive(50);

        VM.warp(1000);
        VM.prank(SYSTEM);
        reactive.react(_log(100e18, 200e18));
        require(reactive.lastPrice() == 2e18, "baseline");

        // A 10 percent move breaches 50 bps.
        VM.warp(1010);
        VM.prank(SYSTEM);
        reactive.react(_log(100e18, 220e18));
        require(reactive.lastPrice() == 2.2e18, "breach baseline");

        // A 0.09 percent move from the breach baseline stays inside the 50 bps band.
        VM.warp(1020);
        VM.prank(SYSTEM);
        reactive.react(_log(100e18, 220.2e18));
        require(reactive.lastPrice() == 2.2e18, "sub-threshold ignored");
    }

    function testNoExecutorKeepsBaseline() public {
        VM.mockCall(SYSTEM, abi.encodeWithSelector(ISystemContract.subscribe.selector), "");
        VM.mockCall(
            SYSTEM,
            abi.encodeWithSelector(ISystemContract.requestCallbackV_1_0.selector),
            ""
        );
        OmniStopReactive reactive = new OmniStopReactive(POOL, 84532, address(0), 50);

        VM.warp(1000);
        VM.prank(SYSTEM);
        reactive.react(_log(100e18, 200e18));

        VM.warp(1010);
        VM.prank(SYSTEM);
        reactive.react(_log(100e18, 220e18));
        require(reactive.lastPrice() == 2e18, "breach must not be consumed without executor");
    }

    function testPayGuards() public {
        OmniStopReactive reactive = _reactive(50);
        VM.expectRevert(bytes("onlySystem"));
        reactive.pay(0);

        VM.deal(address(this), 1 ether);
        (bool funded,) = address(reactive).call{value: 1 ether}("");
        require(funded, "fund");

        VM.prank(SYSTEM);
        reactive.pay(1 ether);
        require(address(reactive).balance == 0, "paid");
    }

    function testExecutorGuards() public {
        OmniStopExecutor executor = new OmniStopExecutor(address(0xB0B), address(0xA11CE));

        VM.expectRevert(bytes("only-proxy"));
        executor.executeSwap(address(0xA11CE), 1e18, ORIGIN_TX, 1);

        VM.prank(address(0xB0B));
        VM.expectRevert(bytes("only-reactive"));
        executor.executeSwap(address(0xBAD), 1e18, ORIGIN_TX, 1);

        VM.warp(1005);
        VM.expectEmit(true, false, false, true, address(executor));
        emit SwapExecuted(1e18, ORIGIN_TX, 1005, 5000);
        VM.prank(address(0xB0B));
        executor.executeSwap(address(0xA11CE), 1e18, ORIGIN_TX, 1000);
    }
}

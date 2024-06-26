// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {OutputToken, InputToken} from "../base/ReactorStructs.sol";
import {DutchOutput, DutchInput} from "../lib/DutchOrderLib.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

/// @notice helpers for handling dutch order objects
library DutchAcceleratedDecayLib {
    using FixedPointMathLib for uint256;

    uint256 private constant DECIMALS = 1e6;

    /// @notice thrown if the decay direction is incorrect
    /// - for DutchInput, startAmount must be less than or equal to endAmount
    /// - for DutchOutput, startAmount must be greater than or equal to endAmount
    error IncorrectAmounts();

    /// @notice thrown if the endTime of an order is before startTime
    error EndTimeBeforeStartTime();

    /// @notice calculates an amount using linear decay over time from decayStartTime to decayEndTime
    /// @dev handles both positive and negative decay depending on startAmount and endAmount
    /// @param startAmount The amount of tokens at decayStartTime
    /// @param endAmount The amount of tokens at decayEndTime
    /// @param decayStartTime The time to start decaying linearly
    /// @param decayEndTime The time to stop decaying linearly
    function decay(
        uint256 startAmount,
        uint256 endAmount,
        uint256 decayStartTime,
        uint256 decayEndTime
    ) internal view returns (uint256 decayedAmount) {
        if (startAmount == endAmount) {
            return startAmount;
        } else if (decayEndTime <= decayStartTime) {
            revert EndTimeBeforeStartTime();
        } else if (decayEndTime <= block.timestamp) {
            decayedAmount = endAmount;
        } else if (decayStartTime >= block.timestamp) {
            decayedAmount = startAmount;
        } else {
            unchecked {
                uint256 elapsed = block.timestamp - decayStartTime;
                uint256 duration = decayEndTime - decayStartTime;
                uint256 acceleratedElapsed = elapsed * 2; // Accelerate the elapsed time by a factor of 4

                if (elapsed >= duration) {
                    decayedAmount = endAmount; // If accelerated elapsed time exceeds duration, set to endAmount
                } else {
                    if (endAmount < startAmount) {
                        uint256 decayAmount = (startAmount - endAmount)
                            .mulDivDown(acceleratedElapsed, duration);
                        decayedAmount = startAmount - decayAmount; // If endAmount is less than startAmount, decay the startAmount
                    } else {
                        uint256 decayAmount = (endAmount - startAmount)
                            .mulDivUp(acceleratedElapsed, duration);
                        decayedAmount = startAmount + decayAmount; // If startAmount is less than endAmount, decay the endAmount
                    }
                }
            }
        }
    }

    /// @notice returns a decayed output using the given dutch spec and times
    /// @param output The output to decay
    /// @param decayStartTime The start time of the decay
    /// @param decayEndTime The end time of the decay
    /// @return result a decayed output
    function decay(
        DutchOutput memory output,
        uint256 decayStartTime,
        uint256 decayEndTime
    ) internal view returns (OutputToken memory result) {
        if (output.startAmount < output.endAmount) {
            revert IncorrectAmounts();
        }

        uint256 decayedOutput = DutchAcceleratedDecayLib.decay(
            output.startAmount,
            output.endAmount,
            decayStartTime,
            decayEndTime
        );
        result = OutputToken(output.token, decayedOutput, output.recipient);
    }

    /// @notice returns a decayed output array using the given dutch spec and times
    /// @param outputs The output array to decay
    /// @param decayStartTime The start time of the decay
    /// @param decayEndTime The end time of the decay
    /// @return result a decayed output array
    function decay(
        DutchOutput[] memory outputs,
        uint256 decayStartTime,
        uint256 decayEndTime
    ) internal view returns (OutputToken[] memory result) {
        uint256 outputLength = outputs.length;
        result = new OutputToken[](outputLength);
        unchecked {
            for (uint256 i = 0; i < outputLength; i++) {
                result[i] = decay(outputs[i], decayStartTime, decayEndTime);
            }
        }
    }

    /// @notice returns a decayed input using the given dutch spec and times
    /// @param input The input to decay
    /// @param decayStartTime The start time of the decay
    /// @param decayEndTime The end time of the decay
    /// @return result a decayed input
    function decay(
        DutchInput memory input,
        uint256 decayStartTime,
        uint256 decayEndTime
    ) internal view returns (InputToken memory result) {
        if (input.startAmount > input.endAmount) {
            revert IncorrectAmounts();
        }

        uint256 decayedInput = DutchAcceleratedDecayLib.decay(
            input.startAmount,
            input.endAmount,
            decayStartTime,
            decayEndTime
        );
        result = InputToken(input.token, decayedInput, input.endAmount);
    }
}

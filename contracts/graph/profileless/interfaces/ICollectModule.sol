// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ICollectModule {
    function initializePublicationCollectModule(uint256 pubId, bytes calldata data) external returns (bytes memory);

    function processCollect(uint256 id, address collector, bytes calldata data) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {DataTokenHub} from "../../contracts/DataTokenHub.sol";
import {ProfilelessDataTokenFactory} from "../../contracts/core/profileless/ProfilelessDataTokenFactory.sol";
import {FeeCollectModule} from "../../contracts/core/profileless/modules/FeeCollectModule.sol";
import {DataTypes} from "../../contracts/libraries/DataTypes.sol";
import {Constants} from "../../contracts/libraries/Constants.sol";
import {Test} from "forge-std/Test.sol";

contract ProfilelessDataTokenFactoryTest is Test {
    bytes32 public constant CREATE_DATA_TOKEN_WITH_SIG_TYPEHASH = keccak256(
        bytes(
            "CreateDataTokenWithSig(string contentURI,address collectModule,bytes collectModuleInitData,uint256 nonce,uint256 deadline)"
        )
    );

    address public governor;
    address public notGovernor;
    address public dataTokenOwner;
    uint256 public dataTokenOwnerPK;
    DataTokenHub public dataTokenHub;
    ProfilelessDataTokenFactory public dataTokenFactory;

    string public contentURI;
    FeeCollectModule public collectModule;
    uint256 public collectLimit;
    uint256 public amount;
    address public currency;
    bytes public initVars;
    bytes public initVarsWithSig;

    function setUp() public {
        governor = makeAddr("governor");
        notGovernor = makeAddr("notGovernor");
        (dataTokenOwner, dataTokenOwnerPK) = makeAddrAndKey("dataTokenOwner");

        contentURI = "https://dataverse-os.com";
        collectLimit = 10000;
        amount = 10e8;
        currency = makeAddr("currency");

        vm.startPrank(governor);
        _createDataTokenHub();
        dataTokenFactory = new ProfilelessDataTokenFactory(address(dataTokenHub));
        dataTokenHub.whitelistDataTokenFactory(address(dataTokenFactory), true);

        collectModule = new FeeCollectModule(address(dataTokenHub), address(dataTokenFactory));

        vm.stopPrank();

        initVars = _getInitVars();
        initVarsWithSig = _getInitVarsWithSig();
    }

    function test_CreateDataToken() public {
        vm.prank(dataTokenOwner);
        address dataToken = dataTokenFactory.createDataToken(initVars);
        assertEq(dataTokenOwner, dataTokenFactory.getOwnerByDataToken(dataToken));
    }

    function test_CreateDataTokenWithSig() public {
        vm.prank(dataTokenOwner);
        address dataToken = dataTokenFactory.createDataTokenWithSig(initVarsWithSig);
        assertEq(dataTokenOwner, dataTokenFactory.getOwnerByDataToken(dataToken));
    }

    function testRevert_CreateDataToken_WhenInvalidInitVars() public {
        bytes memory invalidInitVars = abi.encode(address(collectModule), collectLimit, amount, currency);
        vm.prank(dataTokenOwner);
        vm.expectRevert();
        dataTokenFactory.createDataToken(invalidInitVars);
    }

    function _createDataTokenHub() internal {
        dataTokenHub = new DataTokenHub();
        dataTokenHub.initialize();
    }

    function _getInitVars() internal view returns (bytes memory) {
        DataTypes.ProfilelessPostData memory postData;
        postData.contentURI = contentURI;
        postData.collectModule = address(collectModule);
        postData.collectModuleInitData = abi.encode(collectLimit, amount, currency, dataTokenOwner);
        return abi.encode(postData);
    }

    function _getInitVarsWithSig() internal view returns (bytes memory) {
        DataTypes.ProfilelessPostData memory postData;
        DataTypes.ProfilelessPostDataSigParams memory sigParams;
        postData.contentURI = contentURI;
        postData.collectModule = address(collectModule);
        postData.collectModuleInitData = abi.encode(collectLimit, amount, currency, dataTokenOwner);

        sigParams.dataTokenCreator = dataTokenOwner;
        sigParams.sig = _buildCreateDataTokenSig(postData, dataTokenOwner, dataTokenOwnerPK);
        return abi.encode(postData, sigParams);
    }

    function _buildCreateDataTokenSig(DataTypes.ProfilelessPostData memory postData, address signer, uint256 signerPK)
        internal
        view
        returns (DataTypes.EIP712Signature memory)
    {
        uint256 nonce = dataTokenFactory.sigNonces(signer);
        bytes32 domainSeparator = dataTokenFactory.getDomainSeparator();
        uint256 deadline = block.timestamp + 1 days;
        bytes32 digest;
        {
            bytes32 hashedMessage = keccak256(
                abi.encode(
                    CREATE_DATA_TOKEN_WITH_SIG_TYPEHASH,
                    keccak256(bytes(postData.contentURI)),
                    postData.collectModule,
                    keccak256(bytes(postData.collectModuleInitData)),
                    nonce,
                    deadline
                )
            );

            digest = calculateDigest(domainSeparator, hashedMessage);
        }
        DataTypes.EIP712Signature memory signature;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPK, digest);
            signature.v = v;
            signature.r = r;
            signature.s = s;
        }
        signature.deadline = deadline;
        return signature;
    }

    function calculateDigest(bytes32 domainSeparator, bytes32 hashedMessage) internal pure returns (bytes32) {
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, hashedMessage));
        return digest;
    }
}

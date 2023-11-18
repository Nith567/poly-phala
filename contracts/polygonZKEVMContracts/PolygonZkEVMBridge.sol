// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.17;

import "./lib/DepositContract.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./lib/TokenWrapped.sol";
import "./interfaces/IBasePolygonZkEVMGlobalExitRoot.sol";
import "./interfaces/IBridgeMessageReceiver.sol";
import "./interfaces/IPolygonZkEVMBridge.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "./lib/EmergencyManager.sol";
import "./lib/GlobalExitRootLib.sol";

contract PolygonZkEVMBridge is
    DepositContract,
    EmergencyManager,
    IPolygonZkEVMBridge
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct TokenInformation {
        uint32 originNetwork;
        address originTokenAddress;
    }

    bytes4 public constant _PERMIT_SIGNATURE = 0xd505accf;


    bytes4 public constant _PERMIT_SIGNATURE_DAI = 0x8fcbaf0c;

    uint32 public constant _MAINNET_NETWORK_ID = 0;


    uint32 public constant _CURRENT_SUPPORTED_NETWORKS = 2;
    uint8 public constant _LEAF_TYPE_ASSET = 0;
    uint8 public constant _LEAF_TYPE_MESSAGE = 1;
    uint32 public networkID;


    IBasePolygonZkEVMGlobalExitRoot public globalExitRootManager;

    uint32 public lastUpdatedDepositCount;

    mapping(uint256 => uint256) public claimedBitMap;

    mapping(bytes32 => address) public tokenInfoToWrappedToken;

    mapping(address => TokenInformation) public wrappedTokenToTokenInfo;

    address public polygonZkEVMaddress;

    function initialize(
        uint32 _networkID,
        IBasePolygonZkEVMGlobalExitRoot _globalExitRootManager,
        address _polygonZkEVMaddress
    ) external virtual initializer {
        networkID = _networkID;
        globalExitRootManager = _globalExitRootManager;
        polygonZkEVMaddress = _polygonZkEVMaddress;

        // Initialize OZ contracts
        __ReentrancyGuard_init();
    }

    modifier onlyPolygonZkEVM() {
        if (polygonZkEVMaddress != msg.sender) {
            revert OnlyPolygonZkEVM();
        }
        _;
    }
    event BridgeEvent(
        uint8 leafType,
        uint32 originNetwork,
        address originAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        bytes metadata,
        uint32 depositCount
    );

    event ClaimEvent(
        uint32 index,
        uint32 originNetwork,
        address originAddress,
        address destinationAddress,
        uint256 amount
    );

    event NewWrappedToken(
        uint32 originNetwork,
        address originTokenAddress,
        address wrappedTokenAddress,
        bytes metadata
    );

    function bridgeAsset(
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        address token,
        bool forceUpdateGlobalExitRoot,
        bytes calldata permitData
    ) public payable virtual ifNotEmergencyState nonReentrant {
        if (
            destinationNetwork == networkID ||
            destinationNetwork >= _CURRENT_SUPPORTED_NETWORKS
        ) {
            revert DestinationNetworkInvalid();
        }

        address originTokenAddress;
        uint32 originNetwork;
        bytes memory metadata;
        uint256 leafAmount = amount;

        if (token == address(0)) {
            if (msg.value != amount) {
                revert AmountDoesNotMatchMsgValue();
            }
            originNetwork = _MAINNET_NETWORK_ID;
        } else {
            if (msg.value != 0) {
                revert MsgValueNotZero();
            }

            TokenInformation memory tokenInfo = wrappedTokenToTokenInfo[token];

            if (tokenInfo.originTokenAddress != address(0)) {

                TokenWrapped(token).burn(msg.sender, amount);

                originTokenAddress = tokenInfo.originTokenAddress;
                originNetwork = tokenInfo.originNetwork;
            } else {
                if (permitData.length != 0) {
                    _permit(token, amount, permitData);
                }
                uint256 balanceBefore = IERC20Upgradeable(token).balanceOf(
                    address(this)
                );
                IERC20Upgradeable(token).safeTransferFrom(
                    msg.sender,
                    address(this),
                    amount
                );
                uint256 balanceAfter = IERC20Upgradeable(token).balanceOf(
                    address(this)
                );

                leafAmount = balanceAfter - balanceBefore;

                originTokenAddress = token;
                originNetwork = networkID;
                metadata = abi.encode(
                    _safeName(token),
                    _safeSymbol(token),
                    _safeDecimals(token)
                );
            }
        }

        emit BridgeEvent(
            _LEAF_TYPE_ASSET,
            originNetwork,
            originTokenAddress,
            destinationNetwork,
            destinationAddress,
            leafAmount,
            metadata,
            uint32(depositCount)
        );

        _deposit(
            getLeafValue(
                _LEAF_TYPE_ASSET,
                originNetwork,
                originTokenAddress,
                destinationNetwork,
                destinationAddress,
                leafAmount,
                keccak256(metadata)
            )
        );
        if (forceUpdateGlobalExitRoot) {
            _updateGlobalExitRoot();
        }
    }


    function bridgeMessage(
        uint32 destinationNetwork,
        address destinationAddress,
        bool forceUpdateGlobalExitRoot,
        bytes calldata metadata
    ) external payable ifNotEmergencyState {
        if (
            destinationNetwork == networkID ||
            destinationNetwork >= _CURRENT_SUPPORTED_NETWORKS
        ) {
            revert DestinationNetworkInvalid();
        }

        emit BridgeEvent(
            _LEAF_TYPE_MESSAGE,
            networkID,
            msg.sender,
            destinationNetwork,
            destinationAddress,
            msg.value,
            metadata,
            uint32(depositCount)
        );

        _deposit(
            getLeafValue(
                _LEAF_TYPE_MESSAGE,
                networkID,
                msg.sender,
                destinationNetwork,
                destinationAddress,
                msg.value,
                keccak256(metadata)
            )
        );

        if (forceUpdateGlobalExitRoot) {
            _updateGlobalExitRoot();
        }
    }
    function claimAsset(
        bytes32[_DEPOSIT_CONTRACT_TREE_DEPTH] calldata smtProof,
        uint32 index,
        bytes32 mainnetExitRoot,
        bytes32 rollupExitRoot,
        uint32 originNetwork,
        address originTokenAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        bytes calldata metadata
    ) external ifNotEmergencyState {
        _verifyLeaf(
            smtProof,
            index,
            mainnetExitRoot,
            rollupExitRoot,
            originNetwork,
            originTokenAddress,
            destinationNetwork,
            destinationAddress,
            amount,
            metadata,
            _LEAF_TYPE_ASSET
        );

        if (originTokenAddress == address(0)) {

            (bool success, ) = destinationAddress.call{value: amount}(
                new bytes(0)
            );
            if (!success) {
                revert EtherTransferFailed();
            }
        } else {
            if (originNetwork == networkID) {
                IERC20Upgradeable(originTokenAddress).safeTransfer(
                    destinationAddress,
                    amount
                );
            } else {

                bytes32 tokenInfoHash = keccak256(
                    abi.encodePacked(originNetwork, originTokenAddress)
                );
                address wrappedToken = tokenInfoToWrappedToken[tokenInfoHash];

                if (wrappedToken == address(0)) {
                    (
                        string memory name,
                        string memory symbol,
                        uint8 decimals
                    ) = abi.decode(metadata, (string, string, uint8));

                    TokenWrapped newWrappedToken = (new TokenWrapped){
                        salt: tokenInfoHash
                    }(name, symbol, decimals);

                    newWrappedToken.mint(destinationAddress, amount);

                    tokenInfoToWrappedToken[tokenInfoHash] = address(
                        newWrappedToken
                    );

                    wrappedTokenToTokenInfo[
                        address(newWrappedToken)
                    ] = TokenInformation(originNetwork, originTokenAddress);

                    emit NewWrappedToken(
                        originNetwork,
                        originTokenAddress,
                        address(newWrappedToken),
                        metadata
                    );
                } else {
                    TokenWrapped(wrappedToken).mint(destinationAddress, amount);
                }
            }
        }

        emit ClaimEvent(
            index,
            originNetwork,
            originTokenAddress,
            destinationAddress,
            amount
        );
    }

    /**
     * @notice Verify merkle proof and execute message
     * If the receiving address is an EOA, the call will result as a success
     * Which means that the amount of ether will be transferred correctly, but the message
     * will not trigger any execution
     * @param smtProof Smt proof
     * @param index Index of the leaf
     * @param mainnetExitRoot Mainnet exit root
     * @param rollupExitRoot Rollup exit root
     * @param originNetwork Origin network
     * @param originAddress Origin address
     * @param destinationNetwork Network destination
     * @param destinationAddress Address destination
     * @param amount message value
     * @param metadata Abi encoded metadata if any, empty otherwise
     */
    function claimMessage(
        bytes32[_DEPOSIT_CONTRACT_TREE_DEPTH] calldata smtProof,
        uint32 index,
        bytes32 mainnetExitRoot,
        bytes32 rollupExitRoot,
        uint32 originNetwork,
        address originAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        bytes calldata metadata
    ) external ifNotEmergencyState {
        // Verify leaf exist and it does not have been claimed
        _verifyLeaf(
            smtProof,
            index,
            mainnetExitRoot,
            rollupExitRoot,
            originNetwork,
            originAddress,
            destinationNetwork,
            destinationAddress,
            amount,
            metadata,
            _LEAF_TYPE_MESSAGE
        );
        /* solhint-disable avoid-low-level-calls */
        (bool success, ) = destinationAddress.call{value: amount}(
            abi.encodeCall(
                IBridgeMessageReceiver.onMessageReceived,
                (originAddress, originNetwork, metadata)
            )
        );
        if (!success) {
            revert MessageFailed();
        }

        emit ClaimEvent(
            index,
            originNetwork,
            originAddress,
            destinationAddress,
            amount
        );
    }

    function precalculatedWrapperAddress(
        uint32 originNetwork,
        address originTokenAddress,
        string calldata name,
        string calldata symbol,
        uint8 decimals
    ) external view returns (address) {
        bytes32 salt = keccak256(
            abi.encodePacked(originNetwork, originTokenAddress)
        );

        bytes32 hashCreate2 = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(
                    abi.encodePacked(
                        type(TokenWrapped).creationCode,
                        abi.encode(name, symbol, decimals)
                    )
                )
            )
        );

        return address(uint160(uint256(hashCreate2)));
    }

    function getTokenWrappedAddress(
        uint32 originNetwork,
        address originTokenAddress
    ) external view returns (address) {
        return
            tokenInfoToWrappedToken[
                keccak256(abi.encodePacked(originNetwork, originTokenAddress))
            ];
    }

    function activateEmergencyState() external onlyPolygonZkEVM {
        _activateEmergencyState();
    }

    function deactivateEmergencyState() external onlyPolygonZkEVM {
        _deactivateEmergencyState();
    }
    function _verifyLeaf(
        bytes32[_DEPOSIT_CONTRACT_TREE_DEPTH] calldata smtProof,
        uint32 index,
        bytes32 mainnetExitRoot,
        bytes32 rollupExitRoot,
        uint32 originNetwork,
        address originAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        bytes calldata metadata,
        uint8 leafType
    ) internal {

        _setAndCheckClaimed(index);


        uint256 timestampGlobalExitRoot = globalExitRootManager
            .globalExitRootMap(
                GlobalExitRootLib.calculateGlobalExitRoot(
                    mainnetExitRoot,
                    rollupExitRoot
                )
            );

        if (timestampGlobalExitRoot == 0) {
            revert GlobalExitRootInvalid();
        }

        if (destinationNetwork != networkID) {
            revert DestinationNetworkInvalid();
        }

        bytes32 claimRoot;
        if (networkID == _MAINNET_NETWORK_ID) {
            claimRoot = rollupExitRoot;
        } else {
            claimRoot = mainnetExitRoot;
        }
        if (
            !verifyMerkleProof(
                getLeafValue(
                    leafType,
                    originNetwork,
                    originAddress,
                    destinationNetwork,
                    destinationAddress,
                    amount,
                    keccak256(metadata)
                ),
                smtProof,
                index,
                claimRoot
            )
        ) {
            revert InvalidSmtProof();
        }
    }

    function isClaimed(uint256 index) external view returns (bool) {
        (uint256 wordPos, uint256 bitPos) = _bitmapPositions(index);
        uint256 mask = (1 << bitPos);
        return (claimedBitMap[wordPos] & mask) == mask;
    }

    function _setAndCheckClaimed(uint256 index) public {
        (uint256 wordPos, uint256 bitPos) = _bitmapPositions(index);
        uint256 mask = 1 << bitPos;
        uint256 flipped = claimedBitMap[wordPos] ^= mask;
        if (flipped & mask == 0) {
            revert AlreadyClaimed();
        }
    }


    function updateGlobalExitRoot() external {
        if (lastUpdatedDepositCount < depositCount) {
            _updateGlobalExitRoot();
        }
    }
    function _updateGlobalExitRoot() internal {
        lastUpdatedDepositCount = uint32(depositCount);
        globalExitRootManager.updateExitRoot(getDepositRoot());
    }


    function _bitmapPositions(
        uint256 index
    ) public pure returns (uint256 wordPos, uint256 bitPos) {
        wordPos = uint248(index >> 8);
        bitPos = uint8(index);
    }

    /**
     * @notice Function to call token permit method of extended ERC20
     + @param token ERC20 token address
     * @param amount Quantity that is expected to be allowed
     * @param permitData Raw data of the call `permit` of the token
     */
    function _permit(
        address token,
        uint256 amount,
        bytes calldata permitData
    ) internal {
        bytes4 sig = bytes4(permitData[:4]);
        if (sig == _PERMIT_SIGNATURE) {
            (
                address owner,
                address spender,
                uint256 value,
                uint256 deadline,
                uint8 v,
                bytes32 r,
                bytes32 s
            ) = abi.decode(
                    permitData[4:],
                    (
                        address,
                        address,
                        uint256,
                        uint256,
                        uint8,
                        bytes32,
                        bytes32
                    )
                );
            if (owner != msg.sender) {
                revert NotValidOwner();
            }
            if (spender != address(this)) {
                revert NotValidSpender();
            }

            if (value != amount) {
                revert NotValidAmount();
            }
            /* solhint-disable avoid-low-level-calls */
            address(token).call(
                abi.encodeWithSelector(
                    _PERMIT_SIGNATURE,
                    owner,
                    spender,
                    value,
                    deadline,
                    v,
                    r,
                    s
                )
            );
        } else {
            if (sig != _PERMIT_SIGNATURE_DAI) {
                revert NotValidSignature();
            }

            (
                address holder,
                address spender,
                uint256 nonce,
                uint256 expiry,
                bool allowed,
                uint8 v,
                bytes32 r,
                bytes32 s
            ) = abi.decode(
                    permitData[4:],
                    (
                        address,
                        address,
                        uint256,
                        uint256,
                        bool,
                        uint8,
                        bytes32,
                        bytes32
                    )
                );

            if (holder != msg.sender) {
                revert NotValidOwner();
            }

            if (spender != address(this)) {
                revert NotValidSpender();
            }
            address(token).call(
                abi.encodeWithSelector(
                    _PERMIT_SIGNATURE_DAI,
                    holder,
                    spender,
                    nonce,
                    expiry,
                    allowed,
                    v,
                    r,
                    s
                )
            );
        }
    }

    function _safeSymbol(address token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(
            abi.encodeCall(IERC20MetadataUpgradeable.symbol, ())
        );
        return success ? _returnDataToString(data) : "NO_SYMBOL";
    }

    function _safeName(address token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(
            abi.encodeCall(IERC20MetadataUpgradeable.name, ())
        );
        return success ? _returnDataToString(data) : "NO_NAME";
    }

    function _safeDecimals(address token) internal view returns (uint8) {
        (bool success, bytes memory data) = address(token).staticcall(
            abi.encodeCall(IERC20MetadataUpgradeable.decimals, ())
        );
        return success && data.length == 32 ? abi.decode(data, (uint8)) : 18;
    }

    function _returnDataToString(
        bytes memory data
    ) internal pure returns (string memory) {
        if (data.length >= 64) {
            return abi.decode(data, (string));
        } else if (data.length == 32) {
            // Since the strings on bytes32 are encoded left-right, check the first zero in the data
            uint256 nonZeroBytes;
            while (nonZeroBytes < 32 && data[nonZeroBytes] != 0) {
                nonZeroBytes++;
            }

            // If the first one is 0, we do not handle the encoding
            if (nonZeroBytes == 0) {
                return "NOT_VALID_ENCODING";
            }
            // Create a byte array with nonZeroBytes length
            bytes memory bytesArray = new bytes(nonZeroBytes);
            for (uint256 i = 0; i < nonZeroBytes; i++) {
                bytesArray[i] = data[i];
            }
            return string(bytesArray);
        } else {
            return "NOT_VALID_ENCODING";
        }
    }
}

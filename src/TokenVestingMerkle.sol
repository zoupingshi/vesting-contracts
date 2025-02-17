// contracts/TokenVestingMerkle.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {TokenVesting} from "./TokenVesting.sol";
import {MerkleProofLib} from "solady/utils/MerkleProofLib.sol";

/// @title TokenVestingMerkle - This contract has all the functionality of TokenVesting,
/// but it adds the ability to create a merkle tree of vesting schedules. This makes it
/// easier to initially distribute tokens to a large number of people.
contract TokenVestingMerkle is TokenVesting {
    /// @dev The Merkle Root
    bytes32 private merkleRoot;

    /// @dev Mapping for already used merkle leaves
    mapping(bytes32 => bool) private claimed;

    /// @dev Event emitted when the merkle root is updated
    event MerkleRootUpdated(bytes32 indexed merkleRoot);

    constructor(
        IERC20Metadata token_,
        string memory _name,
        string memory _symbol,
        address _vestingCreator,
        bytes32 _root
    ) TokenVesting(token_, _name, _symbol, _vestingCreator) {
        merkleRoot = _root;
    }

    error InvalidProof();
    error AlreadyClaimed();

    /**
     * @notice Claims a vesting schedule from a merkle tree
     * @param _proof merkle proof
     * @param _start start time of the vesting period
     * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
     * @param _duration duration in seconds of the period in which the tokens will vest
     * @param _slicePeriodSeconds duration of a slice period for the vesting in seconds
     * @param _revokable whether the vesting is revokable or not
     * @param _amount total amount of tokens to be released at the end of the vesting
     */
    function claimSchedule(
        bytes32[] calldata _proof,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _slicePeriodSeconds,
        bool _revokable,
        uint256 _amount
    ) public whenNotPaused nonReentrant {
        bytes32 leaf = keccak256(
            bytes.concat(
                keccak256(abi.encode(_msgSender(), _start, _cliff, _duration, _slicePeriodSeconds, _revokable, _amount))
            )
        );

        if (!MerkleProofLib.verify(_proof, merkleRoot, leaf)) revert InvalidProof();
        if (claimed[leaf]) revert AlreadyClaimed();

        claimed[leaf] = true;
        _createVestingSchedule(_msgSender(), _start, _cliff, _duration, _slicePeriodSeconds, _revokable, _amount);
    }

    /**
     * @notice Returns whether a vesting schedule has been already claimed or not
     * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
     * @param _start start time of the vesting period
     * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
     * @param _duration duration in seconds of the period in which the tokens will vest
     * @param _slicePeriodSeconds duration of a slice period for the vesting in seconds
     * @param _revokable whether the vesting is revokable or not
     * @param _amount total amount of tokens to be released at the end of the vesting
     * @return true if the vesting schedule has been claimed, false otherwise
     */
    function scheduleClaimed(
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _slicePeriodSeconds,
        bool _revokable,
        uint256 _amount
    ) public view returns (bool) {
        bytes32 leaf = keccak256(
            bytes.concat(
                keccak256(abi.encode(_beneficiary, _start, _cliff, _duration, _slicePeriodSeconds, _revokable, _amount))
            )
        );
        return claimed[leaf];
    }

    /**
     * @notice Updates the merkle root
     * @param _root new merkle root
     */
    function updateMerkleRoot(bytes32 _root) public onlyRole(DEFAULT_ADMIN_ROLE) {
        merkleRoot = _root;
        emit MerkleRootUpdated(_root);
    }
}

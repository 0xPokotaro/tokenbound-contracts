// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";
import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC1271} from "openzeppelin-contracts/interfaces/IERC1271.sol";
import {SignatureChecker} from "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";
import {IERC6551Account} from "reference/interfaces/IERC6551Account.sol";
import {ERC6551AccountLib} from "reference/lib/ERC6551AccountLib.sol";

contract Account is IERC165, IERC1271, IERC6551Account {
    uint256 public nonce;

    receive() external payable {}

    function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory result) {
        require(msg.sender == owner(), "Not token owner");

        ++nonce;

        emit TransactionExecuted(to, value, data);

        bool success;
        (success, result) = to.call{value: value}(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function token() external view returns (uint256, address, uint256) {
        return ERC6551AccountLib.token();
    }

    function owner() public view returns (address) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = this.token();
        if (chainId != block.chainid) return address(0);

        return IERC721(tokenContract).ownerOf(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return (interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC6551Account).interfaceId);
    }

    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue) {
        bool isValid = SignatureChecker.isValidSignatureNow(owner(), hash, signature);

        if (isValid) {
            return IERC1271.isValidSignature.selector;
        }

        return "";
    }
}

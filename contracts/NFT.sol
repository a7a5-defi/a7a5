// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.22;

import {ERC721Enumerable, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFT is ERC721Enumerable {
    bool private _paused;
    address private _owner;
    string private _baseUrl;
    uint256 public lastTokenId;

    mapping(uint256 => string) public tokenCID;
    mapping(string => bool) public cidExists;

    event Paused();
    event Unpaused();

    constructor(
        string memory name_,
        string memory symbol_,
        address owner_,
        string memory baseUrl_
    ) ERC721(name_, symbol_) {
        require(owner_ != address(0), "Owner should be non zero address");
        _owner = owner_;
        _baseUrl = baseUrl_;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "only owner");
        _;
    }

    modifier whenNotPaused() {
        require(_paused != true, "paused");
        _;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function tokenURI(
        uint256 _tokenId
    ) public view override returns (string memory) {
        _requireOwned(_tokenId);
        string memory baseURI = _baseURI();
        string memory cid = tokenCID[_tokenId];
        return string.concat(baseURI, cid);
    }

    function tokenAndCIDOfOwnerByIndex(
        address tokenOwner,
        uint256 index
    ) public view virtual returns (uint256, string memory) {
        uint256 _tokenId = tokenOfOwnerByIndex(tokenOwner, index);
        string memory cid = tokenCID[_tokenId];
        return (_tokenId, cid);
    }

    function isExist(uint256 _tokenId) public view returns (bool) {
        return _ownerOf(_tokenId) != address(0);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override(ERC721, IERC721) whenNotPaused {
        ERC721.transferFrom(from, to, tokenId);
    }

    function mint(address _to, string memory _cid) public onlyOwner {
        uint256 _tokenId = lastTokenId;
        _mint(_to, _tokenId);
        _setTokenCID(_tokenId, _cid);
        lastTokenId += 1;
    }

    function burn(uint256 tokenId) public onlyOwner {
        _update(address(0), tokenId, _owner);
    }

    function burnFrom(uint256 tokenId) public onlyOwner {
        address tokenOwner = ownerOf(tokenId);
        _update(address(0), tokenId, tokenOwner);
    }

    function setBaseUrl(string memory newUrl) public onlyOwner {
        _baseUrl = newUrl;
    }

    function pause() public onlyOwner {
        _paused = true;
        emit Paused();
    }

    function unpause() public onlyOwner {
        _paused = false;
        emit Unpaused();
    }

    function _setTokenCID(uint256 _tokenId, string memory _cid) internal {
        require(cidExists[_cid] == false, "CID already exists");
        tokenCID[_tokenId] = _cid;
        cidExists[_cid] = true;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseUrl;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract PakistanLandRegistry is AccessControl {
    // Roles
    bytes32 public constant LAND_INSPECTOR_ROLE = keccak256("LAND_INSPECTOR");
    bytes32 public constant REVENUE_OFFICER_ROLE = keccak256("REVENUE_OFFICER");
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR");

    // Struct to store land details as per Pakistan land records
    struct Land {
        uint256 id;
        string khasraNumber;
        string khewatNumber;
        string mouza;
        string tehsil;
        string district;
        uint256 area; // Marla, Kanal, or Acre
        uint256 value;
        address owner;
        bool isVerified;
        bool isForSale;
        uint256 salePrice;
    }
    
    // Struct to store land transfer requests
    struct TransferRequest {
        uint256 landId;
        address from;
        address to;
        uint256 timestamp;
        bool isApproved;
    }

    // State variables
    uint256 public landCount;
    uint256 public transferRequestCount;
    
    // Mappings
    mapping(uint256 => Land) public lands;
    mapping(uint256 => TransferRequest) public transferRequests;
    mapping(address => uint256[]) public ownerLands;
    mapping(string => bool) public registeredKhasraNumbers; // To prevent duplicate registrations
    
    // Events
    event LandRegistered(uint256 indexed landId, address indexed owner);
    event LandVerified(uint256 indexed landId);
    event TransferRequestCreated(uint256 indexed requestId, uint256 indexed landId);
    event TransferRequestApproved(uint256 indexed requestId);
    event LandTransferred(uint256 indexed landId, address indexed from, address indexed to);
    event LandForSale(uint256 indexed landId, uint256 price);
    event LandSold(uint256 indexed landId, address indexed buyer, uint256 price);

    // Constructor
    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Function to register new land
    function registerLand(
        string memory _khasraNumber,
        string memory _khewatNumber,
        string memory _mouza,
        string memory _tehsil,
        string memory _district,
        uint256 _area,
        uint256 _value,
        address _owner
    ) public onlyRole(REGISTRAR_ROLE) returns (uint256) {
        require(!registeredKhasraNumbers[_khasraNumber], "Land with this Khasra Number already registered");
        
        landCount++;
        
        Land storage land = lands[landCount];
        land.id = landCount;
        land.khasraNumber = _khasraNumber;
        land.khewatNumber = _khewatNumber;
        land.mouza = _mouza;
        land.tehsil = _tehsil;
        land.district = _district;
        land.area = _area;
        land.value = _value;
        land.owner = _owner;
        land.isVerified = false;
        land.isForSale = false;
        land.salePrice = 0;
        
        registeredKhasraNumbers[_khasraNumber] = true;
        ownerLands[_owner].push(landCount);
        
        emit LandRegistered(landCount, _owner);
        return landCount;
    }

    // Function to verify land
    function verifyLand(uint256 _landId) public onlyRole(LAND_INSPECTOR_ROLE) {
        require(_landId <= landCount, "Invalid land ID");
        require(!lands[_landId].isVerified, "Land is already verified");
        
        lands[_landId].isVerified = true;
        emit LandVerified(_landId);
    }

    // Function to create transfer request
    function createTransferRequest(uint256 _landId, address _to) public {
        require(lands[_landId].owner == msg.sender, "Only land owner can initiate transfer request");
        require(lands[_landId].isVerified, "Land is not verified");
        require(_to != address(0), "Invalid recipient address");
        
        transferRequestCount++;
        
        TransferRequest storage request = transferRequests[transferRequestCount];
        request.landId = _landId;
        request.from = msg.sender;
        request.to = _to;
        request.timestamp = block.timestamp;
        request.isApproved = false;
        
        emit TransferRequestCreated(transferRequestCount, _landId);
    }

    // Function to approve transfer request
    function approveTransferRequest(uint256 _requestId) public onlyRole(REVENUE_OFFICER_ROLE) {
        require(_requestId <= transferRequestCount, "Invalid request ID");
        require(!transferRequests[_requestId].isApproved, "Request already approved");
        
        TransferRequest storage request = transferRequests[_requestId];
        Land storage land = lands[request.landId];
        
        require(land.owner == request.from, "Land owner has changed");
        
        removeFromOwnerLands(request.from, request.landId);
        ownerLands[request.to].push(request.landId);
        
        land.owner = request.to;
        land.isForSale = false;
        land.salePrice = 0;
        
        request.isApproved = true;
        
        emit TransferRequestApproved(_requestId);
        emit LandTransferred(request.landId, request.from, request.to);
    }

    // Function to remove land from owner's list
    function removeFromOwnerLands(address _owner, uint256 _landId) internal {
        uint256[] storage ownerLandsList = ownerLands[_owner];
        for (uint256 i = 0; i < ownerLandsList.length; i++) {
            if (ownerLandsList[i] == _landId) {
                ownerLandsList[i] = ownerLandsList[ownerLandsList.length - 1];
                ownerLandsList.pop();
                break;
            }
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LandRegistry {
    // Struct to store land details
    struct Land {
        uint256 id;
        string location;
        uint256 area;
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
    address public government;
    uint256 public landCount;
    uint256 public transferRequestCount;
    
    // Mappings
    mapping(uint256 => Land) public lands;
    mapping(uint256 => TransferRequest) public transferRequests;
    mapping(address => uint256[]) public ownerLands;
    
    // Events
    event LandRegistered(uint256 indexed landId, address indexed owner);
    event LandVerified(uint256 indexed landId);
    event TransferRequestCreated(uint256 indexed requestId, uint256 indexed landId);
    event TransferRequestApproved(uint256 indexed requestId);
    event LandTransferred(uint256 indexed landId, address indexed from, address indexed to);
    event LandForSale(uint256 indexed landId, uint256 price);
    event LandSold(uint256 indexed landId, address indexed buyer, uint256 price);

    // Modifiers
    modifier onlyGovernment() {
        require(msg.sender == government, "Only government can call this function");
        _;
    }

    modifier onlyLandOwner(uint256 _landId) {
        require(lands[_landId].owner == msg.sender, "Only land owner can call this function");
        _;
    }

    // Constructor
    constructor() {
        government = msg.sender;
        landCount = 0;
        transferRequestCount = 0;
    }

    // Function to register new land
    function registerLand(
        string memory _location,
        uint256 _area,
        uint256 _value,
        address _owner
    ) public onlyGovernment returns (uint256) {
        landCount++;
        
        Land storage land = lands[landCount];
        land.id = landCount;
        land.location = _location;
        land.area = _area;
        land.value = _value;
        land.owner = _owner;
        land.isVerified = false;
        land.isForSale = false;
        land.salePrice = 0;
        
        ownerLands[_owner].push(landCount);
        
        emit LandRegistered(landCount, _owner);
        return landCount;
    }

    // Function to verify land
    function verifyLand(uint256 _landId) public onlyGovernment {
        require(_landId <= landCount, "Invalid land ID");
        require(!lands[_landId].isVerified, "Land is already verified");
        
        lands[_landId].isVerified = true;
        emit LandVerified(_landId);
    }

    // Function to create transfer request
    function createTransferRequest(uint256 _landId, address _to) public onlyLandOwner(_landId) {
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
    function approveTransferRequest(uint256 _requestId) public onlyGovernment {
        require(_requestId <= transferRequestCount, "Invalid request ID");
        require(!transferRequests[_requestId].isApproved, "Request already approved");
        
        TransferRequest storage request = transferRequests[_requestId];
        Land storage land = lands[request.landId];
        
        require(land.owner == request.from, "Land owner has changed");
        
        // Remove land from current owner's list
        removeFromOwnerLands(request.from, request.landId);
        
        // Add land to new owner's list
        ownerLands[request.to].push(request.landId);
        
        // Update land ownership
        land.owner = request.to;
        land.isForSale = false;
        land.salePrice = 0;
        
        request.isApproved = true;
        
        emit TransferRequestApproved(_requestId);
        emit LandTransferred(request.landId, request.from, request.to);
    }

    // Function to put land for sale
    function putLandForSale(uint256 _landId, uint256 _price) public onlyLandOwner(_landId) {
        require(lands[_landId].isVerified, "Land is not verified");
        require(_price > 0, "Price must be greater than zero");
        
        lands[_landId].isForSale = true;
        lands[_landId].salePrice = _price;
        
        emit LandForSale(_landId, _price);
    }

    // Function to buy land
    function buyLand(uint256 _landId) public payable {
        Land storage land = lands[_landId];
        
        require(land.isVerified, "Land is not verified");
        require(land.isForSale, "Land is not for sale");
        require(msg.value >= land.salePrice, "Insufficient payment");
        require(msg.sender != land.owner, "Owner cannot buy their own land");
        
        address payable previousOwner = payable(land.owner);
        
        // Remove land from previous owner's list
        removeFromOwnerLands(previousOwner, _landId);
        
        // Add land to new owner's list
        ownerLands[msg.sender].push(_landId);
        
        // Update land ownership
        land.owner = msg.sender;
        land.isForSale = false;
        land.salePrice = 0;
        
        // Transfer payment to previous owner
        previousOwner.transfer(msg.value);
        
        emit LandSold(_landId, msg.sender, msg.value);
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

    // Function to get all lands owned by an address
    function getLandsByOwner(address _owner) public view returns (uint256[] memory) {
        return ownerLands[_owner];
    }

    // Function to get land details
    function getLandDetails(uint256 _landId) public view returns (
        string memory location,
        uint256 area,
        uint256 value,
        address owner,
        bool isVerified,
        bool isForSale,
        uint256 salePrice
    ) {
        Land storage land = lands[_landId];
        return (
            land.location,
            land.area,
            land.value,
            land.owner,
            land.isVerified,
            land.isForSale,
            land.salePrice
        );
    }
}

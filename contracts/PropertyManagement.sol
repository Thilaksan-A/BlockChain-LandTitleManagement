/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Escrow.sol";

contract PropertyManagement {
    address public authority; // government entity
    address public oracle;
    // used to make sure document has been hash checked by oracle with
    // documents submitted when using the database 
    enum Approval {
        Pending,
        Approved,
        Declined
    }

    // Property Struct
    struct Property {
        uint256 id;                 
        string location;
        uint256 value;
        string documentHash;
        string token;
        address payable owner;
        Approval status;
    }

    // used to get full property deets
    mapping(uint256 => Property) public properties;
    uint256 public nextPropertyId; // track property count

    // used to get properyid if required
    mapping(string => uint256) public propertyId;

    // used to check if property is for sale
    mapping(uint256 => bool) public propertySale;

    // used to check if property has an active escrow
    mapping(uint256 => address) public propertyEscrow;

    // used to emit when property is registered
    event PropertyRegistered(uint256 id, string location, string token, string DocumentHash);

    // used to emit when hash documents of a property has been changed
    event HashChange(uint256 propId, string location, string token, string DocumentHash);

    // used to emit when property is for sale (so rndm buyer cant keep initiating escrow)
    event PropertySale(uint256 id, string location, bool forSale);

    // used to emit when a buyer intiates an escrow
    event EscrowCreation(address escrowAddress, uint256 timeout, string token);

    // used to emit when property is transferred
    event PropertyTransferred(
        address currOwner,
        address oldOwner,
        uint256 id,
        string location
    );

    // acknowledge contract deployer as authority only
    constructor() {
        authority = msg.sender;
    }

    // modifiers for functions to make sure only eligble people can call them
    modifier onlyAuthority() {
        require(
            msg.sender == authority,
            "Insufficient rights to perform this operation"
        );
        _;
    }

    modifier onlyOwner(uint256 _propId) {
        require(
            properties[_propId].owner == msg.sender,
            "You are not the owner of the property"
        );
        _;
    }

    modifier houseRegistered(uint256 _propId) {
        require(
            properties[_propId].owner != address(0),
            "House is not registered or invalid propId"
        );
        _;
    }

    modifier onlyOracle() {
        require (oracle != address(0), "oracle address has not been set");
        require(msg.sender == oracle, "Only oracle can call");
        _;
    }

    modifier ApprovedProperty(uint256 _propertyId) {
        require(
            properties[_propertyId].status == Approval.Approved,
            "Property is not approved"
        );
        _;
    }

    // modifer that checks property is for sale
    modifier onlyOnSale(uint256 _propertyId) {
        require(propertySale[_propertyId] == true, "Property is not for sale");
        _;
    }

    // Function that allows authority to set oracle address
    function oracleAddress(address _oracle) public onlyAuthority {
        oracle = _oracle;
    }

    // Registers property including address of the owner who can receive eth
    // when selling property
    function registerProperty(
        string memory _location,
        uint256 _value,
        string memory _documentHash,
        string memory _token
    ) public {
        require(_value > 0, "cannot have 0 house value");
        properties[nextPropertyId] = Property(
            nextPropertyId,
            _location,
            _value,
            _documentHash,
            _token,
            payable(msg.sender),
            Approval.Pending
        );

        propertyId[_location] = nextPropertyId;

        emit PropertyRegistered(nextPropertyId, _location, _token, _documentHash);

        nextPropertyId++;
    }

    // Oracle approves a property if it determines hash matches with database
    function approveProperty(uint256 _propId, bool result) public onlyOracle {
        require(properties[_propId].value > 0, "Invalid Property Id");
        if (result == true) {
            properties[_propId].status = Approval.Approved;
            propertySale[_propId] = true; // auto set onSale upon registration
        } else {
            properties[_propId].status = Approval.Declined;
        }
    }

    // Returns property info after inputing propertyId
    function getPropertyInfo(
        uint256 _propertyId
    ) public houseRegistered(_propertyId) view returns (Property memory) {
        return properties[_propertyId];
    }

    // Returns propertyId if needed to access other functions
    function getPropertyId(string memory _location) public view returns (uint) {
         require(
            properties[propertyId[_location]].owner != address(0),
            "House is not registered"
        );
        return propertyId[_location];
    }

    // Returns current active escrow for propid, returns 0 if no active escrow
    function getPropertyEscrowAddress(
        uint256 _propertyId
    ) public view returns (address) {
        return propertyEscrow[_propertyId];
    }


    // Return propertyLocation - Used for testing purposes
    function getPropertyLocation(uint256 _propertyId) internal view returns (string memory)  {
        Property memory curr = properties[_propertyId];
        return curr.location;
    }

    // Return propertyValue - Used for testing purposes
    function getPropertyValue(uint256 _propertyId) internal view returns (uint)  {
        Property memory curr = properties[_propertyId];
        return curr.value;
    }

    // Return propertyDocumentHash - Used for testing purposes
    function getPropertyHash(uint256 _propertyId) internal view returns (string memory)  {
        Property memory curr = properties[_propertyId];
        return curr.documentHash;
    }

    // Return propertyToken - Used for testing purposes
    function getPropertytoken(uint256 _propertyId) internal view returns (string memory)  {
        Property memory curr = properties[_propertyId];
        return curr.token;
    }

    // Return propertyOwner address - Used for testing purposes
    function getPropertyOwnerAddress(uint256 _propertyId) internal view returns (address) {
        Property memory curr = properties[_propertyId];
        return curr.owner;
    }

    // Returns property info after inputing propertyId
    function getPropertyStatus(
        uint256 _propertyId
    ) public houseRegistered(_propertyId) view returns (string memory) {
        if (properties[_propertyId].status == Approval.Approved) {
            return "Approved";
        } else if (properties[_propertyId].status == Approval.Declined) {
            return "Rejected";
        } else {
            return "Pending";
        }
    }

    // Transfers property to new address
    function transferProperty(
        uint256 propId,
        address newOwner,
        address oldOwner
    ) public {
        require(
            propertyEscrow[propId] == msg.sender || msg.sender == authority,
            "Transfer not initiated by valid escrow or authority"
        );
        properties[propId].owner = payable(newOwner);
        propertyEscrow[propId] = address(0); // Reset escrow address for property
        string memory location = properties[propId].location;
        properties[propId].status = Approval.Pending;
        emit PropertyTransferred(newOwner, oldOwner, propId, location);
    }

    // Reset property escrow mapping when escrow timesout
    function resetPropertyEscrow(uint256 propId) public {
        require(
            propertyEscrow[propId] == msg.sender,
            "Transfer not initiated by valid escrow"
        );
        propertyEscrow[propId] = address(0); // Reset escrow address for property
    }

    // Function that changes a property availability to be on sale
    // House must be approved
    function onSale(
        uint256 _propId
    ) public houseRegistered(_propId) onlyOwner(_propId) ApprovedProperty(_propId) returns (string memory){
        propertySale[_propId] = true;
        string memory str1 = string(properties[_propId].location);
        string memory str2 = " is now on sale";
        return string(abi.encodePacked(str1, str2));
    }

    // Function that changes a property availability to be not on sale
    function noSale(
        uint256 _propId
    ) public houseRegistered(_propId) onlyOwner(_propId) ApprovedProperty(_propId) {
        propertySale[_propId] = false;
    }

    // Function that returns if a property is on sale or not
    function checkSale(uint _propId) public houseRegistered(_propId) view returns (bool) {
        require(properties[_propId].value > 0, "Invalid Property Id");
        return propertySale[_propId];
    }

    // Function that allows owner to changehouse value
    function changePrice(
        uint _propId,
        uint newPrice
    ) public houseRegistered(_propId) onlyOwner(_propId) {
        require(newPrice > 0, "cannot sell house for free");
        properties[_propId].value = newPrice;
    }

    // function that allows owner to change hash value of documents
    // when hash is changed automatically gotes to pending status
    function changeHash(
        uint _propId, string memory _token, string memory _hash
    ) public houseRegistered(_propId) onlyOwner(_propId) {
        properties[_propId].documentHash = _hash;
        properties[_propId].status = Approval.Pending;
        string memory location = properties[_propId].location;
        emit HashChange(_propId, location, _token, _hash);
    }

    // Factory pattern design to implement escrow creation 
    function createEscrow(
        address _oracle,
        address payable _seller,
        address payable _buyer,
        uint256 _value,
        uint256 _propId,
        uint256 _timeout
    ) internal {
        Escrow newEscrow = new Escrow(
            _oracle,
            _seller,
            _buyer,
            _value,
            _propId,
            _timeout
        );
        propertyEscrow[_propId] = address(newEscrow);
        emit EscrowCreation(address(newEscrow), _timeout, properties[_propId].token);
    }

    // Function that generates escrow contract address between buyer and seller 
    function buyProperty(uint _propId) public payable {
        require(properties[_propId].value > 0, "Invalid Property Id");
        // property must be for sale to buy
        require(propertySale[_propId] == true, "Propery not for sale");
        require(properties[_propId].value > 0, "Invalid Property Id");
        require(
            properties[_propId].owner != msg.sender,
            "You already own this property"
        );
        require(
            msg.sender.balance > properties[_propId].value,
            "insuffienct funds to buy property"
        );
        

        createEscrow(
            oracle,
            properties[_propId].owner,
            payable(msg.sender),
            properties[_propId].value,
            _propId,
            block.timestamp + 2628000 // roughly 1 month
            // best practice is to get the oracle to provide the current time (if we have time)
        );

        propertySale[_propId] == false; // so we dont end up with multiple intiating escrow on same property all at once.
        // owner reset onSale status manually
    }
}

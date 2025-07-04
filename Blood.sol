// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BloodDonationSystem {

    enum BloodStatus { Stored, Dispatched }
    enum Role { None, Donor, Hospital }

    mapping(address => Role) public roles;
    address public owner;

    modifier onlyRole(Role _role) {
        require(roles[msg.sender] == _role, "Access denied: wrong role");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        roles[msg.sender] = Role.Hospital;
    }

    function setRole(address user, Role _role) public onlyOwner {
        roles[user] = _role;
    }

    struct Donation {
        string bloodType;
        uint volume;
        uint timestamp;
        string location;
    }

    struct BloodUnit {
        string cccd;
        string bloodType;
        uint volume;
        BloodStatus status;
        string hospital;
        uint donatedAt;
        uint dispatchedAt;
    }

    struct BloodRequest {
        string hospitalName;
        string bloodType;
        uint requiredVolume;
        bool fulfilled;
    }

    mapping(string => Donation[]) private donationHistory;
    BloodUnit[] public bloodUnits;
    BloodRequest[] public bloodRequests;

    mapping(string => uint) public bloodInventory;
    string[] private bloodTypesList;
    mapping(string => bool) private bloodTypeExists;

    event BloodDonated(string cccd, string bloodType, uint volume, string location, uint timestamp);
    event BloodRequested(string hospital, string bloodType, uint volume, bool fulfilled);
    event BloodDispatched(string cccd, string hospital, uint volume);

    function donateBlood(
        string memory _cccd,
        string memory _bloodType,
        uint _volume,
        string memory _location
    ) public onlyRole(Role.Donor) {
        require(_volume > 0, "Invalid blood volume");

        uint timestamp = block.timestamp;

        donationHistory[_cccd].push(Donation({
            bloodType: _bloodType,
            volume: _volume,
            timestamp: timestamp,
            location: _location
        }));

        bloodUnits.push(BloodUnit({
            cccd: _cccd,
            bloodType: _bloodType,
            volume: _volume,
            status: BloodStatus.Stored,
            hospital: "",
            donatedAt: timestamp,
            dispatchedAt: 0
        }));

        bloodInventory[_bloodType] += _volume;

        if (!bloodTypeExists[_bloodType]) {
            bloodTypeExists[_bloodType] = true;
            bloodTypesList.push(_bloodType);
        }

        emit BloodDonated(_cccd, _bloodType, _volume, _location, timestamp);
    }

    function requestBlood(
        string memory _hospital,
        string memory _bloodType,
        uint _volume
    ) public onlyRole(Role.Hospital) {
        require(_volume > 0, "Invalid volume");

        uint remaining = _volume;
        uint availableInStock = bloodInventory[_bloodType];

        require(availableInStock >= remaining, "Not enough blood available in stock");

        for (uint i = 0; i < bloodUnits.length && remaining > 0; i++) {
            BloodUnit storage unit = bloodUnits[i];

            if (
                unit.status == BloodStatus.Stored &&
                keccak256(bytes(unit.bloodType)) == keccak256(bytes(_bloodType))
            ) {
                if (unit.volume <= remaining) {
                    remaining -= unit.volume;
                    bloodInventory[_bloodType] -= unit.volume;
                    unit.status = BloodStatus.Dispatched;
                    unit.hospital = _hospital;
                    unit.dispatchedAt = block.timestamp;
                    emit BloodDispatched(unit.cccd, _hospital, unit.volume);
                } else {
                    unit.volume -= remaining;
                    bloodInventory[_bloodType] -= remaining;
                    bloodUnits.push(BloodUnit({
                        cccd: unit.cccd,
                        bloodType: unit.bloodType,
                        volume: remaining,
                        status: BloodStatus.Dispatched,
                        hospital: _hospital,
                        donatedAt: unit.donatedAt,
                        dispatchedAt: block.timestamp
                    }));
                    emit BloodDispatched(unit.cccd, _hospital, remaining);
                    remaining = 0;
                }
            }
        }

        bool fulfilled = (remaining == 0);

        bloodRequests.push(BloodRequest({
            hospitalName: _hospital,
            bloodType: _bloodType,
            requiredVolume: _volume,
            fulfilled: fulfilled
        }));

        emit BloodRequested(_hospital, _bloodType, _volume, fulfilled);
    }

    function getDonationDetails(string memory _cccd) public view returns (
        uint[] memory volumes,
        uint[] memory timestamps,
        string[] memory locations
    ) {
        uint count = donationHistory[_cccd].length;
        volumes = new uint[](count);
        timestamps = new uint[](count);
        locations = new string[](count);

        for (uint i = 0; i < count; i++) {
            Donation memory d = donationHistory[_cccd][i];
            volumes[i] = d.volume;
            timestamps[i] = d.timestamp;
            locations[i] = d.location;
        }
    }

    function getBloodUnits(string memory _cccd) public view returns (BloodUnit[] memory) {
        uint count;
        for (uint i = 0; i < bloodUnits.length; i++) {
            if (keccak256(bytes(bloodUnits[i].cccd)) == keccak256(bytes(_cccd))) {
                count++;
            }
        }

        BloodUnit[] memory results = new BloodUnit[](count);
        uint index;
        for (uint i = 0; i < bloodUnits.length; i++) {
            if (keccak256(bytes(bloodUnits[i].cccd)) == keccak256(bytes(_cccd))) {
                results[index++] = bloodUnits[i];
            }
        }
        return results;
    }

    function getAllBloodInventories() public view returns (
        string[] memory types,
        uint[] memory volumes
    ) {
        uint count = bloodTypesList.length;
        types = new string[](count);
        volumes = new uint[](count);

        for (uint i = 0; i < count; i++) {
            string memory bt = bloodTypesList[i];
            types[i] = bt;
            volumes[i] = bloodInventory[bt];
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract BloodBank {
    address public owner;

    constructor() {
        owner = msg.sender;
        roles[msg.sender] = Role.Admin;
        _initializeValidBloodGroups();
    }

    // ==== Role System ====
    enum Role { None, Donor, Hospital, Admin }
    mapping(address => Role) public roles;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only admin can perform this action");
        _;
    }

    modifier onlyRole(Role _role) {
        require(roles[msg.sender] == _role, "Access denied: wrong role");
        _;
    }

    function assignRole(address _user, Role _role) external onlyOwner {
        roles[_user] = _role;
    }

    // ==== Enums ====
    enum DonationKind { Voluntary, Paid }
    enum BloodStatus { Valid, Used, Spoiled, Expired }

    // ==== Structs ====
    struct BloodTransaction {
        uint256 time;
        DonationKind kind;
        uint256 volume;
        address executor;
    }

    struct Patient {
        string cccd;
        string name;
        uint256 age;
        uint256 weight;
        string bloodGroup;
        string pendingBloodGroup;
        bool isBloodGroupVerified;
        string contact;
        string homeAddress;
        bool isActive;
        address wallet;
        BloodTransaction[] transactions;
        uint256 totalVoluntaryDonation;
    }

    struct BloodUnit {
        string bloodGroup;
        string donorId;
        uint256 volume;
        uint256 collectedAt;
        uint256 expiryTime;
        uint256 storageTemp;
        BloodStatus status;
        string metadataHash;
        string hospitalName;
    }

    struct TransfusionRecord {
        bytes32 unitId;
        string recipientcccd;
        string recipientName;
        uint256 recipientAge;
        string recipientBloodGroup;
        string hospitalName;
        uint256 transfusedAt;
        address hospitalWallet;
    }

    mapping(string => Patient) private patients;
    mapping(string => bool) private cccdExists;
    mapping(string => bool) private validBloodGroups;
    mapping(bytes32 => BloodUnit) public bloodUnits;
    bytes32[] public bloodUnitIds;
    TransfusionRecord[] public transfusionHistory;

    // ==== Events ====
    event PatientAdded(address indexed donor, string cccd);
    event BloodDonated(address indexed donor, string cccd, uint256 volume);
    event BloodDistributed(bytes32 unitId, address hospital, string hospitalName);
    event BloodTransfused(bytes32 unitId, address hospital, string patientName);
    event BloodGroupVerified(string cccd, string bloodGroup);

    // ==== Initialization ====
    function _initializeValidBloodGroups() internal {
        validBloodGroups["A+"] = true;
        validBloodGroups["A-"] = true;
        validBloodGroups["B+"] = true;
        validBloodGroups["B-"] = true;
        validBloodGroups["AB+"] = true;
        validBloodGroups["AB-"] = true;
        validBloodGroups["O+"] = true;
        validBloodGroups["O-"] = true;
    }

    // ==== Patient Management ====
    function newPatient(
        string memory _cccd,
        string memory _name,
        uint256 _age,
        uint256 _weight,
        string memory _contact,
        string memory _homeAddress,
        string memory _bloodGroup
    ) external onlyRole(Role.Donor) {
        require(!cccdExists[_cccd], "Patient already registered");
        require(_age >= 18 && _age <= 60, "Age must be between 18 and 60");
        require(_weight >= 45, "Weight must be >= 45kg");

        string memory normalized = _normalizeBloodGroup(_bloodGroup);
        require(validBloodGroups[normalized], "Invalid blood group");

        Patient storage p = patients[_cccd];
        p.name = _name;
        p.age = _age;
        p.weight = _weight;
        p.contact = _contact;
        p.homeAddress = _homeAddress;
        p.cccd = _cccd;
        p.isActive = true;
        p.wallet = msg.sender;
        p.pendingBloodGroup = normalized;
        p.isBloodGroupVerified = false;

        cccdExists[_cccd] = true;
        emit PatientAdded(msg.sender, _cccd);
    }

    function verifyBloodGroup(string memory _cccd) external onlyOwner {
        require(cccdExists[_cccd], "Patient not found");
        Patient storage p = patients[_cccd];
        require(!p.isBloodGroupVerified, "Already verified");
        require(bytes(p.pendingBloodGroup).length > 0, "No pending blood group");

        p.bloodGroup = p.pendingBloodGroup;
        p.pendingBloodGroup = "";
        p.isBloodGroupVerified = true;

        emit BloodGroupVerified(_cccd, p.bloodGroup);
    }

    // ==== Blood Donation and Management ====
    function donateBlood(
        string memory _cccd,
        DonationKind _kind,
        uint256 _volume,
        uint256 _storageTemp,
        uint256 _expiryDays,
        string memory _metadataHash,
        string memory _hospitalName
    ) external onlyRole(Role.Donor) {
        require(cccdExists[_cccd], "Patient not found");
        Patient storage p = patients[_cccd];
        require(p.wallet == msg.sender, "Can only donate for own CCCD");
        require(p.isActive, "Inactive patient");
        require(p.isBloodGroupVerified, "Blood group not verified");

        string memory group = p.bloodGroup;
        require(validBloodGroups[group], "Blood group invalid");

        uint256 maxVolume = p.weight * 9;
        require(_volume > 0 && _volume <= maxVolume, "Invalid volume");
        require(_expiryDays <= 45, "Too long expiry");
        require(_storageTemp >= 4 && _storageTemp <= 8, "Invalid temp");

        bytes32 unitId = keccak256(abi.encodePacked(_cccd, block.timestamp, _volume));
        uint256 expiry = block.timestamp + (_expiryDays * 1 days);

        bloodUnits[unitId] = BloodUnit({
            bloodGroup: group,
            donorId: _cccd,
            volume: _volume,
            collectedAt: block.timestamp,
            expiryTime: expiry,
            storageTemp: _storageTemp,
            status: BloodStatus.Valid,
            metadataHash: _metadataHash,
            hospitalName: _hospitalName
        });

        bloodUnitIds.push(unitId);

        p.transactions.push(BloodTransaction({
            time: block.timestamp,
            kind: _kind,
            volume: _volume,
            executor: msg.sender
        }));

        if (_kind == DonationKind.Voluntary) {
            p.totalVoluntaryDonation += _volume;
        }

        emit BloodDonated(msg.sender, _cccd, _volume);
    }

    function distributeBlood(bytes32 unitId, string memory _hospitalName) external onlyRole(Role.Hospital) {
        require(bloodUnits[unitId].status == BloodStatus.Valid, "Blood not valid");
        bloodUnits[unitId].status = BloodStatus.Used;
        bloodUnits[unitId].hospitalName = _hospitalName;
        emit BloodDistributed(unitId, msg.sender, _hospitalName);
    }

    function recordTransfusion(
        bytes32 unitId,
        string memory recipientCccd,
        string memory recipientName,
        uint256 recipientAge,
        string memory recipientBloodGroup
    ) external onlyRole(Role.Hospital) {
        BloodUnit storage unit = bloodUnits[unitId];
        require(unit.status == BloodStatus.Used, "Must be marked Used first");

        transfusionHistory.push(TransfusionRecord({
            unitId: unitId,
            recipientcccd: recipientCccd,
            recipientName: recipientName,
            recipientAge: recipientAge,
            recipientBloodGroup: _normalizeBloodGroup(recipientBloodGroup),
            hospitalName: unit.hospitalName,
            transfusedAt: block.timestamp,
            hospitalWallet: msg.sender
        }));

        emit BloodTransfused(unitId, msg.sender, recipientName);
    }

    // ==== View Functions ====
    function getPatientPublicInfo(string memory _cccd) external view returns (
        string memory name,
        uint256 age,
        string memory bloodGroup,
        string memory contact,
        string memory homeAddress,
        uint256 totalDonation,
        uint256 voluntaryDonation
    ) {
        require(cccdExists[_cccd], "Patient not found");
        Patient storage p = patients[_cccd];

        uint256 total;
        uint256 voluntary;

        for (uint256 i = 0; i < p.transactions.length; i++) {
            total += p.transactions[i].volume;
            if (p.transactions[i].kind == DonationKind.Voluntary) {
                voluntary += p.transactions[i].volume;
            }
        }

        return (
            p.name,
            p.age,
            p.bloodGroup,
            p.contact,
            p.homeAddress,
            total,
            voluntary
        );
    }

    function getBloodUnit(bytes32 unitId) external view returns (BloodUnit memory) {
        return bloodUnits[unitId];
    }

    function getAllBloodUnitIds() external view returns (bytes32[] memory) {
        return bloodUnitIds;
    }

    function getAllTransfusions() external view returns (TransfusionRecord[] memory) {
        return transfusionHistory;
    }

    function getBloodUnitsNearExpiry(uint256 withinDays) external view returns (bytes32[] memory) {
        uint256 threshold = block.timestamp + withinDays * 1 days;
        uint256 count;

        for (uint256 i = 0; i < bloodUnitIds.length; i++) {
            if (bloodUnits[bloodUnitIds[i]].expiryTime <= threshold &&
                bloodUnits[bloodUnitIds[i]].status == BloodStatus.Valid) {
                count++;
            }
        }

        bytes32[] memory result = new bytes32[](count);
        uint256 index;
        for (uint256 i = 0; i < bloodUnitIds.length; i++) {
            if (bloodUnits[bloodUnitIds[i]].expiryTime <= threshold &&
                bloodUnits[bloodUnitIds[i]].status == BloodStatus.Valid) {
                result[index++] = bloodUnitIds[i];
            }
        }
        return result;
    }

    function getInventoryByGroup(string memory bloodGroup) external view returns (uint256 totalVolume) {
        string memory group = _normalizeBloodGroup(bloodGroup);
        require(validBloodGroups[group], "Invalid blood group");

        for (uint256 i = 0; i < bloodUnitIds.length; i++) {
            BloodUnit storage unit = bloodUnits[bloodUnitIds[i]];
            if (keccak256(bytes(unit.bloodGroup)) == keccak256(bytes(group)) &&
                unit.status == BloodStatus.Valid) {
                totalVolume += unit.volume;
            }
        }
    }

    // ==== Internal Utilities ====
    function _normalizeBloodGroup(string memory input) internal pure returns (string memory) {
        bytes memory str = bytes(input);
        bytes memory result = new bytes(str.length);
        uint256 j = 0;

        for (uint256 i = 0; i < str.length; i++) {
            if (str[i] != 0x20) {
                if (str[i] >= 0x61 && str[i] <= 0x7A) {
                    result[j++] = bytes1(uint8(str[i]) - 32);
                } else {
                    result[j++] = str[i];
                }
            }
        }

        bytes memory trimmed = new bytes(j);
        for (uint256 k = 0; k < j; k++) {
            trimmed[k] = result[k];
        }

        return string(trimmed);
    }
}

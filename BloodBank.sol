
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title BloodBank
 * @dev A comprehensive smart contract for managing blood donations, quality, and distribution.
 */
contract BloodBank {
    // ==== Access Control ====
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the admin can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
        _initializeValidBloodGroups();
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
        string contact;
        string homeAddress;
        bool isActive;
        BloodTransaction[] transactions;
        uint256 totalVoluntaryDonation;
    }

    struct BloodUnit {
        string bloodGroup;
        string donorCccd;
        uint256 volume;
        uint256 collectedAt;
        uint256 expiryTime;
        uint256 storageTemp;
        BloodStatus status;
        string metadataHash;
        string hospitalName;
    }

    // ==== Storage ====
    mapping(string => Patient) private patients;
    mapping(string => bool) private cccdExists;
    mapping(string => bool) private validBloodGroups;
    mapping(bytes32 => BloodUnit) public bloodUnits;
    bytes32[] public bloodUnitIds;

    // ==== Events ====
    event PatientAdded(bytes32 indexed cccdHash, string cccd, string name);
    event PatientUpdated(bytes32 indexed cccdHash, string cccd);
    event BloodTransactionAdded(bytes32 indexed cccdHash, string cccd);
    event BloodUnitCreated(bytes32 indexed unitId, string bloodGroup);
    event BloodMarkedSpoiled(bytes32 indexed unitId);
    event BloodDistributed(bytes32 indexed unitId, string hospital);

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
        string memory _name,
        uint256 _age,
        uint256 _weight,
        string memory _bloodGroup,
        string memory _contact,
        string memory _homeAddress,
        string memory _cccd
    ) external onlyOwner {
        require(!cccdExists[_cccd], "Patient already registered");
        require(_age >= 18 && _age <= 60, "Age must be between 18 and 60");
        require(_weight >= 45, "Weight must be at least 45kg");
        require(validBloodGroups[_bloodGroup], "Invalid blood group");

        Patient storage p = patients[_cccd];
        p.name = _name;
        p.age = _age;
        p.weight = _weight;
        p.bloodGroup = _normalizeBloodGroup(_bloodGroup);
        p.contact = _contact;
        p.homeAddress = _homeAddress;
        p.cccd = _cccd;
        p.isActive = true;

        cccdExists[_cccd] = true;
        emit PatientAdded(keccak256(bytes(_cccd)), _cccd, _name);
    }

    function updatePatient(
        string memory _cccd,
        string memory _name,
        uint256 _age,
        string memory _bloodGroup,
        string memory _contact,
        string memory _homeAddress
    ) external onlyOwner {
        require(cccdExists[_cccd], "Patient does not exist");
        require(validBloodGroups[_bloodGroup], "Invalid blood group");

        Patient storage p = patients[_cccd];
        p.name = _name;
        p.age = _age;
        p.bloodGroup = _normalizeBloodGroup(_bloodGroup);
        p.contact = _contact;
        p.homeAddress = _homeAddress;

        emit PatientUpdated(keccak256(bytes(_cccd)), _cccd);
    }

    // ==== Blood Donation and Management ====
    function donateBlood(
        string memory _cccd,
        uint256 _volume,
        uint256 _expiryDays,
        uint256 _storageTemp,
        DonationKind _kind,
        string memory _metadataHash,
        string memory _hospitalName
    ) external onlyOwner {
        require(cccdExists[_cccd], "Patient not found");
        require(_volume > 0, "Volume must be greater than 0");

        //Tinh the tich toi da cho phep dua tren can nang (9ml/kg)
        uint256 maxVolume = patients[_cccd].weight * 9;
        require(_volume <= maxVolume, "Donation exceeds 9ml per kg body weight");

        require(_expiryDays <= 45, "Expiry exceeds max 45 days");
        require(_storageTemp >= 4 && _storageTemp <= 8, "Storage temperature must be between 4 and 8 C");

        Patient storage p = patients[_cccd];
        require(p.isActive, "Inactive patient");

        string memory group = _normalizeBloodGroup(p.bloodGroup);
        bytes32 unitId = keccak256(abi.encodePacked(_cccd, block.timestamp, _volume));

        uint256 expiry = block.timestamp + (_expiryDays * 1 days);


        bloodUnits[unitId] = BloodUnit({
            bloodGroup: group,
            donorCccd: _cccd,
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

        emit BloodTransactionAdded(keccak256(bytes(_cccd)), _cccd);
        emit BloodUnitCreated(unitId, group);
    }

    function distributeBlood(bytes32 unitId, string memory _hospital) external onlyOwner {
        require(bloodUnits[unitId].status == BloodStatus.Valid, "Not available");
        bloodUnits[unitId].status = BloodStatus.Used;
        bloodUnits[unitId].hospitalName = _hospital;
        emit BloodDistributed(unitId, _hospital);
    }

    function markAsSpoiled(bytes32 unitId) external onlyOwner {
        require(bloodUnits[unitId].status == BloodStatus.Valid, "Not valid");
        bloodUnits[unitId].status = BloodStatus.Spoiled;
        emit BloodMarkedSpoiled(unitId);
    }

    // ==== View Functions ====
    function getPatientRecord(string memory _cccd) external view returns (
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

        uint256 total = 0;
        uint256 voluntary = 0;

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

    function getPatientTransactions(string memory _cccd, uint256 limit) external view returns (BloodTransaction[] memory) {
        require(cccdExists[_cccd], "Patient not found");
        BloodTransaction[] storage txs = patients[_cccd].transactions;
        uint256 len = txs.length > limit ? limit : txs.length;

        BloodTransaction[] memory result = new BloodTransaction[](len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = txs[i];
        }
        return result;
    }

    function getBloodUnit(bytes32 unitId) external view returns (BloodUnit memory) {
        return bloodUnits[unitId];
    }

    function getAllBloodUnitIds() external view returns (bytes32[] memory) {
        return bloodUnitIds;
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
        return input; // Placeholder for normalization logic like trimming or uppercasing
    }
}

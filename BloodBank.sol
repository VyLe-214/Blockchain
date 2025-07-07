// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BloodDonationSystem {

    enum BloodStatus { Stored, Dispatched }

    address public owner;
    mapping(address => string) public hospitalNames; // Lưu tên bệnh viện theo địa chỉ ví
    mapping(address => bool) public hospitalWhitelist; // Lưu trạng thái whitelist của bệnh viện

    modifier onlyAdmin() {
        require(msg.sender == owner, "Only admin");
        _;
    }

    modifier onlyHospital() {
        require(hospitalWhitelist[msg.sender], "Only hospital");
        _;
    }

    modifier onlyDonor() {
        require(!hospitalWhitelist[msg.sender] && msg.sender != owner, "Only donor");
        _;
    }

    constructor() {
        owner = msg.sender;

        // Sửa địa chỉ ví thành định dạng checksum hợp lệ
        hospitalWhitelist[0x583031D1113aD414F02576BD6afaBfb302140225] = true;
        hospitalNames[0x583031D1113aD414F02576BD6afaBfb302140225] =  "\u0042\u1EC7nh vi\u1EC7n Th\u1EE7 \u0110\u1EE9c";

        hospitalWhitelist[0xdD870fA1b7C4700F2BD7f44238821C26f7392148] = true;
        hospitalNames[0xdD870fA1b7C4700F2BD7f44238821C26f7392148] = "B\u1ec7nh vi\u1ec7n qu\u1eadn 9";
    }

    function addHospital(address hospitalAddress, string memory hospitalName) public onlyAdmin {
        hospitalWhitelist[hospitalAddress] = true;
        hospitalNames[hospitalAddress] = hospitalName;
    }

    struct PendingDonation {
        string bloodType;
        uint volume;
        uint donationDate;
        string location;
        bool exists;
    }

    struct Donation {
        string bloodType;
        uint volume;
        uint timestamp;
        string location;
        bool confirmedByAdmin; 
    }

    struct BloodUnit {
        string cccd;
        string bloodType;
        uint volume;
        BloodStatus status;
        string hospital;
        uint donatedAt;
        uint dispatchedAt;
        string location;
    }

    struct BloodJourney {
        string cccd;
        string bloodType;
        uint volume;
        uint donatedAt;
        string location;
        uint dispatchedAt;
        string hospital;
    }

    struct BloodRequest {
        string hospitalName;
        string bloodType;
        uint requiredVolume;
        bool fulfilled;
    }

    mapping(string => PendingDonation) public pendingDonations;
    mapping(string => Donation[]) private donationHistory;
    BloodUnit[] private bloodUnits;
    BloodRequest[] public bloodRequests;

    mapping(string => uint) private bloodInventory;
    string[] private bloodTypesList;
    string[] public validBloodTypes = ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"];
    mapping(string => bool) private bloodTypeExists;

    event BloodDonated(string cccd, string bloodType, uint volume, string location, uint timestamp);
    event BloodRequested(string hospital, string bloodType, uint volume, bool fulfilled);
    event BloodDispatched(string cccd, string hospital, uint volume);

    function registerDonation(
        string memory _cccd,
        string memory _bloodType,
        uint _volume,
        uint _donationDate,
        string memory _location
    ) public onlyDonor {
        require(_volume > 0, "Invalid blood volume");

        require(bytes(_cccd).length == 12, "CCCD must be 12 digits");
        for (uint i = 0; i < 12; i++) {
            require(bytes(_cccd)[i] >= '0' && bytes(_cccd)[i] <= '9', "CCCD must be all digits");
        }
        
        bool isValidBloodType = false;
        for (uint i = 0; i < validBloodTypes.length; i++) {
            if (keccak256(bytes(_bloodType)) == keccak256(bytes(validBloodTypes[i]))) {
                isValidBloodType = true;
                break;
            }
        }
        require(isValidBloodType, "Invalid blood type");

        require(!pendingDonations[_cccd].exists, "Already registered");
        
        pendingDonations[_cccd] = PendingDonation({
            bloodType: _bloodType,
            volume: _volume,
            donationDate: _donationDate,
            location: _location,
            exists: true
        });
    }

    // Bước 2: Admin hoặc bệnh viện xác nhận donation và nhập kho máu
    function confirmDonation(string memory _cccd) public onlyAdmin {
        require(pendingDonations[_cccd].exists, "No pending donation");

        PendingDonation memory p = pendingDonations[_cccd];
        
        // Đưa donation vào bloodUnits
        bloodUnits.push(BloodUnit({
            cccd: _cccd,
            bloodType: p.bloodType,
            volume: p.volume,
            status: BloodStatus.Stored,
            hospital: hospitalNames[msg.sender], 
            donatedAt: block.timestamp,
            dispatchedAt: 0,
            location: p.location
        }));

        // Cập nhật inventory
        if (!bloodTypeExists[p.bloodType]) {
            bloodTypesList.push(p.bloodType);  // Thêm loại máu mới vào danh sách
            bloodTypeExists[p.bloodType] = true;  // Đánh dấu rằng loại máu này đã tồn tại
        }

        bloodInventory[p.bloodType] += p.volume;

        donationHistory[_cccd].push(Donation({
            bloodType: p.bloodType,
            volume: p.volume,
            timestamp: block.timestamp,
            location: p.location,
            confirmedByAdmin: true  // Đánh dấu là đã được xác nhận
        }));


        // Xóa donation khỏi pendingDonations sau khi xác nhận
        delete pendingDonations[_cccd];
        
        emit BloodDonated(_cccd, p.bloodType, p.volume, p.location, block.timestamp);
    }


    function requestBlood(
        string memory _bloodType,
        uint _volume
    ) public onlyHospital {
        require(_volume > 0, "Invalid volume");

        uint remaining = _volume;
        uint availableInStock = bloodInventory[_bloodType];

        require(availableInStock >= remaining, "Not enough blood available in stock");

        // Lấy tên bệnh viện từ địa chỉ ví
        string memory hospitalName = hospitalNames[msg.sender];

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
                    unit.hospital = hospitalName; // Lưu tên bệnh viện
                    unit.dispatchedAt = block.timestamp;
                    emit BloodDispatched(unit.cccd, hospitalName, unit.volume);
                } else {
                    unit.volume -= remaining;
                    bloodInventory[_bloodType] -= remaining;
                    bloodUnits.push(BloodUnit({
                        cccd: unit.cccd,
                        bloodType: unit.bloodType,
                        volume: remaining,
                        status: BloodStatus.Dispatched,
                        hospital: hospitalName,
                        donatedAt: unit.donatedAt,
                        dispatchedAt: block.timestamp,
                        location: unit.location
                    }));
                    emit BloodDispatched(unit.cccd, hospitalName, remaining);
                    remaining = 0;
                }
            }
        }

        bool fulfilled = (remaining == 0);

        bloodRequests.push(BloodRequest({
            hospitalName: hospitalName,
            bloodType: _bloodType,
            requiredVolume: _volume,
            fulfilled: fulfilled
        }));

        emit BloodRequested(hospitalName, _bloodType, _volume, fulfilled);
    }

    function getDonationHistory(string memory _cccd) public view returns (
        uint totalDonations,
        uint totalVolume,
        uint lastDonationTimestamp
    ) {
        uint count = donationHistory[_cccd].length;
        lastDonationTimestamp = 0;
        totalDonations = count;
        totalVolume = 0;

        if (count > 0) {
            for (uint i = 0; i < count; i++) {
                Donation memory d = donationHistory[_cccd][i];
                totalVolume += d.volume;
            }

            lastDonationTimestamp = donationHistory[_cccd][count - 1].timestamp;
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

    function getBloodJourney(string memory _cccd) public view returns (
        string[] memory bloodTypes,
        uint[] memory volumes,
        uint[] memory donatedAts,
        string[] memory locations,
        uint[] memory dispatchedAts,
        string[] memory hospitals
    ) {
        uint count;
        for (uint i = 0; i < bloodUnits.length; i++) {
            if (keccak256(bytes(bloodUnits[i].cccd)) == keccak256(bytes(_cccd))) {
                count++;
            }
        }
        
        bloodTypes = new string[](count);
        volumes = new uint[](count);
        donatedAts = new uint[](count);
        locations = new string[](count);
        dispatchedAts = new uint[](count);
        hospitals = new string[](count);

        uint index = 0;
        for (uint i = 0; i < bloodUnits.length; i++) {
            if (keccak256(bytes(bloodUnits[i].cccd)) == keccak256(bytes(_cccd))) {
                bloodTypes[index] = bloodUnits[i].bloodType;
                volumes[index] = bloodUnits[i].volume;
                donatedAts[index] = bloodUnits[i].donatedAt;
                locations[index] = bloodUnits[i].location;
                dispatchedAts[index] = bloodUnits[i].dispatchedAt;
                hospitals[index] = bloodUnits[i].hospital;
                index++;
            }
        }

        return (bloodTypes, volumes, donatedAts, locations, dispatchedAts, hospitals);
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

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title BloodBank
 * @dev A smart contract for managing blood transactions and patient records in a blood bank.
 */
contract BloodBank {
    // Contract owner (usually hospital)
    // Nguoi trien khai hop dong (benh vien) co quyen thuc hien cac thao tac
    address public owner;

    constructor() {
        //Gan bien owner bang dia chi vi cua nguoi trien khai hop dong
        owner = msg.sender;
    }

    // Enum for patient type: Phan loai Donor (nguoi hien mau); receiver (nguoi nhan mau)
    enum PatientType {
        Donor,
        Receiver
    }

    // Struct for blood transaction: Ghi lai tung lan hien mau (ai hien/nhan)
    struct BloodTransaction {
        PatientType patientType;
        uint256 time;
        address from;
        address to;
        uint256 volume; // so ml mau giao dich
    }

    // Struct for patient
    /**
    * @bloodGroup: nhom mau (A+, O-, AB+)
    * @contact: so dien thoai lien hien
    * @BloodTransaction: so lan hien mau
    */
    struct Patient {
        string cccd;
        string name;
        uint256 age;
        string bloodGroup;
        string contact;
        string homeAddress;
        BloodTransaction[] bT;
    }

    // Patient records: luu tru va xuat du lieu
    // Mapping tu cccd => bool (true/false):  Kiem tra xem benh nhan voi ma cccd da duoc dang ky hay chua.
    Patient[] private PatientRecord;
    mapping(string => uint256) private PatientRecordIndex;
    mapping(string => bool) private cccdExists;

    // Access modifier
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the admin can perform this action");
        _;
    }

    // Events: ghi nhan va gui thong bao
    event PatientAdded(bytes32 indexed cccdHash, string cccd, string name);
    event PatientUpdated(bytes32 indexed cccdHash, string cccd);
    event BloodTransactionAdded(
        bytes32 indexed cccdHash,
         string cccd,
        PatientType patientType,
        address from,
        address to
    );

    // Register a new patient
    function newPatient(
        string memory _name,
        uint256 _age,
        string memory _bloodGroup,
        string memory _contact,
        string memory _homeAddress,
        string memory _cccd
    ) external onlyOwner {
        // onlyOwner kiem tra quyen truy cap
        require(!cccdExists[_cccd], "Patient already registered");

        uint256 index = PatientRecord.length;
        /**
        * @PatientRecord.push: Day them 1 phan tu vao cuoi mang PatientRecord
        * p tu input se truyen vao ham newPatien
        **/
        PatientRecord.push();
        Patient storage p = PatientRecord[index];
        p.name = _name;
        p.age = _age;
        p.bloodGroup = _bloodGroup;
        p.contact = _contact;
        p.homeAddress = _homeAddress;
        p.cccd = _cccd;

        PatientRecordIndex[_cccd] = index;
        cccdExists[_cccd] = true; // tranh trung lap

        emit PatientAdded(keccak256(bytes(_cccd)), _cccd, _name); //thong bao benh nhan moi da dc them thanh cong
    }

    // Update existing patient
    function updatePatient(
        string memory _cccd,
        string memory _name,
        uint256 _age,
        string memory _bloodGroup,
        string memory _contact,
        string memory _homeAddress
    ) external onlyOwner {
        require(cccdExists[_cccd], "Patient does not exist");

        uint256 index = PatientRecordIndex[_cccd];
        Patient storage p = PatientRecord[index];
        p.name = _name;
        p.age = _age;
        p.bloodGroup = _bloodGroup;
        p.contact = _contact;
        p.homeAddress = _homeAddress;

        emit PatientUpdated(keccak256(bytes(_cccd)), _cccd);
    }

    // Record a blood transaction
    function bloodTransaction(
        string memory _cccd,
        PatientType _type,
        address _from,
        address _to,
        uint256 _volume
    ) external onlyOwner {
        require(cccdExists[_cccd], "Patient not found");
        require(_volume > 0, "Volume must be greater than 0");

        uint256 index = PatientRecordIndex[_cccd];

        BloodTransaction memory txObj = BloodTransaction({
            patientType: _type,
            time: block.timestamp,
            from: _from,
            to: _to,
            volume: _volume
        });

        PatientRecord[index].bT.push(txObj);// Gan giao dich vao lich su benh nhan

        emit BloodTransactionAdded(keccak256(bytes(_cccd)), _cccd, _type, _from, _to);
    }
    
    // Tong mau da hien cua mot benh nhan
    function getTotalBloodDonated(string memory _cccd) external view returns (uint256 totalVolume) {
         require(cccdExists[_cccd], "Patient not found");

         uint256 index = PatientRecordIndex[_cccd];
         Patient storage p = PatientRecord[index];
         
        for (uint256 i = 0; i < p.bT.length; i++) {
            if (p.bT[i].patientType == PatientType.Donor) {
            totalVolume += p.bT[i].volume;
            }
        }
        return totalVolume;
    }

    // View patient record
    function getPatientRecord(string memory _cccd)
        external
        view
        returns (Patient memory)
    {
        require(cccdExists[_cccd], "Patient not found");
        return PatientRecord[PatientRecordIndex[_cccd]];
    }

    // View all patient records
    function getAllRecord() external view returns (Patient[] memory) {
        return PatientRecord;
    }

    // View all blood transactions for a patient
    function getPatientTransactions(string memory _cccd)
        external
        view
        returns (BloodTransaction[] memory)
    {
        require(cccdExists[_cccd], "Patient not found");
        return PatientRecord[PatientRecordIndex[_cccd]].bT;
    }
}

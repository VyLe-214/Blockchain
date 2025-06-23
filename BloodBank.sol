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
        uint256 aadhar;
        string name;
        uint256 age;
        string bloodGroup;
        string contact;
        string homeAddress;
        BloodTransaction[] bT;
    }

    // Patient records: luu tru va xuat du lieu
    // Mapping tu Aadhar => bool (true/false):  Kiem tra xem benh nhan voi ma Aadhar da duoc dang ky hay chua.
    Patient[] private PatientRecord;
    mapping(uint256 => uint256) private PatientRecordIndex;
    mapping(uint256 => bool) private aadharExists;

    // Access modifier
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the admin can perform this action");
        _;
    }

    // Events: ghi nhan va gui thong bao
    event PatientAdded(uint256 indexed aadhar, string name);
    event PatientUpdated(uint256 indexed aadhar);
    event BloodTransactionAdded(
        uint256 indexed aadhar,
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
        uint256 _aadhar
    ) external onlyOwner {
        // onlyOwner kiem tra quyen truy cap
        require(!aadharExists[_aadhar], "Patient already registered");

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
        p.aadhar = _aadhar;

        PatientRecordIndex[_aadhar] = index;
        aadharExists[_aadhar] = true; // tranh trung lap

        emit PatientAdded(_aadhar, _name); //thong bao benh nhan moi da dc them thanh cong
    }

    // Update existing patient
    function updatePatient(
        uint256 _aadhar,
        string memory _name,
        uint256 _age,
        string memory _bloodGroup,
        string memory _contact,
        string memory _homeAddress
    ) external onlyOwner {
        require(aadharExists[_aadhar], "Patient does not exist");

        uint256 index = PatientRecordIndex[_aadhar];
        Patient storage p = PatientRecord[index];
        p.name = _name;
        p.age = _age;
        p.bloodGroup = _bloodGroup;
        p.contact = _contact;
        p.homeAddress = _homeAddress;

        emit PatientUpdated(_aadhar);
    }

    // Record a blood transaction
    function bloodTransaction(
        uint256 _aadhar,
        PatientType _type,
        address _from,
        address _to,
        uint256 _volume
    ) external onlyOwner {
        require(aadharExists[_aadhar], "Patient not found");
        require(_volume > 0, "Volume must be greater than 0");

        uint256 index = PatientRecordIndex[_aadhar];

        BloodTransaction memory txObj = BloodTransaction({
            patientType: _type,
            time: block.timestamp,
            from: _from,
            to: _to,
            volume: _volume
        });

        PatientRecord[index].bT.push(txObj);// Gan giao dich vao lich su benh nhan

        emit BloodTransactionAdded(_aadhar, _type, _from, _to);
    }
    
    // Tong mau da hien cua mot benh nhan
    function getTotalBloodDonated(uint256 _aadhar) external view returns (uint256 totalVolume) {
         require(aadharExists[_aadhar], "Patient not found");

         uint256 index = PatientRecordIndex[_aadhar];
         Patient storage p = PatientRecord[index];
         
        for (uint256 i = 0; i < p.bT.length; i++) {
            if (p.bT[i].patientType == PatientType.Donor) {
            totalVolume += p.bT[i].volume;
            }
        }
        return totalVolume;
    }

    // View patient record
    function getPatientRecord(uint256 _aadhar)
        external
        view
        returns (Patient memory)
    {
        require(aadharExists[_aadhar], "Patient not found");
        return PatientRecord[PatientRecordIndex[_aadhar]];
    }

    // View all patient records
    function getAllRecord() external view returns (Patient[] memory) {
        return PatientRecord;
    }

    // View all blood transactions for a patient
    function getPatientTransactions(uint256 _aadhar)
        external
        view
        returns (BloodTransaction[] memory)
    {
        require(aadharExists[_aadhar], "Patient not found");
        return PatientRecord[PatientRecordIndex[_aadhar]].bT;
    }
}

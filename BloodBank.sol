// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BloodDonationSystem {

    enum BloodStatus { Stored, Dispatched }

    struct Donation {
        string bloodType;
        uint volume;
        uint timestamp;
        string location;
        string city;
    }

    struct BloodUnit {
        string cccd;
        string bloodType;
        uint volume;
        string city;
        BloodStatus status;
        string hospital;
        uint donatedAt;
        uint dispatchedAt;
    }

    struct BloodRequest {
        string hospitalName;
        string city;
        string bloodType;
        uint requiredVolume;
        bool fulfilled;
    }

    mapping(string => Donation[]) private donationHistory;
    BloodUnit[] public bloodUnits;
    BloodRequest[] public bloodRequests;

    event BloodDonated(string cccd, string bloodType, uint volume, string location, string city, uint timestamp);
    event BloodRequested(string hospital, string city, string bloodType, uint volume, bool fulfilled);
    event BloodDispatched(string cccd, string hospital, uint volume);

    function donateBlood(
        string memory _cccd,
        string memory _bloodType,
        uint _volume,
        string memory _location,
        string memory _city
    ) public {
        require(_volume > 0, "Invalid blood volume");

        uint timestamp = block.timestamp;

        donationHistory[_cccd].push(Donation({
            bloodType: _bloodType,
            volume: _volume,
            timestamp: timestamp,
            location: _location,
            city: _city
        }));

        bloodUnits.push(BloodUnit({
            cccd: _cccd,
            bloodType: _bloodType,
            volume: _volume,
            city: _city,
            status: BloodStatus.Stored,
            hospital: "",
            donatedAt: timestamp,
            dispatchedAt: 0
        }));

        emit BloodDonated(_cccd, _bloodType, _volume, _location, _city, timestamp);
    }

    function requestBlood(
        string memory _hospital,
        string memory _city,
        string memory _bloodType,
        uint _volume
    ) public {
        require(_volume > 0, "Invalid volume");

        uint remaining = _volume;

        for (uint i = 0; i < bloodUnits.length && remaining > 0; i++) {
            BloodUnit storage unit = bloodUnits[i];

            if (
                unit.status == BloodStatus.Stored &&
                keccak256(bytes(unit.bloodType)) == keccak256(bytes(_bloodType)) &&
                keccak256(bytes(unit.city)) == keccak256(bytes(_city))
            ) {
                if (unit.volume <= remaining) {
                    remaining -= unit.volume;
                    unit.status = BloodStatus.Dispatched;
                    unit.hospital = _hospital;
                    unit.dispatchedAt = block.timestamp;
                    emit BloodDispatched(unit.cccd, _hospital, unit.volume);
                } else {
                    unit.volume -= remaining;
                    bloodUnits.push(BloodUnit({
                        cccd: unit.cccd,
                        bloodType: unit.bloodType,
                        volume: remaining,
                        city: unit.city,
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
            city: _city,
            bloodType: _bloodType,
            requiredVolume: _volume,
            fulfilled: fulfilled
        }));

        emit BloodRequested(_hospital, _city, _bloodType, _volume, fulfilled);
    }

    function getDonationSummary(string memory _cccd) public view returns (
        uint totalTimes,
        uint totalVolume
    ) {
        Donation[] memory list = donationHistory[_cccd];
        uint total = 0;
        for (uint i = 0; i < list.length; i++) {
            total += list[i].volume;
        }
        return (list.length, total);
    }

    function getDonationDetails(string memory _cccd) public view returns (Donation[] memory) {
        return donationHistory[_cccd];
    }

    function getBloodUnitsByCCCD(string memory _cccd) public view returns (BloodUnit[] memory) {
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
}

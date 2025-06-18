# Blockchain
project nhóm
🧾 Giải thích tính năng của smart contract
Tính năng	Giải thích
owner	Người triển khai hợp đồng (bệnh viện) có quyền thực hiện các thao tác nhạy cảm
onlyOwner modifier	Bảo vệ các chức năng chỉ cho phép bệnh viện thực hiện
PatientType enum	Phân loại bệnh nhân: Donor (người hiến máu) và Receiver (người nhận máu)
Patient struct	Lưu trữ đầy đủ hồ sơ của bệnh nhân (gồm cả lịch sử giao dịch máu)
BloodTransaction struct	Ghi lại chi tiết từng lần hiến hoặc nhận máu: ai hiến/nhận, thời gian, địa chỉ
newPatient()	Thêm bệnh nhân mới, kèm kiểm tra không trùng Aadhar
updatePatient()	Cho phép cập nhật thông tin bệnh nhân khi có sai sót
bloodTransaction()	Ghi lại giao dịch máu cho bệnh nhân đã có hồ sơ
getPatientRecord()	Truy xuất hồ sơ một bệnh nhân theo Aadhar
getAllRecord()	Trả về toàn bộ danh sách bệnh nhân trong hệ thống
getPatientTransactions()	Truy xuất lịch sử giao dịch máu của một bệnh nhân
event	Phát tín hiệu cho frontend hoặc hệ thống log biết khi có thao tác xảy ra

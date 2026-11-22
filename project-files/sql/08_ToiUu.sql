/* =====================================================================
   08_ToiUu.sql  -  TỐI ƯU TRUY VẤN BẰNG EXECUTION PLAN VÀ CHỈ MỤC
   Quy trình cho MỖI truy vấn nặng (bảng >= 1.000 dòng: HoaDon 1.502 dòng, HD_M ~4.500 dòng):
     B1. Bật SET STATISTICS IO, TIME và bật Actual Execution Plan (Ctrl+M trong SSMS).
     B2. Chạy truy vấn TRƯỚC khi có chỉ mục -> ghi lại logical reads, CPU time, tên toán tử trong plan (Scan/Seek).
     B3. Dán truy vấn + plan cho AI (ChatGPT/Gemini/Copilot, không dán dữ liệu thật) và xin đề xuất chỉ mục.
     B4. Đánh giá từng đề xuất của AI: CHẤP NHẬN hoặc BÁC BỎ kèm lý do. Tạo chỉ mục đã chấp nhận.
     B5. Chạy lại truy vấn -> ghi số liệu SAU và so sánh.
   Số logical reads trước/sau đã điền từ lần chạy thật của nhóm. Thời gian CPU/elapsed gần như 0 ms vì dữ liệu còn nhỏ nên lấy logical reads làm bằng chứng chính.
   ===================================================================== */
USE QuanLyNhaHang;
GO
-- Chốt chặn: nếu chưa vào được CSDL QuanLyNhaHang thì bỏ qua file này (tránh tạo nhầm đối tượng vào CSDL khác)
IF DB_NAME() <> N'QuanLyNhaHang'
BEGIN
    RAISERROR(N'Chưa có CSDL QuanLyNhaHang - hãy chạy 01_CSDL.sql thành công trước. Bỏ qua file này.', 16, 1);
    SET NOEXEC ON;
END
GO

-- Xóa chỉ mục cũ nếu chạy lại để phép đo "trước" luôn đúng
DROP INDEX IF EXISTS IX_HoaDon_Ban_ThoiGian        ON HoaDon;
DROP INDEX IF EXISTS IX_HD_M_MaMon                  ON HD_M;
DROP INDEX IF EXISTS IX_HoaDon_KhachHang_ThoiGian   ON HoaDon;
GO

SET NOCOUNT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

/* =====================================================================
   TRUY VẤN NẶNG 1: tra cứu hóa đơn của một bàn trong một tháng
   ===================================================================== */
-- ---- TRƯỚC khi có chỉ mục ----
SELECT MaHD, ThoiGianMo, TrangThai
FROM HoaDon
WHERE MaBan = 5 AND ThoiGianMo >= '2025-06-01' AND ThoiGianMo < '2025-07-01';
-- Số đo của nhóm: logical reads HoaDon = 15 ; plan dự kiến: Clustered Index Scan (nhóm mở Actual Plan để xác nhận)

/* Đề xuất của AI (điền thật theo câu trả lời AI nhóm nhận được; ví dụ thường gặp):
   - AI #1.1: tạo chỉ mục (MaBan, ThoiGianMo)               -> CHẤP NHẬN: cột điều kiện bằng đứng trước, cột khoảng đứng sau,
                                                               plan chuyển từ Scan sang Seek.
   - AI #1.2: thêm INCLUDE (TrangThai)                       -> CHẤP NHẬN/BÁC BỎ tùy số liệu: nếu bỏ INCLUDE phải thêm Key Lookup, đo xem có đáng không.
   - AI #1.3: tạo chỉ mục riêng cho cột TrangThai            -> BÁC BỎ: chỉ có 3 giá trị, độ chọn lọc rất thấp, tốn chỗ và chậm khi ghi. */
CREATE NONCLUSTERED INDEX IX_HoaDon_Ban_ThoiGian ON HoaDon (MaBan, ThoiGianMo) INCLUDE (TrangThai);
GO
-- ---- SAU khi có chỉ mục ----
SELECT MaHD, ThoiGianMo, TrangThai
FROM HoaDon
WHERE MaBan = 5 AND ThoiGianMo >= '2025-06-01' AND ThoiGianMo < '2025-07-01';
-- Số đo của nhóm: logical reads HoaDon = 2 ; plan dự kiến: Index Seek (nhóm mở Actual Plan để xác nhận)
GO

/* =====================================================================
   TRUY VẤN NẶNG 2: tổng số lượng bán của một món (quét bảng chi tiết hóa đơn)
   Khóa chính của HD_M là (MaHD, MaMon) nên tìm theo MaMon phải quét toàn bảng.
   ===================================================================== */
-- ---- TRƯỚC ----
SELECT MaMon, SUM(SoLuong) AS TongSoLuong, SUM(SoLuong * DonGia) AS TongTien
FROM HD_M
WHERE MaMon = 2
GROUP BY MaMon;
-- Số đo của nhóm: logical reads HD_M = 20 ; plan dự kiến: Clustered Index Scan (nhóm mở Actual Plan để xác nhận)

/* Đề xuất của AI:
   - AI #2.1: chỉ mục (MaMon) INCLUDE (SoLuong, DonGia)     -> CHẤP NHẬN: chỉ mục phủ (covering), không cần quay lại bảng.
   - AI #2.2: chỉ mục (DonGia)                               -> BÁC BỎ: không truy vấn nào lọc theo DonGia.
   - AI #2.3: chỉ mục columnstore cho HD_M                    -> BÁC BỎ (hoặc để mở rộng): bảng chỉ vài nghìn dòng, columnstore chưa đáng. */
CREATE NONCLUSTERED INDEX IX_HD_M_MaMon ON HD_M (MaMon) INCLUDE (SoLuong, DonGia);
GO
-- ---- SAU ----
SELECT MaMon, SUM(SoLuong) AS TongSoLuong, SUM(SoLuong * DonGia) AS TongTien
FROM HD_M
WHERE MaMon = 2
GROUP BY MaMon;
-- Số đo của nhóm: logical reads HD_M = 3 ; plan dự kiến: Index Seek (IX_HD_M_MaMon) (nhóm mở Actual Plan để xác nhận)
GO

/* =====================================================================
   TRUY VẤN NẶNG 3: 10 hóa đơn gần nhất của một khách hàng (có ORDER BY)
   ===================================================================== */
-- ---- TRƯỚC ----
SELECT TOP 10 MaHD, ThoiGianMo, MaBan
FROM HoaDon
WHERE MaKH = 7
ORDER BY ThoiGianMo DESC;
-- Số đo của nhóm: logical reads HoaDon = 15 ; plan dự kiến: Scan + toán tử Sort (nhóm mở Actual Plan để xác nhận)

/* Đề xuất của AI:
   - AI #3.1: chỉ mục (MaKH, ThoiGianMo DESC) INCLUDE (MaBan) -> CHẤP NHẬN: seek theo MaKH, dữ liệu đã sắp theo thời gian nên bỏ được Sort.
   - AI #3.2: chỉ mục riêng (ThoiGianMo)                      -> BÁC BỎ: đã có chỉ mục tốt hơn cho truy vấn này, thêm chỉ mục làm chậm INSERT. */
CREATE NONCLUSTERED INDEX IX_HoaDon_KhachHang_ThoiGian ON HoaDon (MaKH, ThoiGianMo DESC) INCLUDE (MaBan);
GO
-- ---- SAU ----
SELECT TOP 10 MaHD, ThoiGianMo, MaBan
FROM HoaDon
WHERE MaKH = 7
ORDER BY ThoiGianMo DESC;
-- Số đo của nhóm: logical reads HoaDon = 2 ; plan dự kiến: Index Seek, không còn Sort (nhóm mở Actual Plan để xác nhận)
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

/* ---------- Bảng tổng hợp để đưa vào báo cáo (nhóm điền) ----------
   | Truy vấn | Logical reads trước | Logical reads sau | CPU/Elapsed trước -> sau | Chỉ mục tạo | AI đề xuất / chấp nhận / bác bỏ |
   | 1        | 15                  | 2                 | 0 ms -> 0 ms             | IX_HoaDon_Ban_ThoiGian        | 3 / 2 / 1 |
   | 2        | 20                  | 3                 | 1 ms -> 0 ms             | IX_HD_M_MaMon                 | 3 / 1 / 2 |
   | 3        | 15                  | 2                 | 0 ms -> 0 ms             | IX_HoaDon_KhachHang_ThoiGian  | 2 / 1 / 1 |
   Lưu ý: chỉ mục làm INSERT/UPDATE chậm hơn một chút, nên chỉ giữ chỉ mục phục vụ truy vấn thật sự thường dùng. */

-- Xem danh sách chỉ mục hiện có
SELECT OBJECT_NAME(object_id) AS Bang, name AS TenChiMuc, type_desc
FROM sys.indexes
WHERE object_id IN (OBJECT_ID('HoaDon'), OBJECT_ID('HD_M')) AND name IS NOT NULL
ORDER BY Bang, name;
GO

SET NOEXEC OFF;
GO

/* =====================================================================
   04_TruyVan_View.sql  -  4 VIEW và 20 TRUY VẤN
   Cơ cấu theo rubric: 4 đơn giản | 3 kết nối (có kết ngoài) | 3 gom nhóm
   | 4 truy vấn con (có phép chia) | 2 tập hợp | 2 CTE (có đệ quy) | 2 ranking.
   Có 6 truy vấn đánh dấu [NL->SQL] (rubric cần tối thiểu 5) để ghi vào nhật ký AI (prompt, mã AI sinh, rà soát, chỗ đã sửa).
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

/* =====================================================================
   PHẦN A - VIEW
   ===================================================================== */

-- View 1: thực đơn đang bán (dành cho nhân viên phục vụ, chỉ lộ cột cần thiết)
CREATE VIEW vw_MenuDangBan AS
SELECT m.MaMon, m.TenMon, lm.TenLoai, m.PhanLoai, m.GiaBan
FROM Mon m
JOIN LoaiMon lm ON lm.MaLoai = m.MaLoai
WHERE m.DangBan = 1;
GO

-- View 2: món cần chế biến (dành cho bếp: chỉ thấy bàn, món, số lượng; KHÔNG thấy giá và tiền)
-- Đây là view giới hạn cột + dòng phục vụ phân quyền (file 07).
CREATE VIEW vw_MonCanCheBien AS
SELECT b.TenBan, m.TenMon, ct.SoLuong, hd.ThoiGianMo
FROM HoaDon hd
JOIN HD_M ct ON ct.MaHD = hd.MaHD
JOIN Mon  m  ON m.MaMon = ct.MaMon
JOIN Ban  b  ON b.MaBan = hd.MaBan
WHERE hd.TrangThai = 'DangMo';
GO

-- View 3: tổng tiền từng hóa đơn (trước và sau giảm giá), dùng cho báo cáo doanh thu
CREATE VIEW vw_DoanhThuHoaDon AS
SELECT hd.MaHD, hd.MaBan, hd.MaNV, hd.MaKH, hd.ThoiGianMo, hd.TrangThai,
       SUM(ct.SoLuong * ct.DonGia)                                    AS TongTruocGiam,
       SUM(ct.SoLuong * ct.DonGia) * (100 - hd.GiamGiaPhanTram) / 100 AS TongPhaiTra
FROM HoaDon hd
JOIN HD_M ct ON ct.MaHD = hd.MaHD
GROUP BY hd.MaHD, hd.MaBan, hd.MaNV, hd.MaKH, hd.ThoiGianMo, hd.TrangThai, hd.GiamGiaPhanTram;
GO

-- View 4: nguyên liệu dưới định mức tồn (dành cho quản lý)
CREATE VIEW vw_TonKhoThap AS
SELECT MaNL, TenNL, DonViTinh, TonKho, DinhMucTon, DinhMucTon - TonKho AS CanNhapThem
FROM NguyenLieu
WHERE TonKho < DinhMucTon;
GO

-- Chạy thử 4 view
SELECT TOP 5 * FROM vw_MenuDangBan ORDER BY GiaBan DESC;
SELECT TOP 5 * FROM vw_MonCanCheBien;                 -- chưa có hóa đơn đang mở nên có thể rỗng
SELECT TOP 5 * FROM vw_DoanhThuHoaDon WHERE TrangThai = 'DaThanhToan' ORDER BY TongPhaiTra DESC;
SELECT * FROM vw_TonKhoThap;
GO

/* =====================================================================
   PHẦN B - 20 TRUY VẤN
   ===================================================================== */

/* ---------- NHÓM 1: 4 truy vấn đơn giản (SELECT - FROM - WHERE, có hàm và phép toán) ---------- */

-- Q1. Món đang bán có giá trên 40.000đ, kèm giá sau khi giảm 10% (phép toán), sắp xếp giá giảm dần
SELECT TenMon, GiaBan, GiaBan * 0.9 AS GiaGiam10Phan_Tram
FROM Mon
WHERE DangBan = 1 AND GiaBan > 40000
ORDER BY GiaBan DESC;

-- Q2. Nhân viên đang làm: họ tên in hoa và số tháng đã làm việc (hàm UPPER, DATEDIFF)
SELECT MaNV, UPPER(HoTen) AS HoTenInHoa, NgayVaoLam,
       DATEDIFF(MONTH, NgayVaoLam, GETDATE()) AS SoThangLamViec
FROM NhanVien
WHERE DangLam = 1
ORDER BY NgayVaoLam;

-- Q3. Hóa đơn thanh toán tiền mặt trong tháng 3/2025, kèm số phút phục vụ (hàm DATEDIFF)
SELECT MaHD, MaBan, ThoiGianMo, DATEDIFF(MINUTE, ThoiGianMo, ThoiGianDong) AS SoPhutPhucVu
FROM HoaDon
WHERE PhuongThucTT = 'TienMat'
  AND ThoiGianMo >= '2025-03-01' AND ThoiGianMo < '2025-04-01'
ORDER BY ThoiGianMo;

-- Q4. Khách hàng có số điện thoại đầu 090 và từ 100 điểm trở lên (LIKE)
SELECT MaKH, HoTen, SDT, DiemTichLuy
FROM KhachHang
WHERE SDT LIKE '090%' AND DiemTichLuy >= 100
ORDER BY DiemTichLuy DESC;

/* ---------- NHÓM 2: 3 truy vấn kết nối (có kết ngoài) ---------- */

-- Q5. 20 hóa đơn mới nhất kèm tên bàn và nhân viên lập (INNER JOIN nhiều bảng)
SELECT TOP 20 hd.MaHD, hd.ThoiGianMo, b.TenBan, nv.HoTen AS NhanVienLap, hd.TrangThai
FROM HoaDon hd
JOIN Ban b      ON b.MaBan = hd.MaBan
JOIN NhanVien nv ON nv.MaNV = hd.MaNV
ORDER BY hd.ThoiGianMo DESC;

-- Q6. Tất cả khách hàng kể cả người chưa có hóa đơn nào (LEFT JOIN - kết ngoài)
SELECT kh.MaKH, kh.HoTen, COUNT(hd.MaHD) AS SoHoaDon
FROM KhachHang kh
LEFT JOIN HoaDon hd ON hd.MaKH = kh.MaKH
GROUP BY kh.MaKH, kh.HoTen
ORDER BY SoHoaDon, kh.MaKH;

-- Q7. Món kèm loại món và loại cha của nó (tự kết bảng LoaiMon bằng LEFT JOIN)
SELECT m.TenMon, lm.TenLoai, cha.TenLoai AS LoaiCha
FROM Mon m
JOIN LoaiMon lm      ON lm.MaLoai = m.MaLoai
LEFT JOIN LoaiMon cha ON cha.MaLoai = lm.MaLoaiCha
ORDER BY cha.TenLoai, lm.TenLoai, m.TenMon;

/* ---------- NHÓM 3: 3 truy vấn gom nhóm (GROUP BY, HAVING, ORDER BY) ---------- */

-- Q8. Doanh thu theo tháng (hóa đơn đã thanh toán)
SELECT YEAR(ThoiGianMo) AS Nam, MONTH(ThoiGianMo) AS Thang,
       COUNT(*) AS SoHoaDon, SUM(TongPhaiTra) AS DoanhThu
FROM vw_DoanhThuHoaDon
WHERE TrangThai = 'DaThanhToan'
GROUP BY YEAR(ThoiGianMo), MONTH(ThoiGianMo)
ORDER BY Nam, Thang;

-- Q9. [NL->SQL #1] Nhân viên lập trên 280 hóa đơn đã thanh toán, kèm tổng doanh thu
-- Prompt gửi AI: "Liệt kê nhân viên đã lập hơn 280 hóa đơn đã thanh toán, kèm số hóa đơn và tổng doanh thu, xếp theo doanh thu giảm dần."
-- Mã AI sinh / Rà soát / Chỗ đã sửa: nhóm ghi vào nhật ký AI sau khi chạy thật.
SELECT nv.MaNV, nv.HoTen, COUNT(*) AS SoHoaDon, SUM(v.TongPhaiTra) AS DoanhThu
FROM vw_DoanhThuHoaDon v
JOIN NhanVien nv ON nv.MaNV = v.MaNV
WHERE v.TrangThai = 'DaThanhToan'
GROUP BY nv.MaNV, nv.HoTen
HAVING COUNT(*) > 280
ORDER BY DoanhThu DESC;

-- Q10. Tổng số lượng bán theo loại món, chỉ lấy loại bán trên 1.000 phần
SELECT lm.TenLoai, SUM(ct.SoLuong) AS TongSoLuong
FROM HD_M ct
JOIN Mon m ON m.MaMon = ct.MaMon
JOIN LoaiMon lm ON lm.MaLoai = m.MaLoai
GROUP BY lm.TenLoai
HAVING SUM(ct.SoLuong) > 1000
ORDER BY TongSoLuong DESC;

/* ---------- NHÓM 4: 4 truy vấn con / lồng (IN, EXISTS, ALL, ANY, phép chia) ---------- */

-- Q11. (IN) Khách hàng từng gọi món "Bánh tiramisu"
SELECT MaKH, HoTen
FROM KhachHang
WHERE MaKH IN (SELECT hd.MaKH
               FROM HoaDon hd
               JOIN HD_M ct ON ct.MaHD = hd.MaHD
               JOIN Mon m   ON m.MaMon = ct.MaMon
               WHERE m.TenMon = N'Bánh tiramisu');

-- Q12. (EXISTS / NOT EXISTS) Nhà cung cấp đã có phiếu nhập; và nguyên liệu chưa từng được nhập
SELECT ncc.MaNCC, ncc.TenNCC
FROM NhaCungCap ncc
WHERE EXISTS (SELECT 1 FROM PhieuNhap pn WHERE pn.MaNCC = ncc.MaNCC);

SELECT nl.MaNL, nl.TenNL
FROM NguyenLieu nl
WHERE NOT EXISTS (SELECT 1 FROM ChiTietPhieuNhap ct WHERE ct.MaNL = nl.MaNL);

-- Q13. [NL->SQL #2] (ALL, ANY) Món đắt hơn tất cả món cà phê; món ngoài loại "Món chính" rẻ hơn ít nhất một món chính
-- Prompt gửi AI: "Tìm các món có giá cao hơn mọi món thuộc loại Cà phê. Tìm các món không phải món chính nhưng rẻ hơn ít nhất một món chính."
-- Mã AI sinh / Rà soát / Chỗ đã sửa: nhóm ghi vào nhật ký AI sau khi chạy thật.
SELECT TenMon, GiaBan
FROM Mon
WHERE GiaBan > ALL (SELECT GiaBan FROM Mon WHERE MaLoai = 4);

SELECT TenMon, GiaBan
FROM Mon
WHERE MaLoai <> 8
  AND GiaBan < ANY (SELECT GiaBan FROM Mon WHERE MaLoai = 8);

-- Q14. [NL->SQL #3] (PHÉP CHIA) Khách hàng đã gọi MỌI món thuộc loại "Cà phê"
-- Prompt gửi AI: "Tìm khách hàng đã từng gọi tất cả các món thuộc loại Cà phê (dùng NOT EXISTS hai tầng)."
-- Mã AI sinh / Rà soát / Chỗ đã sửa: nhóm ghi vào nhật ký AI sau khi chạy thật.
SELECT kh.MaKH, kh.HoTen
FROM KhachHang kh
WHERE NOT EXISTS (                              -- không có món cà phê nào...
        SELECT 1 FROM Mon m
        WHERE m.MaLoai = 4
          AND NOT EXISTS (                      -- ...mà khách này chưa từng gọi
                SELECT 1
                FROM HoaDon hd
                JOIN HD_M ct ON ct.MaHD = hd.MaHD
                WHERE hd.MaKH = kh.MaKH AND ct.MaMon = m.MaMon));

/* ---------- NHÓM 5: 2 truy vấn phép toán tập hợp ---------- */

-- Q15. (UNION) Danh bạ chung của nhân viên và khách hàng
SELECT HoTen, SDT, N'Nhân viên' AS Loai FROM NhanVien
UNION
SELECT HoTen, SDT, N'Khách hàng' FROM KhachHang
ORDER BY HoTen;

-- Q16. (EXCEPT, INTERSECT)
-- 16a. Nguyên liệu có trong công thức món nhưng chưa từng được nhập kho
SELECT dl.MaNL FROM DinhLuong dl
EXCEPT
SELECT ct.MaNL FROM ChiTietPhieuNhap ct;

-- 16b. [NL->SQL #4] Khách hàng vừa gọi "Cà phê sữa" vừa gọi "Bánh flan"
-- Prompt gửi AI: "Tìm khách hàng đã từng gọi cả Cà phê sữa lẫn Bánh flan, dùng INTERSECT."
-- Mã AI sinh / Rà soát / Chỗ đã sửa: nhóm ghi vào nhật ký AI sau khi chạy thật.
SELECT hd.MaKH
FROM HoaDon hd JOIN HD_M ct ON ct.MaHD = hd.MaHD JOIN Mon m ON m.MaMon = ct.MaMon
WHERE m.TenMon = N'Cà phê sữa' AND hd.MaKH IS NOT NULL
INTERSECT
SELECT hd.MaKH
FROM HoaDon hd JOIN HD_M ct ON ct.MaHD = hd.MaHD JOIN Mon m ON m.MaMon = ct.MaMon
WHERE m.TenMon = N'Bánh flan' AND hd.MaKH IS NOT NULL;

/* ---------- NHÓM 6: 2 truy vấn CTE (có CTE đệ quy) ---------- */

-- Q17. (CTE + RANK) Top 3 món bán chạy nhất trong từng khung giờ
WITH BanTheoKhung AS (
    SELECT CASE WHEN DATEPART(HOUR, hd.ThoiGianMo) BETWEEN 7  AND 10 THEN N'1-Sáng (7h-10h)'
                WHEN DATEPART(HOUR, hd.ThoiGianMo) BETWEEN 11 AND 13 THEN N'2-Trưa (11h-13h)'
                WHEN DATEPART(HOUR, hd.ThoiGianMo) BETWEEN 14 AND 17 THEN N'3-Chiều (14h-17h)'
                ELSE N'4-Tối (18h-22h)' END AS KhungGio,
           m.TenMon,
           SUM(ct.SoLuong) AS TongSoLuong
    FROM HoaDon hd
    JOIN HD_M ct ON ct.MaHD = hd.MaHD
    JOIN Mon m   ON m.MaMon = ct.MaMon
    WHERE hd.TrangThai = 'DaThanhToan'
    GROUP BY CASE WHEN DATEPART(HOUR, hd.ThoiGianMo) BETWEEN 7  AND 10 THEN N'1-Sáng (7h-10h)'
                  WHEN DATEPART(HOUR, hd.ThoiGianMo) BETWEEN 11 AND 13 THEN N'2-Trưa (11h-13h)'
                  WHEN DATEPART(HOUR, hd.ThoiGianMo) BETWEEN 14 AND 17 THEN N'3-Chiều (14h-17h)'
                  ELSE N'4-Tối (18h-22h)' END,
             m.TenMon
),
XepHang AS (
    SELECT KhungGio, TenMon, TongSoLuong,
           RANK() OVER (PARTITION BY KhungGio ORDER BY TongSoLuong DESC) AS Hang
    FROM BanTheoKhung
)
SELECT KhungGio, Hang, TenMon, TongSoLuong
FROM XepHang
WHERE Hang <= 3
ORDER BY KhungGio, Hang;
-- [NL->SQL #5] Prompt gửi AI: "Món bán chạy nhất theo khung giờ sáng/trưa/chiều/tối, lấy top 3 mỗi khung, dùng CTE và RANK."
-- Mã AI sinh / Rà soát / Chỗ đã sửa: nhóm ghi vào nhật ký AI sau khi chạy thật.

-- Q18. (CTE ĐỆ QUY) Cây loại món: liệt kê đường đi từ loại gốc đến loại con
WITH CayLoaiMon AS (
    SELECT MaLoai, TenLoai, MaLoaiCha, 0 AS Cap, CAST(TenLoai AS NVARCHAR(500)) AS DuongDi
    FROM LoaiMon
    WHERE MaLoaiCha IS NULL                                  -- phần neo: loại gốc
    UNION ALL
    SELECT c.MaLoai, c.TenLoai, c.MaLoaiCha, p.Cap + 1,
           CAST(p.DuongDi + N' > ' + c.TenLoai AS NVARCHAR(500))
    FROM LoaiMon c
    JOIN CayLoaiMon p ON c.MaLoaiCha = p.MaLoai              -- phần đệ quy: loại con
)
SELECT Cap, DuongDi
FROM CayLoaiMon
ORDER BY DuongDi;

/* ---------- NHÓM 7: 2 truy vấn ranking functions ---------- */

-- Q19. (ROW_NUMBER) Hóa đơn gần nhất của mỗi khách hàng
WITH Xep AS (
    SELECT MaKH, MaHD, ThoiGianMo,
           ROW_NUMBER() OVER (PARTITION BY MaKH ORDER BY ThoiGianMo DESC) AS STT
    FROM HoaDon
    WHERE MaKH IS NOT NULL
)
SELECT kh.HoTen, x.MaHD, x.ThoiGianMo
FROM Xep x
JOIN KhachHang kh ON kh.MaKH = x.MaKH
WHERE x.STT = 1
ORDER BY kh.HoTen;

-- Q20. [NL->SQL #6] (RANK, DENSE_RANK, NTILE) Xếp hạng món theo số lượng bán
-- Prompt gửi AI: "Xếp hạng món theo tổng số lượng bán: hạng chung (RANK), hạng trong từng loại (DENSE_RANK) và chia 4 nhóm (NTILE)."
-- Mã AI sinh / Rà soát / Chỗ đã sửa: nhóm ghi vào nhật ký AI sau khi chạy thật.
SELECT lm.TenLoai, m.TenMon, SUM(ct.SoLuong) AS TongSoLuong,
       RANK()       OVER (ORDER BY SUM(ct.SoLuong) DESC)                         AS HangChung,
       DENSE_RANK() OVER (PARTITION BY lm.MaLoai ORDER BY SUM(ct.SoLuong) DESC) AS HangTrongLoai,
       NTILE(4)     OVER (ORDER BY SUM(ct.SoLuong) DESC)                         AS Nhom
FROM HD_M ct
JOIN Mon m      ON m.MaMon = ct.MaMon
JOIN LoaiMon lm ON lm.MaLoai = m.MaLoai
GROUP BY lm.MaLoai, lm.TenLoai, m.MaMon, m.TenMon
ORDER BY HangChung;
GO

SET NOEXEC OFF;
GO

/* =====================================================================
   03_DuLieu.sql  -  DỮ LIỆU MẪU (giả lập hoàn toàn, không dùng dữ liệu cá nhân thật)
   - Bảng danh mục: mỗi bảng >= 10 dòng
   - Bảng giao dịch: HoaDon 1.502 dòng, HD_M ~4.500 dòng (>= 1.000 dòng)
   - Có dòng biên + phần thử cố tình vi phạm ràng buộc + đủ INSERT / UPDATE / DELETE
   LƯU Ý: IDENTITY bắt đầu từ 1 vì CSDL vừa được tạo mới ở file 01.
   Dữ liệu sinh theo công thức (MaHD, MOD...) để chạy lại luôn ra cùng kết quả.
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

/* ---------- 1. Danh mục: ChucVu (10 dòng) ---------- */
INSERT INTO ChucVu (TenCV, LuongCoBan) VALUES
(N'Quản lý',      15000000),
(N'Thu ngân',      8000000),
(N'Phục vụ',       6500000),
(N'Bếp trưởng',   14000000),
(N'Đầu bếp',      10000000),
(N'Pha chế',       8500000),
(N'Phụ bếp',       6000000),
(N'Tạp vụ',        5500000),
(N'Bảo vệ',        6000000),
(N'Kế toán',       9000000);

/* ---------- 2. NhanVien (12 dòng) ---------- */
INSERT INTO NhanVien (MaCV, HoTen, SDT, NgayVaoLam, DangLam) VALUES
(1,  N'Nguyễn Văn An',     '0910000001', '2022-01-10', 1),
(2,  N'Trần Thị Bình',     '0910000002', '2022-03-15', 1),
(2,  N'Lê Hoàng Cường',    '0910000003', '2023-02-01', 1),
(3,  N'Phạm Thu Dung',     '0910000004', '2023-06-20', 1),
(3,  N'Võ Minh Em',        '0910000005', '2024-01-05', 1),
(3,  N'Đặng Quốc Phong',   '0910000006', '2024-05-12', 1),
(4,  N'Bùi Thanh Giang',   '0910000007', '2021-11-01', 1),
(5,  N'Hoàng Văn Hải',     '0910000008', '2022-08-08', 1),
(6,  N'Ngô Thị Lan',       '0910000009', '2023-09-09', 1),
(7,  N'Đỗ Văn Khoa',       '0910000010', '2024-02-02', 1),
(8,  N'Lý Thị Mai',        '0910000011', '2024-07-07', 1),
(10, N'Phan Thị Nga',      '0910000012', '2022-12-12', 1);

/* ---------- 3. KhachHang (20 dòng; có dòng biên DiemTichLuy = 0) ---------- */
INSERT INTO KhachHang (HoTen, SDT, DiemTichLuy, NgayDangKy) VALUES
(N'Nguyễn Thị Hoa',    '0900000001',   0, '2024-01-15'),
(N'Trần Văn Bảo',      '0900000002', 120, '2024-02-20'),
(N'Lê Thị Cúc',        '0900000003', 250, '2024-03-10'),
(N'Phạm Văn Đạt',      '0900000004', 530, '2024-03-28'),
(N'Hoàng Thị Em',      '0900000005',   0, '2024-04-05'),
(N'Vũ Văn Phúc',       '0900000006',  80, '2024-05-18'),
(N'Đặng Thị Giang',    '0900000007', 310, '2024-06-01'),
(N'Bùi Văn Hùng',      '0900000008', 640, '2024-06-22'),
(N'Đỗ Thị Hương',      '0900000009',   0, '2024-07-14'),
(N'Ngô Văn Khánh',     '0900000010', 190, '2024-08-03'),
(N'Dương Thị Linh',    '0900000011', 450, '2024-08-30'),
(N'Lý Văn Minh',       '0900000012',  60, '2024-09-12'),
(N'Phan Thị Ngọc',     '0900000013',   0, '2024-10-01'),
(N'Trương Văn Phát',   '0900000014', 220, '2024-10-25'),
(N'Huỳnh Thị Quyên',   '0900000015', 700, '2024-11-11'),
(N'Mai Văn Sơn',       '0900000016', 140, '2024-12-02'),
(N'Cao Thị Trang',     '0900000017',   0, '2025-01-09'),
(N'Tô Văn Uy',         '0900000018', 360, '2025-02-14'),
(N'Lâm Thị Vân',       '0900000019',  95, '2025-03-03'),
(N'Châu Văn Xuân',     '0900000020', 510, '2025-04-18');

/* ---------- 4. Ban (12 dòng; có dòng biên SoGhe = 1) ---------- */
INSERT INTO Ban (TenBan, SoGhe, KhuVuc, TrangThai) VALUES
(N'Bàn 01', 2, N'Tầng 1',    'Trong'),
(N'Bàn 02', 2, N'Tầng 1',    'Trong'),
(N'Bàn 03', 4, N'Tầng 1',    'Trong'),
(N'Bàn 04', 4, N'Tầng 1',    'Trong'),
(N'Bàn 05', 4, N'Tầng 2',    'Trong'),
(N'Bàn 06', 6, N'Tầng 2',    'Trong'),
(N'Bàn 07', 6, N'Tầng 2',    'Trong'),
(N'Bàn 08', 8, N'Tầng 2',    'Trong'),
(N'Bàn 09', 4, N'Sân vườn',  'Trong'),
(N'Bàn 10', 4, N'Sân vườn',  'Trong'),
(N'Bàn 11', 6, N'Sân vườn',  'Trong'),
(N'Quầy bar', 1, N'Tầng 1',  'Trong');

/* ---------- 5. LoaiMon (13 dòng; có cấu trúc cây cha - con) ---------- */
INSERT INTO LoaiMon (TenLoai, MaLoaiCha) VALUES
(N'Đồ uống',           NULL),   -- 1
(N'Đồ ăn',             NULL),   -- 2
(N'Tráng miệng',       NULL),   -- 3
(N'Cà phê',               1),   -- 4
(N'Trà',                  1),   -- 5
(N'Nước ép & sinh tố',    1),   -- 6
(N'Đá xay',               1),   -- 7
(N'Món chính',            2),   -- 8
(N'Món ăn vặt',           2),   -- 9
(N'Bánh ngọt',            3),   -- 10
(N'Kem',                  3),   -- 11
(N'Khai vị',              2),   -- 12
(N'Nước đóng chai',       1);   -- 13

/* ---------- 6. Mon (25 dòng): 1-12 và 25 là thức uống (TU), 13-24 là đồ ăn (DA) ---------- */
INSERT INTO Mon (MaLoai, TenMon, GiaBan, PhanLoai, DangBan) VALUES
(4,  N'Cà phê đen đá',       25000, 'TU', 1),   -- 1
(4,  N'Cà phê sữa',          29000, 'TU', 1),   -- 2
(4,  N'Bạc xỉu',             32000, 'TU', 1),   -- 3
(5,  N'Trà đào cam sả',      45000, 'TU', 1),   -- 4
(5,  N'Trà vải',             42000, 'TU', 1),   -- 5
(5,  N'Trà sữa trân châu',   45000, 'TU', 1),   -- 6
(6,  N'Nước cam ép',         40000, 'TU', 1),   -- 7
(6,  N'Sinh tố bơ',          50000, 'TU', 1),   -- 8
(6,  N'Sinh tố xoài',        48000, 'TU', 1),   -- 9
(7,  N'Cà phê đá xay',       55000, 'TU', 1),   -- 10
(7,  N'Matcha đá xay',       58000, 'TU', 1),   -- 11
(5,  N'Trà gừng nóng',       35000, 'TU', 1),   -- 12
(8,  N'Mì Ý sốt bò bằm',     75000, 'DA', 1),   -- 13
(8,  N'Cơm gà chiên',        65000, 'DA', 1),   -- 14
(8,  N'Cơm chay thập cẩm',   55000, 'DA', 1),   -- 15
(8,  N'Bánh mì ốp la',       35000, 'DA', 1),   -- 16
(9,  N'Khoai tây chiên',     40000, 'DA', 1),   -- 17
(9,  N'Gà viên chiên',       45000, 'DA', 1),   -- 18
(12, N'Salad rau trộn',      38000, 'DA', 1),   -- 19
(12, N'Súp bí đỏ',           35000, 'DA', 1),   -- 20
(10, N'Bánh tiramisu',       55000, 'DA', 1),   -- 21
(10, N'Bánh flan',           25000, 'DA', 1),   -- 22
(11, N'Kem vani',            30000, 'DA', 1),   -- 23
(11, N'Kem socola',          30000, 'DA', 0),   -- 24 (tạm ngưng bán: dòng biên DangBan = 0)
(13, N'Nước suối',           10000, 'TU', 1);   -- 25 (giá thấp nhất, không có định lượng nguyên liệu)

INSERT INTO MonThucUong (MaMon, DungTichMl, NhietDo) VALUES
(1, 300, 'Da'), (2, 300, 'Da'), (3, 350, 'Da'), (4, 500, 'Lanh'), (5, 500, 'Lanh'),
(6, 500, 'Lanh'), (7, 400, 'Lanh'), (8, 450, 'Lanh'), (9, 450, 'Lanh'), (10, 500, 'Da'),
(11, 500, 'Da'), (12, 250, 'Nong'), (25, 500, 'Lanh');

INSERT INTO MonDoAn (MaMon, ThoiGianCheBien, LaMonChay) VALUES
(13, 15, 0), (14, 15, 0), (15, 12, 1), (16, 8, 0), (17, 10, 1), (18, 12, 0),
(19, 5, 1), (20, 10, 1), (21, 3, 0), (22, 3, 0), (23, 2, 1), (24, 2, 1);

/* ---------- 7. NguyenLieu (26 dòng) ----------
   Dòng biên: Bánh mì ổ có TonKho = 0; Kem tươi, Phô mai, Gừng dưới định mức tồn */
INSERT INTO NguyenLieu (TenNL, DonViTinh, TonKho, DinhMucTon, DonGiaVon, GhiChu) VALUES
(N'Cà phê hạt',          N'kg',   40,   10, 180000, NULL),                          -- 1
(N'Sữa đặc',             N'lon', 120,   30,  25000, NULL),                          -- 2
(N'Sữa tươi',            N'lít',  60,   20,  32000, N'Bảo quản lạnh'),              -- 3
(N'Đường',               N'kg',   50,   15,  22000, NULL),                          -- 4
(N'Trà đen',             N'kg',   20,    5, 150000, NULL),                          -- 5
(N'Trà xanh',            N'kg',   15,    5, 160000, NULL),                          -- 6
(N'Đào ngâm',            N'hộp',  40,   10,  60000, NULL),                          -- 7
(N'Cam tươi',            N'kg',   30,   10,  35000, N'Dùng trong ngày'),            -- 8
(N'Sả cây',              N'kg',    8,    3,  20000, NULL),                          -- 9
(N'Vải ngâm',            N'hộp',  35,   10,  55000, NULL),                          -- 10
(N'Trân châu',           N'kg',   25,    8,  70000, NULL),                          -- 11
(N'Bơ',                  N'kg',   18,    6,  90000, NULL),                          -- 12
(N'Xoài',                N'kg',   22,    8,  45000, NULL),                          -- 13
(N'Bột matcha',          N'kg',    4,    2, 600000, NULL),                          -- 14
(N'Gừng',                N'kg',  1.5,    2,  40000, N'Dưới định mức'),              -- 15
(N'Thịt bò bằm',         N'kg',   30,   10, 250000, N'Bảo quản đông'),              -- 16
(N'Mì Ý',                N'kg',   25,    8,  55000, NULL),                          -- 17
(N'Gạo',                 N'kg',   80,   25,  20000, NULL),                          -- 18
(N'Thịt gà',             N'kg',   35,   12,  90000, N'Bảo quản đông'),              -- 19
(N'Khoai tây',           N'kg',   40,   15,  30000, NULL),                          -- 20
(N'Trứng gà',            N'quả', 300,  100,   3500, NULL),                          -- 21
(N'Rau xà lách',         N'kg',   12,    5,  40000, N'Dùng trong ngày'),            -- 22
(N'Bí đỏ',               N'kg',   16,    6,  25000, NULL),                          -- 23
(N'Kem tươi',            N'lít',   3,    5, 120000, N'Dưới định mức'),              -- 24
(N'Bánh mì ổ',           N'ổ',     0,   30,   5000, N'Hết hàng (tồn = 0)'),         -- 25
(N'Phô mai mascarpone',  N'kg',  1.5,    2, 400000, N'Dưới định mức');              -- 26

/* ---------- 8. NhaCungCap (10 dòng) ---------- */
INSERT INTO NhaCungCap (TenNCC, SDT, DiaChi) VALUES
(N'Công ty Cà phê Cao Nguyên',    '0281000001', N'12 Lê Lợi, Buôn Ma Thuột'),
(N'Cơ sở Sữa Đồng Xanh',          '0281000002', N'45 Nguyễn Huệ, Đồng Nai'),
(N'Đại lý Đường Biên Hòa',        '0281000003', N'78 Phạm Văn Thuận, Biên Hòa'),
(N'Trà Bảo Lộc Xanh',             '0281000004', N'9 Trần Phú, Bảo Lộc'),
(N'Nông sản Rau Sạch Đà Lạt',     '0281000005', N'21 Hùng Vương, Đà Lạt'),
(N'Vựa Trái Cây Miền Tây',        '0281000006', N'33 Trần Hưng Đạo, Cần Thơ'),
(N'Thực phẩm Đông Lạnh An Phát',  '0281000007', N'5 Võ Thị Sáu, Biên Hòa'),
(N'Gạo & Mì Hưng Thịnh',          '0281000008', N'60 Quốc Lộ 1A, Đồng Nai'),
(N'Trứng Gà Sạch Long Thành',     '0281000009', N'14 Lê Duẩn, Long Thành'),
(N'Bánh Kem Ngọt Ngào',           '0281000010', N'27 Cách Mạng Tháng 8, Biên Hòa');

/* ---------- 9. DinhLuong (62 dòng): nguyên liệu cho 1 phần món ---------- */
INSERT INTO DinhLuong (MaMon, MaNL, SoLuong) VALUES
(1,1,0.020),(1,4,0.010),
(2,1,0.020),(2,2,0.030),
(3,1,0.010),(3,2,0.020),(3,3,0.100),
(4,5,0.010),(4,7,0.100),(4,8,0.100),(4,9,0.020),(4,4,0.020),
(5,5,0.010),(5,10,0.100),(5,4,0.020),
(6,5,0.010),(6,3,0.150),(6,11,0.050),(6,4,0.020),
(7,8,0.300),(7,4,0.010),
(8,12,0.150),(8,2,0.030),(8,3,0.100),
(9,13,0.200),(9,2,0.020),(9,3,0.100),
(10,1,0.020),(10,3,0.100),(10,4,0.020),(10,24,0.030),
(11,14,0.015),(11,3,0.150),(11,4,0.020),(11,24,0.030),
(12,6,0.010),(12,15,0.020),(12,4,0.020),
(13,17,0.120),(13,16,0.100),
(14,18,0.150),(14,19,0.200),(14,21,1.000),
(15,18,0.150),(15,23,0.100),(15,22,0.050),
(16,25,1.000),(16,21,2.000),
(17,20,0.250),
(18,19,0.200),
(19,22,0.150),(19,21,1.000),
(20,23,0.200),(20,3,0.100),
(21,26,0.080),(21,21,1.000),(21,1,0.010),
(22,21,2.000),(22,2,0.030),
(23,24,0.100),
(24,24,0.100),(24,4,0.010);

/* ---------- 10. PhieuNhap (40 dòng) và ChiTietPhieuNhap (120 dòng) ----------
   Nguyên liệu 24, 25, 26 cố ý chưa từng được nhập (phục vụ truy vấn NOT EXISTS / EXCEPT ở file 04) */
;WITH So AS (
    SELECT TOP (40) CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO PhieuNhap (MaNV, MaNCC, NgayNhap, GhiChu)
SELECT 1 + (n % 2) * 11,                                   -- nhân viên 1 hoặc 12
       1 + (n % 10),
       DATEADD(DAY, (n * 13) % 540, CAST('2025-01-01' AS DATETIME2(0))),
       CONCAT(N'Phiếu nhập mẫu số ', n)
FROM So;

INSERT INTO ChiTietPhieuNhap (MaPN, MaNL, SoLuong, DonGiaNhap)
SELECT p.MaPN, nl.MaNL, 5 + (p.MaPN + x.so) % 20, nl.DonGiaVon
FROM PhieuNhap p
CROSS JOIN (VALUES (1), (2), (3)) AS x(so)
JOIN NguyenLieu nl ON nl.MaNL = 1 + (p.MaPN * 5 + x.so * 7) % 23;   -- 3 nguyên liệu khác nhau trong mỗi phiếu

/* ---------- 11. HoaDon: 1.500 hóa đơn lịch sử (01/2025 - 06/2026) ----------
   n = số thứ tự 1..1500. Cứ n chia hết cho 4 là khách vãng lai (MaKH NULL);
   cứ n chia hết cho 50 là hóa đơn bị hủy. */
;WITH So AS (
    SELECT TOP (1500) CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO HoaDon (MaKH, MaNV, MaBan, ThoiGianMo, ThoiGianDong, TrangThai, PhuongThucTT, GiamGiaPhanTram)
SELECT CASE WHEN n % 4 = 0 THEN NULL ELSE 1 + (n % 20) END,
       2 + (n % 5),                                         -- nhân viên 2..6 (thu ngân, phục vụ)
       1 + (n % 12),
       t.Mo,
       DATEADD(MINUTE, 20 + (n % 70), t.Mo),
       CASE WHEN n % 50 = 0 THEN 'Huy' ELSE 'DaThanhToan' END,
       CASE WHEN n % 50 = 0 THEN NULL
            WHEN n % 3 = 0 THEN 'TienMat'
            WHEN n % 3 = 1 THEN 'The'
            ELSE 'ChuyenKhoan' END,
       CASE WHEN n % 4 = 0 THEN 0 WHEN n % 10 = 0 THEN 10 WHEN n % 7 = 0 THEN 5 ELSE 0 END
FROM So
CROSS APPLY (SELECT DATEADD(MINUTE, 420 + (n * 53) % 960,                      -- giờ mở từ 07:00 đến 22:59
                    CAST(DATEADD(DAY, n % 540, '2025-01-01') AS DATETIME2(0)))) AS t(Mo);

/* Dòng biên của HoaDon */
INSERT INTO HoaDon (MaKH, MaNV, MaBan, ThoiGianMo, ThoiGianDong, TrangThai, PhuongThucTT, GiamGiaPhanTram) VALUES
(15, 2, 1, '2026-06-24 23:59:00', '2026-06-24 23:59:00', 'DaThanhToan', 'TienMat', 100),  -- giảm 100%, giờ đóng = giờ mở
(NULL, 3, 12, '2026-06-25 08:00:00', '2026-06-25 08:30:00', 'DaThanhToan', 'The', 0);      -- khách vãng lai, giảm 0%

/* ---------- 12. HD_M: mỗi hóa đơn có 3 món khác nhau (~4.500 dòng) ---------- */
INSERT INTO HD_M (MaHD, MaMon, SoLuong, DonGia)
SELECT h.MaHD, m.MaMon, 1 + (h.MaHD + x.so) % 4, m.GiaBan
FROM HoaDon h
CROSS JOIN (VALUES (1), (2), (3)) AS x(so)
JOIN Mon m ON m.MaMon = 1 + (h.MaHD * 7 + x.so * 5) % 24     -- chọn món 1..24, 3 món không trùng nhau
WHERE h.MaHD <= 1500;

/* Dòng biên của HD_M: số lượng lớn nhất (20), món giá thấp nhất (nước suối) */
INSERT INTO HD_M (MaHD, MaMon, SoLuong, DonGia) VALUES
(1501, 2,  20, 29000),
(1501, 25,  1, 10000),
(1502, 1,   1, 25000);

/* ---------- 13. Kiểm tra số dòng ---------- */
SELECT 'ChucVu' AS Bang, COUNT(*) AS SoDong FROM ChucVu UNION ALL
SELECT 'NhanVien', COUNT(*) FROM NhanVien UNION ALL
SELECT 'KhachHang', COUNT(*) FROM KhachHang UNION ALL
SELECT 'Ban', COUNT(*) FROM Ban UNION ALL
SELECT 'LoaiMon', COUNT(*) FROM LoaiMon UNION ALL
SELECT 'Mon', COUNT(*) FROM Mon UNION ALL
SELECT 'NguyenLieu', COUNT(*) FROM NguyenLieu UNION ALL
SELECT 'NhaCungCap', COUNT(*) FROM NhaCungCap UNION ALL
SELECT 'DinhLuong', COUNT(*) FROM DinhLuong UNION ALL
SELECT 'PhieuNhap', COUNT(*) FROM PhieuNhap UNION ALL
SELECT 'ChiTietPhieuNhap', COUNT(*) FROM ChiTietPhieuNhap UNION ALL
SELECT 'HoaDon', COUNT(*) FROM HoaDon UNION ALL
SELECT 'HD_M', COUNT(*) FROM HD_M;
GO

/* =====================================================================
   UPDATE và DELETE (rubric yêu cầu đủ INSERT, UPDATE, DELETE)
   ===================================================================== */
-- UPDATE 1: nhân viên Đặng Quốc Phong nghỉ việc
UPDATE NhanVien SET DangLam = 0 WHERE MaNV = 6;

-- UPDATE 2: cộng 50 điểm cho khách hàng số 3
UPDATE KhachHang SET DiemTichLuy = DiemTichLuy + 50 WHERE MaKH = 3;

-- UPDATE 3: tăng giá cà phê 2.000 đồng (chỉ ảnh hưởng hóa đơn mới, vì HD_M đã lưu DonGia riêng)
UPDATE Mon SET GiaBan = GiaBan + 2000 WHERE MaLoai = 4;

-- INSERT + UPDATE + DELETE trên một dòng thử nghiệm
INSERT INTO NhaCungCap (TenNCC, SDT, DiaChi) VALUES (N'NCC thử nghiệm', '0281999999', N'Địa chỉ thử');
UPDATE NhaCungCap SET SDT = '0281888888' WHERE TenNCC = N'NCC thử nghiệm';
DELETE FROM NhaCungCap WHERE TenNCC = N'NCC thử nghiệm';

-- DELETE: xóa khách hàng thử (chưa có hóa đơn nên không vướng khóa ngoại)
INSERT INTO KhachHang (HoTen, SDT) VALUES (N'Khách thử xóa', '0900999999');
DELETE FROM KhachHang WHERE SDT = '0900999999';
GO

/* =====================================================================
   BỘ LỆNH CỐ TÌNH VI PHẠM RÀNG BUỘC: câu lệnh nào cũng phải bị từ chối
   (ở file 02 chưa có trigger nên đây là các lỗi do PK / FK / CHECK / UNIQUE / NOT NULL)
   ===================================================================== */
-- Thử 1: trùng UNIQUE (tên chức vụ)
BEGIN TRY
    INSERT INTO ChucVu (TenCV, LuongCoBan) VALUES (N'Quản lý', 1000000);
    PRINT N'LỖI: câu lệnh vi phạm nhưng vẫn chạy được!';
END TRY
BEGIN CATCH
    PRINT N'Thử 1 (UNIQUE)   - bị từ chối: ' + ERROR_MESSAGE();
END CATCH
GO
-- Thử 2: vi phạm CHECK (giá bán âm)
BEGIN TRY
    INSERT INTO Mon (MaLoai, TenMon, GiaBan, PhanLoai) VALUES (4, N'Món lỗi', -5000, 'TU');
    PRINT N'LỖI: câu lệnh vi phạm nhưng vẫn chạy được!';
END TRY
BEGIN CATCH
    PRINT N'Thử 2 (CHECK)    - bị từ chối: ' + ERROR_MESSAGE();
END CATCH
GO
-- Thử 3: vi phạm FOREIGN KEY (chức vụ không tồn tại)
BEGIN TRY
    INSERT INTO NhanVien (MaCV, HoTen, SDT) VALUES (999, N'Nhân viên lỗi', '0919999999');
    PRINT N'LỖI: câu lệnh vi phạm nhưng vẫn chạy được!';
END TRY
BEGIN CATCH
    PRINT N'Thử 3 (FK)       - bị từ chối: ' + ERROR_MESSAGE();
END CATCH
GO
-- Thử 4: vi phạm CHECK (giảm giá 150%)
BEGIN TRY
    INSERT INTO HoaDon (MaNV, MaBan, GiamGiaPhanTram) VALUES (2, 1, 150);
    PRINT N'LỖI: câu lệnh vi phạm nhưng vẫn chạy được!';
END TRY
BEGIN CATCH
    PRINT N'Thử 4 (CHECK)    - bị từ chối: ' + ERROR_MESSAGE();
END CATCH
GO
-- Thử 5: vi phạm CHECK thêm bằng ALTER TABLE (giờ đóng trước giờ mở)
BEGIN TRY
    INSERT INTO HoaDon (MaNV, MaBan, ThoiGianMo, ThoiGianDong, TrangThai)
    VALUES (2, 1, '2026-01-01 10:00:00', '2026-01-01 09:00:00', 'DaThanhToan');
    PRINT N'LỖI: câu lệnh vi phạm nhưng vẫn chạy được!';
END TRY
BEGIN CATCH
    PRINT N'Thử 5 (CHECK)    - bị từ chối: ' + ERROR_MESSAGE();
END CATCH
GO
-- Thử 6: vi phạm CHECK (trạng thái bàn không hợp lệ)
BEGIN TRY
    UPDATE Ban SET TrangThai = 'Hong' WHERE MaBan = 1;
    PRINT N'LỖI: câu lệnh vi phạm nhưng vẫn chạy được!';
END TRY
BEGIN CATCH
    PRINT N'Thử 6 (CHECK)    - bị từ chối: ' + ERROR_MESSAGE();
END CATCH
GO
-- Thử 7: trùng khóa chính ghép (món đã có trong hóa đơn)
BEGIN TRY
    INSERT INTO HD_M (MaHD, MaMon, SoLuong, DonGia) VALUES (1501, 2, 1, 29000);
    PRINT N'LỖI: câu lệnh vi phạm nhưng vẫn chạy được!';
END TRY
BEGIN CATCH
    PRINT N'Thử 7 (PK)       - bị từ chối: ' + ERROR_MESSAGE();
END CATCH
GO
-- Thử 8: NOT NULL (khách hàng thiếu họ tên)
BEGIN TRY
    INSERT INTO KhachHang (HoTen, SDT) VALUES (NULL, '0900888888');
    PRINT N'LỖI: câu lệnh vi phạm nhưng vẫn chạy được!';
END TRY
BEGIN CATCH
    PRINT N'Thử 8 (NOT NULL) - bị từ chối: ' + ERROR_MESSAGE();
END CATCH
GO
-- Thử 9: xóa dòng cha đang được dòng con tham chiếu (FK)
BEGIN TRY
    DELETE FROM Mon WHERE MaMon = 1;
    PRINT N'LỖI: câu lệnh vi phạm nhưng vẫn chạy được!';
END TRY
BEGIN CATCH
    PRINT N'Thử 9 (FK xóa)   - bị từ chối: ' + ERROR_MESSAGE();
END CATCH
GO

SET NOEXEC OFF;
GO

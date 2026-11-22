/* #####################################################################
   script.sql - ĐỀ TÀI 13: QUẢN LÝ NHÀ HÀNG / QUÁN CÀ PHÊ (SQL Server)
   Gộp 8 file theo đúng thứ tự chạy:
   01_CSDL -> 02_Bang -> 03_DuLieu -> 04_TruyVan_View -> 05_ThuTuc_Ham
   -> 06_Trigger_GiaoTac -> 07_PhanQuyen_SaoLuu -> 08_ToiUu
   Chạy toàn bộ trong SSMS bằng tài khoản sysadmin (hoặc chạy lần lượt từng file trong thư mục sql/).
   Nếu 01 lỗi, các phần sau tự bỏ qua (chốt chặn NOEXEC) để không tạo nhầm đối tượng.
   Điểm cộng nằm ở file 07, phần F (che dữ liệu động).
   ##################################################################### */

/* ================= BẮT ĐẦU FILE 01_CSDL.sql ================= */
GO
/* =====================================================================
   01_CSDL.sql  -  TẠO CƠ SỞ DỮ LIỆU
   Đề tài 13: Quản lý nhà hàng / quán cà phê  (SQL Server)
   Thứ tự chạy: 01 -> 02 -> 03 -> 04 -> 05 -> 06 -> 07 -> 08
   Yêu cầu rubric: tạo CSDL có cấu hình file dữ liệu (mdf) và file log (ldf) rõ ràng.
   Ghi chú: file được đặt vào thư mục mặc định của SQL Server nên chạy được trên máy mới.
   ===================================================================== */
USE master;
GO

-- Xóa CSDL cũ (nếu có) để script chạy lại được từ đầu
IF DB_ID(N'QuanLyNhaHang') IS NOT NULL
BEGIN
    ALTER DATABASE QuanLyNhaHang SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE QuanLyNhaHang;
END
GO

-- Lấy thư mục data/log mặc định của máy đang chạy rồi tạo CSDL
DECLARE @DuongDanData NVARCHAR(260) = CONVERT(NVARCHAR(260), SERVERPROPERTY('InstanceDefaultDataPath'));
DECLARE @DuongDanLog  NVARCHAR(260) = CONVERT(NVARCHAR(260), SERVERPROPERTY('InstanceDefaultLogPath'));

DECLARE @Sql NVARCHAR(MAX) = N'
CREATE DATABASE QuanLyNhaHang
ON PRIMARY
(   NAME       = N''QuanLyNhaHang_Data'',      -- tên logic (dùng khi RESTORE ở file 07)
    FILENAME   = N''' + @DuongDanData + N'QuanLyNhaHang.mdf'',
    SIZE       = 50MB,                         -- dung lượng ban đầu
    MAXSIZE    = 1GB,                          -- giới hạn tối đa
    FILEGROWTH = 10MB )                        -- mỗi lần tự tăng
LOG ON
(   NAME       = N''QuanLyNhaHang_Log'',
    FILENAME   = N''' + @DuongDanLog + N'QuanLyNhaHang.ldf'',
    SIZE       = 20MB,
    MAXSIZE    = 500MB,
    FILEGROWTH = 10MB )
COLLATE Vietnamese_CI_AS;                      -- sắp xếp đúng tiếng Việt (COLLATE phải đứng SAU phần LOG ON)';
EXEC (@Sql);
GO

-- Chốt chặn: nếu tạo CSDL thất bại thì bỏ qua toàn bộ phần còn lại (tránh tạo nhầm bảng vào master)
IF DB_ID(N'QuanLyNhaHang') IS NULL
BEGIN
    RAISERROR(N'Tạo CSDL QuanLyNhaHang THẤT BẠI - dừng script. Đọc thông báo lỗi phía trên.', 16, 1);
    SET NOEXEC ON;
END
GO

-- Dùng mô hình phục hồi FULL để sao lưu được Full / Differential / Log (file 07)
ALTER DATABASE QuanLyNhaHang SET RECOVERY FULL;
GO

-- Kiểm tra cấu hình file vừa tạo
SELECT name                  AS TenFileLogic,
       type_desc             AS Loai,
       physical_name         AS DuongDan,
       size * 8 / 1024       AS KichThuocMB,
       max_size * 8 / 1024   AS ToiDaMB,
       growth * 8 / 1024     AS TangMoiLanMB
FROM sys.master_files
WHERE database_id = DB_ID(N'QuanLyNhaHang');
GO

SET NOEXEC OFF;
GO
GO

/* ================= BẮT ĐẦU FILE 02_Bang.sql ================= */
GO
/* =====================================================================
   02_Bang.sql  -  TẠO BẢNG VÀ RÀNG BUỘC (khớp mô hình CDM/PDM)
   Có đủ: PRIMARY KEY, FOREIGN KEY, CHECK, UNIQUE, DEFAULT và ALTER TABLE.
   Thứ tự tạo: bảng cha trước, bảng con sau.
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

/* ---------- Nhóm nhân sự ---------- */
CREATE TABLE ChucVu (
    MaCV        INT IDENTITY(1,1) CONSTRAINT PK_ChucVu PRIMARY KEY,
    TenCV       NVARCHAR(50)  NOT NULL CONSTRAINT UQ_ChucVu_TenCV UNIQUE,
    LuongCoBan  DECIMAL(12,0) NOT NULL CONSTRAINT DF_ChucVu_Luong DEFAULT 0
                CONSTRAINT CK_ChucVu_Luong CHECK (LuongCoBan >= 0)
);

CREATE TABLE NhanVien (
    MaNV        INT IDENTITY(1,1) CONSTRAINT PK_NhanVien PRIMARY KEY,
    MaCV        INT           NOT NULL CONSTRAINT FK_NhanVien_ChucVu REFERENCES ChucVu(MaCV),
    HoTen       NVARCHAR(100) NOT NULL,
    SDT         VARCHAR(15)   NOT NULL,
    NgayVaoLam  DATE          NOT NULL CONSTRAINT DF_NhanVien_NgayVaoLam DEFAULT (GETDATE()),
    DangLam     BIT           NOT NULL CONSTRAINT DF_NhanVien_DangLam DEFAULT 1
);

/* ---------- Nhóm bán hàng ---------- */
CREATE TABLE KhachHang (
    MaKH         INT IDENTITY(1,1) CONSTRAINT PK_KhachHang PRIMARY KEY,
    HoTen        NVARCHAR(100) NOT NULL,
    SDT          VARCHAR(15)   NOT NULL,
    DiemTichLuy  INT           NOT NULL CONSTRAINT DF_KhachHang_Diem DEFAULT 0
                 CONSTRAINT CK_KhachHang_Diem CHECK (DiemTichLuy >= 0),
    NgayDangKy   DATE          NOT NULL CONSTRAINT DF_KhachHang_NgayDK DEFAULT (GETDATE())
);

CREATE TABLE Ban (
    MaBan      INT IDENTITY(1,1) CONSTRAINT PK_Ban PRIMARY KEY,
    TenBan     NVARCHAR(20) NOT NULL CONSTRAINT UQ_Ban_TenBan UNIQUE,
    SoGhe      INT          NOT NULL CONSTRAINT CK_Ban_SoGhe CHECK (SoGhe > 0),
    KhuVuc     NVARCHAR(30) NOT NULL,
    TrangThai  VARCHAR(15)  NOT NULL CONSTRAINT DF_Ban_TrangThai DEFAULT 'Trong'
               CONSTRAINT CK_Ban_TrangThai CHECK (TrangThai IN ('Trong', 'CoKhach'))
);

/* ---------- Nhóm thực đơn ---------- */
CREATE TABLE LoaiMon (
    MaLoai     INT IDENTITY(1,1) CONSTRAINT PK_LoaiMon PRIMARY KEY,
    TenLoai    NVARCHAR(50) NOT NULL,
    MaLoaiCha  INT NULL            -- quan hệ đệ quy: loại cha (khóa ngoại thêm bằng ALTER TABLE bên dưới)
);

CREATE TABLE Mon (
    MaMon     INT IDENTITY(1,1) CONSTRAINT PK_Mon PRIMARY KEY,
    MaLoai    INT           NOT NULL CONSTRAINT FK_Mon_LoaiMon REFERENCES LoaiMon(MaLoai),
    TenMon    NVARCHAR(100) NOT NULL,
    GiaBan    DECIMAL(12,0) NOT NULL CONSTRAINT CK_Mon_GiaBan CHECK (GiaBan > 0),
    PhanLoai  CHAR(2)       NOT NULL CONSTRAINT CK_Mon_PhanLoai CHECK (PhanLoai IN ('DA', 'TU')),  -- DA = đồ ăn, TU = thức uống
    DangBan   BIT           NOT NULL CONSTRAINT DF_Mon_DangBan DEFAULT 1
);

-- Chuyên biệt hóa: mỗi bảng con dùng chính MaMon của bảng Mon làm khóa chính
CREATE TABLE MonDoAn (
    MaMon            INT NOT NULL CONSTRAINT PK_MonDoAn PRIMARY KEY
                     CONSTRAINT FK_MonDoAn_Mon REFERENCES Mon(MaMon),
    ThoiGianCheBien  INT NOT NULL CONSTRAINT CK_MonDoAn_ThoiGian CHECK (ThoiGianCheBien > 0),  -- phút
    LaMonChay        BIT NOT NULL CONSTRAINT DF_MonDoAn_Chay DEFAULT 0
);

CREATE TABLE MonThucUong (
    MaMon      INT NOT NULL CONSTRAINT PK_MonThucUong PRIMARY KEY
               CONSTRAINT FK_MonThucUong_Mon REFERENCES Mon(MaMon),
    DungTichMl INT NOT NULL CONSTRAINT CK_MonThucUong_DungTich CHECK (DungTichMl > 0),
    NhietDo    VARCHAR(5) NOT NULL CONSTRAINT CK_MonThucUong_NhietDo CHECK (NhietDo IN ('Nong', 'Lanh', 'Da'))
);

/* ---------- Nhóm kho và nhập hàng ---------- */
CREATE TABLE NguyenLieu (
    MaNL        INT IDENTITY(1,1) CONSTRAINT PK_NguyenLieu PRIMARY KEY,
    TenNL       NVARCHAR(100) NOT NULL CONSTRAINT UQ_NguyenLieu_TenNL UNIQUE,
    DonViTinh   NVARCHAR(20)  NOT NULL,
    -- Cố ý KHÔNG đặt CHECK (TonKho >= 0) vì quy tắc "chặn tồn kho âm" do trigger ở file 06 đảm nhiệm
    TonKho      DECIMAL(12,3) NOT NULL CONSTRAINT DF_NguyenLieu_TonKho DEFAULT 0,
    DinhMucTon  DECIMAL(12,3) NOT NULL CONSTRAINT DF_NguyenLieu_DinhMuc DEFAULT 0
                CONSTRAINT CK_NguyenLieu_DinhMuc CHECK (DinhMucTon >= 0),
    DonGiaVon   DECIMAL(12,0) NOT NULL CONSTRAINT DF_NguyenLieu_DonGiaVon DEFAULT 0
                CONSTRAINT CK_NguyenLieu_DonGiaVon CHECK (DonGiaVon >= 0),
    GhiChu      NVARCHAR(200) NULL
);

CREATE TABLE NhaCungCap (
    MaNCC   INT IDENTITY(1,1) CONSTRAINT PK_NhaCungCap PRIMARY KEY,
    TenNCC  NVARCHAR(100) NOT NULL,
    SDT     VARCHAR(15)   NOT NULL,
    DiaChi  NVARCHAR(200) NOT NULL
);

/* ---------- Hóa đơn và phiếu nhập ---------- */
CREATE TABLE HoaDon (
    MaHD             INT IDENTITY(1,1) CONSTRAINT PK_HoaDon PRIMARY KEY,
    MaKH             INT NULL CONSTRAINT FK_HoaDon_KhachHang REFERENCES KhachHang(MaKH),   -- NULL = khách vãng lai
    MaNV             INT NOT NULL CONSTRAINT FK_HoaDon_NhanVien REFERENCES NhanVien(MaNV),
    MaBan            INT NOT NULL CONSTRAINT FK_HoaDon_Ban REFERENCES Ban(MaBan),
    ThoiGianMo       DATETIME2(0) NOT NULL CONSTRAINT DF_HoaDon_ThoiGianMo DEFAULT (SYSDATETIME()),
    ThoiGianDong     DATETIME2(0) NULL,
    TrangThai        VARCHAR(15)  NOT NULL CONSTRAINT DF_HoaDon_TrangThai DEFAULT 'DangMo'
                     CONSTRAINT CK_HoaDon_TrangThai CHECK (TrangThai IN ('DangMo', 'DaThanhToan', 'Huy')),
    PhuongThucTT     VARCHAR(15)  NULL
                     CONSTRAINT CK_HoaDon_PhuongThucTT CHECK (PhuongThucTT IN ('TienMat', 'The', 'ChuyenKhoan')),
    GiamGiaPhanTram  DECIMAL(5,2) NOT NULL CONSTRAINT DF_HoaDon_GiamGia DEFAULT 0
                     CONSTRAINT CK_HoaDon_GiamGia CHECK (GiamGiaPhanTram BETWEEN 0 AND 100)
);

CREATE TABLE PhieuNhap (
    MaPN     INT IDENTITY(1,1) CONSTRAINT PK_PhieuNhap PRIMARY KEY,
    MaNV     INT NOT NULL CONSTRAINT FK_PhieuNhap_NhanVien REFERENCES NhanVien(MaNV),
    MaNCC    INT NOT NULL CONSTRAINT FK_PhieuNhap_NhaCungCap REFERENCES NhaCungCap(MaNCC),
    NgayNhap DATETIME2(0) NOT NULL CONSTRAINT DF_PhieuNhap_NgayNhap DEFAULT (SYSDATETIME()),
    GhiChu   NVARCHAR(200) NULL
);

/* ---------- Ba bảng của mối kết hợp N-N có thuộc tính ---------- */
-- Món - Nguyên liệu (định lượng): để chế biến 1 phần món cần bao nhiêu nguyên liệu
CREATE TABLE DinhLuong (
    MaMon    INT NOT NULL CONSTRAINT FK_DinhLuong_Mon REFERENCES Mon(MaMon),
    MaNL     INT NOT NULL CONSTRAINT FK_DinhLuong_NguyenLieu REFERENCES NguyenLieu(MaNL),
    SoLuong  DECIMAL(12,3) NOT NULL CONSTRAINT CK_DinhLuong_SoLuong CHECK (SoLuong > 0),
    CONSTRAINT PK_DinhLuong PRIMARY KEY (MaMon, MaNL)
);

-- Hóa đơn - Món (chi tiết hóa đơn); DonGia lưu giá tại thời điểm bán
CREATE TABLE HD_M (
    MaHD     INT NOT NULL CONSTRAINT FK_HD_M_HoaDon REFERENCES HoaDon(MaHD),
    MaMon    INT NOT NULL CONSTRAINT FK_HD_M_Mon REFERENCES Mon(MaMon),
    SoLuong  INT NOT NULL CONSTRAINT CK_HD_M_SoLuong CHECK (SoLuong > 0),
    DonGia   DECIMAL(12,0) NOT NULL CONSTRAINT CK_HD_M_DonGia CHECK (DonGia >= 0),
    CONSTRAINT PK_HD_M PRIMARY KEY (MaHD, MaMon)
);

-- Phiếu nhập - Nguyên liệu (chi tiết phiếu nhập)
CREATE TABLE ChiTietPhieuNhap (
    MaPN        INT NOT NULL CONSTRAINT FK_CTPN_PhieuNhap REFERENCES PhieuNhap(MaPN),
    MaNL        INT NOT NULL CONSTRAINT FK_CTPN_NguyenLieu REFERENCES NguyenLieu(MaNL),
    SoLuong     DECIMAL(12,3) NOT NULL CONSTRAINT CK_CTPN_SoLuong CHECK (SoLuong > 0),
    DonGiaNhap  DECIMAL(12,0) NOT NULL CONSTRAINT CK_CTPN_DonGiaNhap CHECK (DonGiaNhap >= 0),
    CONSTRAINT PK_ChiTietPhieuNhap PRIMARY KEY (MaPN, MaNL)
);
GO

/* =====================================================================
   ALTER TABLE: bổ sung / sửa ràng buộc sau khi đã tạo bảng
   ===================================================================== */
-- 1) Khóa ngoại đệ quy của LoaiMon (loại cha) và không cho tự làm cha của chính nó
ALTER TABLE LoaiMon ADD CONSTRAINT FK_LoaiMon_LoaiCha
    FOREIGN KEY (MaLoaiCha) REFERENCES LoaiMon(MaLoai);
ALTER TABLE LoaiMon ADD CONSTRAINT CK_LoaiMon_KhongTuCha
    CHECK (MaLoaiCha IS NULL OR MaLoaiCha <> MaLoai);
ALTER TABLE LoaiMon ADD CONSTRAINT UQ_LoaiMon_TenLoai UNIQUE (TenLoai);

-- 2) Số điện thoại không được trùng
ALTER TABLE NhanVien  ADD CONSTRAINT UQ_NhanVien_SDT  UNIQUE (SDT);
ALTER TABLE KhachHang ADD CONSTRAINT UQ_KhachHang_SDT UNIQUE (SDT);

-- 3) Giờ đóng hóa đơn không được trước giờ mở
ALTER TABLE HoaDon ADD CONSTRAINT CK_HoaDon_ThoiGian
    CHECK (ThoiGianDong IS NULL OR ThoiGianDong >= ThoiGianMo);

-- 4) Tên nhà cung cấp không trùng
ALTER TABLE NhaCungCap ADD CONSTRAINT UQ_NhaCungCap_TenNCC UNIQUE (TenNCC);
GO

-- Kiểm tra nhanh: liệt kê các bảng đã tạo
SELECT name AS TenBang FROM sys.tables ORDER BY name;
GO

SET NOEXEC OFF;
GO
GO

/* ================= BẮT ĐẦU FILE 03_DuLieu.sql ================= */
GO
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
GO

/* ================= BẮT ĐẦU FILE 04_TruyVan_View.sql ================= */
GO
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
GO

/* ================= BẮT ĐẦU FILE 05_ThuTuc_Ham.sql ================= */
GO
/* =====================================================================
   05_ThuTuc_Ham.sql  -  4 FUNCTION và 5 STORED PROCEDURE
   Function : 2 vô hướng, 1 bảng inline, 1 bảng nhiều câu lệnh
   Procedure: có tham số OUTPUT, có IF/WHILE/CASE, có kiểm tra đầu vào + THROW,
              có thao tác nhiều bảng. Mỗi đối tượng có ca chạy thử ĐÚNG và ca chạy thử SAI.
   Lưu ý: trigger chưa tồn tại ở file này (tạo ở file 06), nên mọi thủ tục tự kiểm tra
          quy tắc nghiệp vụ; trigger ở file 06 là lớp bảo vệ thêm cho thao tác ghi trực tiếp.
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
   PHẦN A - FUNCTION
   ===================================================================== */

-- F1 (vô hướng): giá vốn của 1 phần món = tổng (định lượng x đơn giá vốn nguyên liệu)
CREATE FUNCTION dbo.fn_GiaVonMon (@MaMon INT)
RETURNS DECIMAL(14,0)
AS
BEGIN
    DECLARE @GiaVon DECIMAL(14,0);
    SELECT @GiaVon = SUM(dl.SoLuong * nl.DonGiaVon)
    FROM DinhLuong dl
    JOIN NguyenLieu nl ON nl.MaNL = dl.MaNL
    WHERE dl.MaMon = @MaMon;
    RETURN @GiaVon;              -- NULL nếu món không tồn tại hoặc chưa có định lượng
END
GO

-- F2 (vô hướng): tổng tiền hóa đơn trước giảm giá
CREATE FUNCTION dbo.fn_TongTienHoaDon (@MaHD INT)
RETURNS DECIMAL(14,0)
AS
BEGIN
    DECLARE @Tong DECIMAL(14,0);
    SELECT @Tong = SUM(SoLuong * DonGia) FROM HD_M WHERE MaHD = @MaHD;
    RETURN ISNULL(@Tong, 0);
END
GO

-- F3 (bảng inline): nguyên liệu có tồn kho dưới (định mức x hệ số)
CREATE FUNCTION dbo.fn_NguyenLieuDuoiDinhMuc (@HeSo DECIMAL(5,2))
RETURNS TABLE
AS
RETURN
(
    SELECT MaNL, TenNL, DonViTinh, TonKho, DinhMucTon, DinhMucTon * @HeSo - TonKho AS CanNhapThem
    FROM NguyenLieu
    WHERE TonKho < DinhMucTon * @HeSo
);
GO

-- F4 (bảng nhiều câu lệnh): top món bán chạy trong khoảng ngày
CREATE FUNCTION dbo.fn_MonBanChay (@Top INT, @TuNgay DATE, @DenNgay DATE)
RETURNS @KetQua TABLE (Hang INT, MaMon INT, TenMon NVARCHAR(100), TongSoLuong INT)
AS
BEGIN
    INSERT INTO @KetQua (Hang, MaMon, TenMon, TongSoLuong)
    SELECT TOP (@Top)
           ROW_NUMBER() OVER (ORDER BY SUM(ct.SoLuong) DESC),
           m.MaMon, m.TenMon, SUM(ct.SoLuong)
    FROM HD_M ct
    JOIN HoaDon hd ON hd.MaHD = ct.MaHD
    JOIN Mon m     ON m.MaMon = ct.MaMon
    WHERE hd.TrangThai = 'DaThanhToan'
      AND hd.ThoiGianMo >= @TuNgay
      AND hd.ThoiGianMo <  DATEADD(DAY, 1, @DenNgay)
    GROUP BY m.MaMon, m.TenMon
    ORDER BY SUM(ct.SoLuong) DESC;
    RETURN;
END
GO

/* =====================================================================
   PHẦN B - STORED PROCEDURE
   ===================================================================== */

-- P1: mở hóa đơn cho một bàn.  [Có tham số OUTPUT + kiểm tra đầu vào + THROW]
CREATE PROCEDURE sp_MoHoaDon
    @MaBan INT,
    @MaNV  INT,
    @MaKH  INT = NULL,          -- NULL = khách vãng lai
    @MaHD  INT OUTPUT           -- trả về mã hóa đơn vừa mở
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Ban WHERE MaBan = @MaBan)
        THROW 50001, N'Bàn không tồn tại.', 1;
    IF NOT EXISTS (SELECT 1 FROM NhanVien WHERE MaNV = @MaNV AND DangLam = 1)
        THROW 50002, N'Nhân viên không tồn tại hoặc đã nghỉ việc.', 1;
    IF @MaKH IS NOT NULL AND NOT EXISTS (SELECT 1 FROM KhachHang WHERE MaKH = @MaKH)
        THROW 50003, N'Khách hàng không tồn tại.', 1;
    IF EXISTS (SELECT 1 FROM HoaDon WHERE MaBan = @MaBan AND TrangThai = 'DangMo')
        THROW 50004, N'Bàn đang có khách, không nhận thêm hóa đơn mới.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
            INSERT INTO HoaDon (MaKH, MaNV, MaBan) VALUES (@MaKH, @MaNV, @MaBan);
            UPDATE Ban SET TrangThai = 'CoKhach' WHERE MaBan = @MaBan;
            -- mỗi bàn chỉ có tối đa 1 hóa đơn đang mở nên truy ngược mã hóa đơn như sau
            SELECT @MaHD = MaHD FROM HoaDon WHERE MaBan = @MaBan AND TrangThai = 'DangMo';
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- P2: gọi món, trừ nguyên liệu theo định lượng.  [Thao tác NHIỀU bảng: HD_M + NguyenLieu, có giao tác]
CREATE PROCEDURE sp_GoiMon
    @MaHD    INT,
    @MaMon   INT,
    @SoLuong INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @SoLuong IS NULL OR @SoLuong <= 0
        THROW 50020, N'Số lượng phải lớn hơn 0.', 1;
    IF NOT EXISTS (SELECT 1 FROM HoaDon WHERE MaHD = @MaHD AND TrangThai = 'DangMo')
        THROW 50021, N'Hóa đơn không tồn tại hoặc không ở trạng thái đang mở.', 1;
    IF NOT EXISTS (SELECT 1 FROM Mon WHERE MaMon = @MaMon AND DangBan = 1)
        THROW 50022, N'Món không tồn tại hoặc đã ngừng bán.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
            -- Món đã có trong hóa đơn thì cộng dồn số lượng, chưa có thì thêm dòng mới (DonGia = giá bán hiện tại)
            IF EXISTS (SELECT 1 FROM HD_M WHERE MaHD = @MaHD AND MaMon = @MaMon)
            BEGIN
                UPDATE HD_M SET SoLuong = SoLuong + @SoLuong WHERE MaHD = @MaHD AND MaMon = @MaMon;
            END
            ELSE
            BEGIN
                INSERT INTO HD_M (MaHD, MaMon, SoLuong, DonGia)
                SELECT @MaHD, @MaMon, @SoLuong, GiaBan FROM Mon WHERE MaMon = @MaMon;
            END

            -- Trừ tất cả nguyên liệu của món cùng lúc
            UPDATE nl
            SET TonKho = nl.TonKho - dl.SoLuong * @SoLuong
            FROM NguyenLieu nl
            JOIN DinhLuong dl ON dl.MaNL = nl.MaNL
            WHERE dl.MaMon = @MaMon;

            -- Thiếu dù chỉ MỘT nguyên liệu thì hủy cả giao tác (kể cả dòng HD_M vừa thêm)
            IF EXISTS (SELECT 1
                       FROM NguyenLieu nl
                       JOIN DinhLuong dl ON dl.MaNL = nl.MaNL
                       WHERE dl.MaMon = @MaMon AND nl.TonKho < 0)
                THROW 50023, N'Không đủ nguyên liệu để chế biến món này.', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- P3: thanh toán hóa đơn.  [Có IF + CASE (giảm giá theo điểm), OUTPUT, nhiều bảng: HoaDon, Ban, KhachHang]
-- Quy tắc giảm giá: khách từ 500 điểm giảm 10%, từ 200 điểm giảm 5%, còn lại không giảm.
CREATE PROCEDURE sp_ThanhToan
    @MaHD           INT,
    @PhuongThucTT   VARCHAR(15),
    @SoTienPhaiTra  DECIMAL(14,0) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MaKH INT, @MaBan INT, @Tong DECIMAL(14,0), @Diem INT, @GiamGia DECIMAL(5,2);

    SELECT @MaKH = MaKH, @MaBan = MaBan
    FROM HoaDon
    WHERE MaHD = @MaHD AND TrangThai = 'DangMo';

    IF @MaBan IS NULL
        THROW 50030, N'Hóa đơn không tồn tại hoặc không ở trạng thái đang mở.', 1;
    IF @PhuongThucTT IS NULL OR @PhuongThucTT NOT IN ('TienMat', 'The', 'ChuyenKhoan')
        THROW 50031, N'Phương thức thanh toán phải là TienMat, The hoặc ChuyenKhoan.', 1;

    SET @Tong = dbo.fn_TongTienHoaDon(@MaHD);
    IF @Tong = 0
        THROW 50032, N'Hóa đơn chưa có món nào.', 1;

    SELECT @Diem = DiemTichLuy FROM KhachHang WHERE MaKH = @MaKH;   -- khách vãng lai: @Diem vẫn NULL
    SET @GiamGia = CASE WHEN @Diem >= 500 THEN 10
                        WHEN @Diem >= 200 THEN 5
                        ELSE 0 END;
    SET @SoTienPhaiTra = @Tong * (100 - @GiamGia) / 100;

    BEGIN TRY
        BEGIN TRANSACTION;
            UPDATE HoaDon
            SET TrangThai = 'DaThanhToan', ThoiGianDong = SYSDATETIME(),
                PhuongThucTT = @PhuongThucTT, GiamGiaPhanTram = @GiamGia
            WHERE MaHD = @MaHD;

            UPDATE Ban SET TrangThai = 'Trong' WHERE MaBan = @MaBan;

            IF @MaKH IS NOT NULL      -- cứ 10.000đ được 1 điểm
                UPDATE KhachHang
                SET DiemTichLuy = DiemTichLuy + CAST(@SoTienPhaiTra / 10000 AS INT)
                WHERE MaKH = @MaKH;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- P4: nhập nguyên liệu vào kho.  [Nhiều bảng: PhieuNhap, ChiTietPhieuNhap, NguyenLieu]
CREATE PROCEDURE sp_NhapKho
    @MaNCC      INT,
    @MaNV       INT,
    @MaNL       INT,
    @SoLuong    DECIMAL(12,3),
    @DonGiaNhap DECIMAL(12,0)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MaPN INT;

    IF @SoLuong IS NULL OR @SoLuong <= 0
        THROW 50040, N'Số lượng nhập phải lớn hơn 0.', 1;
    IF @DonGiaNhap IS NULL OR @DonGiaNhap < 0
        THROW 50041, N'Đơn giá nhập không được âm.', 1;
    IF NOT EXISTS (SELECT 1 FROM NhaCungCap WHERE MaNCC = @MaNCC)
        THROW 50042, N'Nhà cung cấp không tồn tại.', 1;
    IF NOT EXISTS (SELECT 1 FROM NhanVien WHERE MaNV = @MaNV AND DangLam = 1)
        THROW 50043, N'Nhân viên không tồn tại hoặc đã nghỉ việc.', 1;
    IF NOT EXISTS (SELECT 1 FROM NguyenLieu WHERE MaNL = @MaNL)
        THROW 50044, N'Nguyên liệu không tồn tại.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
            INSERT INTO PhieuNhap (MaNV, MaNCC) VALUES (@MaNV, @MaNCC);
            SET @MaPN = SCOPE_IDENTITY();
            INSERT INTO ChiTietPhieuNhap (MaPN, MaNL, SoLuong, DonGiaNhap)
            VALUES (@MaPN, @MaNL, @SoLuong, @DonGiaNhap);
            UPDATE NguyenLieu SET TonKho = TonKho + @SoLuong WHERE MaNL = @MaNL;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- P5: báo cáo doanh thu từng ngày (kể cả ngày không có hóa đơn).  [Có WHILE]
CREATE PROCEDURE sp_BaoCaoDoanhThu
    @TuNgay  DATE,
    @DenNgay DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @TuNgay > @DenNgay
        THROW 50050, N'Từ ngày phải nhỏ hơn hoặc bằng đến ngày.', 1;
    IF DATEDIFF(DAY, @TuNgay, @DenNgay) > 366
        THROW 50051, N'Khoảng báo cáo tối đa 366 ngày.', 1;

    DECLARE @Ngay DATE = @TuNgay;
    DECLARE @KetQua TABLE (Ngay DATE, SoHoaDon INT, DoanhThu DECIMAL(14,0));

    WHILE @Ngay <= @DenNgay
    BEGIN
        INSERT INTO @KetQua (Ngay, SoHoaDon, DoanhThu)
        SELECT @Ngay, COUNT(*), ISNULL(SUM(TongPhaiTra), 0)
        FROM vw_DoanhThuHoaDon
        WHERE TrangThai = 'DaThanhToan'
          AND ThoiGianMo >= @Ngay AND ThoiGianMo < DATEADD(DAY, 1, @Ngay);

        SET @Ngay = DATEADD(DAY, 1, @Ngay);
    END

    SELECT Ngay, SoHoaDon, DoanhThu FROM @KetQua ORDER BY Ngay;
END
GO

/* =====================================================================
   PHẦN C - CHẠY THỬ (mỗi đối tượng có ca ĐÚNG và ca SAI)
   ===================================================================== */

/* ---- Function ---- */
-- fn_GiaVonMon: ĐÚNG (Cà phê sữa = 0,02 kg cà phê + 0,03 lon sữa đặc = 4.350đ); SAI (món không tồn tại -> NULL)
SELECT dbo.fn_GiaVonMon(2)   AS GiaVon_CaPheSua_Dung;
SELECT dbo.fn_GiaVonMon(999) AS GiaVon_MonKhongTonTai_Sai;

-- fn_TongTienHoaDon: ĐÚNG (hóa đơn 1); SAI (hóa đơn không tồn tại -> 0)
SELECT dbo.fn_TongTienHoaDon(1)      AS TongTien_HD1_Dung;
SELECT dbo.fn_TongTienHoaDon(999999) AS TongTien_HDKhongTonTai_Sai;

-- fn_NguyenLieuDuoiDinhMuc: ĐÚNG (hệ số 1 -> các nguyên liệu dưới định mức); SAI/biên (hệ số 0 -> không có dòng nào)
SELECT * FROM dbo.fn_NguyenLieuDuoiDinhMuc(1.0);
SELECT * FROM dbo.fn_NguyenLieuDuoiDinhMuc(0);

-- fn_MonBanChay: ĐÚNG (top 5 năm 2025); SAI/biên (top 0 -> rỗng)
SELECT * FROM dbo.fn_MonBanChay(5, '2025-01-01', '2025-12-31');
SELECT * FROM dbo.fn_MonBanChay(0, '2025-01-01', '2025-12-31');
GO

/* ---- sp_MoHoaDon ---- */
-- ĐÚNG: mở hóa đơn cho Bàn 1 (nhân viên 2, khách 3)
DECLARE @MaHD1 INT;
EXEC sp_MoHoaDon @MaBan = 1, @MaNV = 2, @MaKH = 3, @MaHD = @MaHD1 OUTPUT;
SELECT @MaHD1 AS MaHoaDonVuaMo, TrangThai AS TrangThaiBan1 FROM Ban WHERE MaBan = 1;
GO
-- SAI 1: Bàn 1 đang có khách
BEGIN TRY
    DECLARE @MaHD2 INT;
    EXEC sp_MoHoaDon @MaBan = 1, @MaNV = 2, @MaHD = @MaHD2 OUTPUT;
END TRY
BEGIN CATCH
    PRINT N'sp_MoHoaDon SAI 1 - bị từ chối: ' + ERROR_MESSAGE();
END CATCH
-- SAI 2: nhân viên đã nghỉ việc (MaNV = 6)
BEGIN TRY
    DECLARE @MaHD3 INT;
    EXEC sp_MoHoaDon @MaBan = 2, @MaNV = 6, @MaHD = @MaHD3 OUTPUT;
END TRY
BEGIN CATCH
    PRINT N'sp_MoHoaDon SAI 2 - bị từ chối: ' + ERROR_MESSAGE();
END CATCH
GO

/* ---- sp_GoiMon (dùng hóa đơn đang mở của Bàn 1) ---- */
-- ĐÚNG: gọi 2 ly Cà phê sữa; xem tồn kho cà phê hạt (mã 1) và sữa đặc (mã 2) giảm
DECLARE @HD INT = (SELECT MaHD FROM HoaDon WHERE MaBan = 1 AND TrangThai = 'DangMo');
SELECT MaNL, TenNL, TonKho AS TonTruoc FROM NguyenLieu WHERE MaNL IN (1, 2);
EXEC sp_GoiMon @MaHD = @HD, @MaMon = 2, @SoLuong = 2;
EXEC sp_GoiMon @MaHD = @HD, @MaMon = 13, @SoLuong = 1;       -- thêm 1 Mì Ý
SELECT MaNL, TenNL, TonKho AS TonSau FROM NguyenLieu WHERE MaNL IN (1, 2);
SELECT * FROM HD_M WHERE MaHD = @HD;
GO
-- SAI 1: số lượng bằng 0
BEGIN TRY
    DECLARE @HD1 INT = (SELECT MaHD FROM HoaDon WHERE MaBan = 1 AND TrangThai = 'DangMo');
    EXEC sp_GoiMon @MaHD = @HD1, @MaMon = 2, @SoLuong = 0;
END TRY
BEGIN CATCH
    PRINT N'sp_GoiMon SAI 1 - bị từ chối: ' + ERROR_MESSAGE();
END CATCH
-- SAI 2: món không tồn tại
BEGIN TRY
    DECLARE @HD2 INT = (SELECT MaHD FROM HoaDon WHERE MaBan = 1 AND TrangThai = 'DangMo');
    EXEC sp_GoiMon @MaHD = @HD2, @MaMon = 999, @SoLuong = 1;
END TRY
BEGIN CATCH
    PRINT N'sp_GoiMon SAI 2 - bị từ chối: ' + ERROR_MESSAGE();
END CATCH
-- SAI 3: Bánh mì ốp la (mã 16) cần "Bánh mì ổ" nhưng tồn kho = 0 -> hủy cả giao tác
BEGIN TRY
    DECLARE @HD3 INT = (SELECT MaHD FROM HoaDon WHERE MaBan = 1 AND TrangThai = 'DangMo');
    EXEC sp_GoiMon @MaHD = @HD3, @MaMon = 16, @SoLuong = 1;
END TRY
BEGIN CATCH
    PRINT N'sp_GoiMon SAI 3 - bị từ chối: ' + ERROR_MESSAGE();
END CATCH
-- Kiểm chứng đã hoàn tác: hóa đơn KHÔNG có món 16, tồn kho trứng gà (mã 21) và bánh mì ổ (mã 25) giữ nguyên
SELECT COUNT(*) AS SoDongMon16_PhaiLa0
FROM HD_M WHERE MaMon = 16 AND MaHD = (SELECT MaHD FROM HoaDon WHERE MaBan = 1 AND TrangThai = 'DangMo');
SELECT MaNL, TenNL, TonKho FROM NguyenLieu WHERE MaNL IN (21, 25);
GO

/* ---- sp_ThanhToan ---- */
-- SAI 1: phương thức thanh toán không hợp lệ
BEGIN TRY
    DECLARE @HDa INT = (SELECT MaHD FROM HoaDon WHERE MaBan = 1 AND TrangThai = 'DangMo');
    DECLARE @Tien0 DECIMAL(14,0);
    EXEC sp_ThanhToan @MaHD = @HDa, @PhuongThucTT = 'Bitcoin', @SoTienPhaiTra = @Tien0 OUTPUT;
END TRY
BEGIN CATCH
    PRINT N'sp_ThanhToan SAI 1 - bị từ chối: ' + ERROR_MESSAGE();
END CATCH
GO
-- ĐÚNG: thanh toán hóa đơn Bàn 1 (khách 3 có 300 điểm -> giảm 5%)
DECLARE @HDb INT = (SELECT MaHD FROM HoaDon WHERE MaBan = 1 AND TrangThai = 'DangMo');
DECLARE @Tien DECIMAL(14,0);
SELECT DiemTichLuy AS DiemTruoc FROM KhachHang WHERE MaKH = 3;
EXEC sp_ThanhToan @MaHD = @HDb, @PhuongThucTT = 'TienMat', @SoTienPhaiTra = @Tien OUTPUT;
SELECT @Tien AS SoTienPhaiTra;
SELECT TrangThai, GiamGiaPhanTram, PhuongThucTT FROM HoaDon WHERE MaHD = @HDb;
SELECT TrangThai AS TrangThaiBan1_SauThanhToan FROM Ban WHERE MaBan = 1;
SELECT DiemTichLuy AS DiemSau FROM KhachHang WHERE MaKH = 3;
-- SAI 2: thanh toán lại hóa đơn đã đóng
BEGIN TRY
    EXEC sp_ThanhToan @MaHD = @HDb, @PhuongThucTT = 'TienMat', @SoTienPhaiTra = @Tien OUTPUT;
END TRY
BEGIN CATCH
    PRINT N'sp_ThanhToan SAI 2 - bị từ chối: ' + ERROR_MESSAGE();
END CATCH
GO

/* ---- sp_NhapKho ---- */
-- ĐÚNG: nhập thêm 10 ổ bánh mì (mã 25) từ nhà cung cấp 10; tồn kho tăng từ 0 lên 10
SELECT TonKho AS TonTruoc FROM NguyenLieu WHERE MaNL = 25;
EXEC sp_NhapKho @MaNCC = 10, @MaNV = 1, @MaNL = 25, @SoLuong = 10, @DonGiaNhap = 5000;
SELECT TonKho AS TonSau FROM NguyenLieu WHERE MaNL = 25;
GO
-- SAI 1: số lượng âm
BEGIN TRY
    EXEC sp_NhapKho @MaNCC = 10, @MaNV = 1, @MaNL = 25, @SoLuong = -5, @DonGiaNhap = 5000;
END TRY
BEGIN CATCH
    PRINT N'sp_NhapKho SAI 1 - bị từ chối: ' + ERROR_MESSAGE();
END CATCH
-- SAI 2: nhà cung cấp không tồn tại
BEGIN TRY
    EXEC sp_NhapKho @MaNCC = 999, @MaNV = 1, @MaNL = 25, @SoLuong = 5, @DonGiaNhap = 5000;
END TRY
BEGIN CATCH
    PRINT N'sp_NhapKho SAI 2 - bị từ chối: ' + ERROR_MESSAGE();
END CATCH
GO

/* ---- sp_BaoCaoDoanhThu ---- */
-- ĐÚNG: 7 ngày đầu tháng 3/2025 (WHILE chạy 7 vòng)
EXEC sp_BaoCaoDoanhThu @TuNgay = '2025-03-01', @DenNgay = '2025-03-07';
GO
-- SAI 1: từ ngày lớn hơn đến ngày
BEGIN TRY
    EXEC sp_BaoCaoDoanhThu @TuNgay = '2025-03-10', @DenNgay = '2025-03-01';
END TRY
BEGIN CATCH
    PRINT N'sp_BaoCaoDoanhThu SAI 1 - bị từ chối: ' + ERROR_MESSAGE();
END CATCH
-- SAI 2: khoảng quá dài
BEGIN TRY
    EXEC sp_BaoCaoDoanhThu @TuNgay = '2020-01-01', @DenNgay = '2025-12-31';
END TRY
BEGIN CATCH
    PRINT N'sp_BaoCaoDoanhThu SAI 2 - bị từ chối: ' + ERROR_MESSAGE();
END CATCH
GO

SET NOEXEC OFF;
GO
GO

/* ================= BẮT ĐẦU FILE 06_Trigger_GiaoTac.sql ================= */
GO
/* =====================================================================
   06_Trigger_GiaoTac.sql  -  3 TRIGGER và 2 KỊCH BẢN GIAO TÁC
   Trigger : AFTER (2 cái) + INSTEAD OF (1 cái); xử lý đúng khi 1 câu lệnh tác động nhiều dòng
             bằng cách dùng bảng inserted / deleted (không giả định chỉ có 1 dòng).
   Giao tác: BEGIN TRAN / COMMIT / ROLLBACK + TRY...CATCH, demo thành công và thất bại.
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
   PHẦN A - TRIGGER
   ===================================================================== */

-- T1 (AFTER UPDATE): chặn tồn kho âm.  Quy tắc nghiệp vụ: không bán món khi thiếu nguyên liệu.
CREATE TRIGGER trg_NguyenLieu_ChanTonAm
ON NguyenLieu
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(TonKho) RETURN;

    IF EXISTS (SELECT 1 FROM inserted WHERE TonKho < 0)     -- kiểm tra mọi dòng bị sửa
    BEGIN
        DECLARE @Ten NVARCHAR(100), @Msg NVARCHAR(200);
        SELECT TOP 1 @Ten = TenNL FROM inserted WHERE TonKho < 0;
        SET @Msg = CONCAT(N'Tồn kho không được âm. Nguyên liệu vi phạm: ', @Ten);
        ROLLBACK TRANSACTION;                               -- hủy cả câu lệnh gây lỗi
        THROW 50101, @Msg, 1;
    END
END
GO

-- T2 (INSTEAD OF INSERT): bàn đang có khách thì không nhận thêm hóa đơn mở.
-- Thủ tục sp_MoHoaDon đã tự kiểm tra, trigger này chặn cả trường hợp INSERT trực tiếp vào bảng.
CREATE TRIGGER trg_HoaDon_ChanBanCoKhach
ON HoaDon
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1                                     -- (1) bàn đã có hóa đơn đang mở
               FROM inserted i
               WHERE i.TrangThai = 'DangMo'
                 AND EXISTS (SELECT 1 FROM HoaDon h WHERE h.MaBan = i.MaBan AND h.TrangThai = 'DangMo'))
       OR EXISTS (SELECT 1                                  -- (2) cùng 1 lệnh INSERT mở 2 hóa đơn cho 1 bàn
                  FROM inserted
                  WHERE TrangThai = 'DangMo'
                  GROUP BY MaBan
                  HAVING COUNT(*) > 1)
        THROW 50102, N'Bàn đang có khách, không nhận thêm hóa đơn mới.', 1;

    -- Hợp lệ: thực hiện việc INSERT thay cho câu lệnh gốc (INSTEAD OF nên phải tự INSERT)
    INSERT INTO HoaDon (MaKH, MaNV, MaBan, ThoiGianMo, ThoiGianDong, TrangThai, PhuongThucTT, GiamGiaPhanTram)
    SELECT MaKH, MaNV, MaBan, ThoiGianMo, ThoiGianDong, TrangThai, PhuongThucTT, GiamGiaPhanTram
    FROM inserted;
END
GO

-- T3 (AFTER INSERT, UPDATE, DELETE): không cho sửa chi tiết của hóa đơn đã thanh toán hoặc đã hủy
CREATE TRIGGER trg_HD_M_ChanSuaHoaDonDong
ON HD_M
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM (SELECT MaHD FROM inserted
                     UNION
                     SELECT MaHD FROM deleted) AS x
               JOIN HoaDon hd ON hd.MaHD = x.MaHD
               WHERE hd.TrangThai <> 'DangMo')
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50103, N'Không được thêm, sửa, xóa món của hóa đơn đã thanh toán hoặc đã hủy.', 1;
    END
END
GO

/* =====================================================================
   PHẦN B - CHẠY THỬ TRIGGER
   ===================================================================== */

/* ---- T1: chặn tồn kho âm (UPDATE nhiều dòng cùng lúc) ---- */
-- ĐÚNG: cộng 1 vào tồn kho của nguyên liệu 1 và 2 (hai dòng)
UPDATE NguyenLieu SET TonKho = TonKho + 1 WHERE MaNL IN (1, 2);
SELECT MaNL, TenNL, TonKho FROM NguyenLieu WHERE MaNL IN (1, 2);
GO
-- SAI: trừ 99.999 cho cả hai nguyên liệu -> cả câu lệnh bị hủy, không dòng nào bị đổi
BEGIN TRY
    UPDATE NguyenLieu SET TonKho = TonKho - 99999 WHERE MaNL IN (1, 2);
    PRINT N'LỖI: lẽ ra phải bị chặn!';
END TRY
BEGIN CATCH
    PRINT N'T1 bị từ chối: ' + ERROR_MESSAGE();
END CATCH
SELECT MaNL, TenNL, TonKho AS TonKho_VanNhuCu FROM NguyenLieu WHERE MaNL IN (1, 2);
GO

/* ---- T2: bàn đang có khách không nhận hóa đơn mới (INSERT trực tiếp) ---- */
DECLARE @HDx INT;
EXEC sp_MoHoaDon @MaBan = 3, @MaNV = 2, @MaHD = @HDx OUTPUT;     -- Bàn 3 đang có khách
GO
-- SAI 1: INSERT trực tiếp thêm hóa đơn mở cho Bàn 3
BEGIN TRY
    INSERT INTO HoaDon (MaNV, MaBan) VALUES (2, 3);
    PRINT N'LỖI: lẽ ra phải bị chặn!';
END TRY
BEGIN CATCH
    PRINT N'T2 (SAI 1) bị từ chối: ' + ERROR_MESSAGE();
END CATCH
-- SAI 2: một lệnh INSERT nhiều dòng cùng mở 2 hóa đơn cho Bàn 4 -> bị chặn cả lệnh
BEGIN TRY
    INSERT INTO HoaDon (MaNV, MaBan) VALUES (2, 4), (3, 4);
    PRINT N'LỖI: lẽ ra phải bị chặn!';
END TRY
BEGIN CATCH
    PRINT N'T2 (SAI 2) bị từ chối: ' + ERROR_MESSAGE();
END CATCH
-- ĐÚNG: INSERT nhiều dòng cho 2 bàn khác nhau còn trống (5 và 6) rồi hoàn tác để giữ dữ liệu sạch
BEGIN TRANSACTION;
    INSERT INTO HoaDon (MaNV, MaBan) VALUES (2, 5), (3, 6);
    SELECT MaHD, MaBan, TrangThai FROM HoaDon WHERE MaBan IN (5, 6) AND TrangThai = 'DangMo';   -- thấy 2 dòng
ROLLBACK TRANSACTION;
SELECT COUNT(*) AS SoHoaDonMoCuaBan5Va6_PhaiLa0 FROM HoaDon WHERE MaBan IN (5, 6) AND TrangThai = 'DangMo';
GO

/* ---- T3: không sửa chi tiết hóa đơn đã đóng ---- */
-- SAI 1: thêm món vào hóa đơn 1 (đã thanh toán)
BEGIN TRY
    INSERT INTO HD_M (MaHD, MaMon, SoLuong, DonGia) VALUES (1, 25, 1, 10000);
    PRINT N'LỖI: lẽ ra phải bị chặn!';
END TRY
BEGIN CATCH
    PRINT N'T3 (SAI 1) bị từ chối: ' + ERROR_MESSAGE();
END CATCH
-- SAI 2: UPDATE nhiều dòng thuộc nhiều hóa đơn đã đóng
BEGIN TRY
    UPDATE HD_M SET SoLuong = SoLuong + 1 WHERE MaHD IN (1, 2);
    PRINT N'LỖI: lẽ ra phải bị chặn!';
END TRY
BEGIN CATCH
    PRINT N'T3 (SAI 2) bị từ chối: ' + ERROR_MESSAGE();
END CATCH
-- SAI 3: xóa chi tiết hóa đơn đã đóng
BEGIN TRY
    DELETE FROM HD_M WHERE MaHD = 1;
    PRINT N'LỖI: lẽ ra phải bị chặn!';
END TRY
BEGIN CATCH
    PRINT N'T3 (SAI 3) bị từ chối: ' + ERROR_MESSAGE();
END CATCH
-- ĐÚNG: gọi món vào hóa đơn đang mở của Bàn 3 vẫn được phép
DECLARE @HDm INT = (SELECT MaHD FROM HoaDon WHERE MaBan = 3 AND TrangThai = 'DangMo');
EXEC sp_GoiMon @MaHD = @HDm, @MaMon = 1, @SoLuong = 1;
SELECT * FROM HD_M WHERE MaHD = @HDm;
GO

/* =====================================================================
   PHẦN C - GIAO TÁC
   ===================================================================== */

/* ---- Kịch bản 1: gọi NHIỀU món trong một giao tác; thiếu nguyên liệu của một món thì hủy cả hai ---- */
-- Chuẩn bị: mở hóa đơn cho Bàn 7
DECLARE @HDg1 INT;
EXEC sp_MoHoaDon @MaBan = 7, @MaNV = 3, @MaHD = @HDg1 OUTPUT;
GO

-- 1A. THÀNH CÔNG: gọi Cà phê sữa (mã 2) và Mì Ý sốt bò (mã 13), đủ nguyên liệu -> COMMIT
DECLARE @HD INT = (SELECT MaHD FROM HoaDon WHERE MaBan = 7 AND TrangThai = 'DangMo');
BEGIN TRY
    BEGIN TRANSACTION;
        INSERT INTO HD_M (MaHD, MaMon, SoLuong, DonGia)
        SELECT @HD, m.MaMon, g.SoLuong, m.GiaBan
        FROM (VALUES (2, 1), (13, 1)) AS g(MaMon, SoLuong)
        JOIN Mon m ON m.MaMon = g.MaMon;

        UPDATE nl
        SET TonKho = nl.TonKho - x.CanDung
        FROM NguyenLieu nl
        JOIN (SELECT dl.MaNL, SUM(dl.SoLuong * g.SoLuong) AS CanDung
              FROM DinhLuong dl
              JOIN (VALUES (2, 1), (13, 1)) AS g(MaMon, SoLuong) ON g.MaMon = dl.MaMon
              GROUP BY dl.MaNL) x ON x.MaNL = nl.MaNL;
    COMMIT TRANSACTION;
    PRINT N'Kịch bản 1A: THÀNH CÔNG - đã COMMIT.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT N'Kịch bản 1A: THẤT BẠI - đã ROLLBACK: ' + ERROR_MESSAGE();
END CATCH
SELECT * FROM HD_M WHERE MaHD = @HD;
GO

-- 1B. THẤT BẠI: gọi 2 Cà phê đen (mã 1) và 1000 Bánh mì ốp la (mã 16); 1000 ổ bánh mì vượt xa tồn kho
--     (cố ý dùng số lượng lớn để luôn thiếu nguyên liệu, kể cả sau khi file 05 đã nhập thêm bánh mì ổ)
--     -> trigger T1 chặn tồn âm, toàn bộ giao tác bị hủy: dòng Cà phê sữa vừa thêm cũng biến mất
DECLARE @HD INT = (SELECT MaHD FROM HoaDon WHERE MaBan = 7 AND TrangThai = 'DangMo');
SELECT COUNT(*) AS SoDongTruoc FROM HD_M WHERE MaHD = @HD;
SELECT TonKho AS TonKhoSua_Truoc FROM NguyenLieu WHERE MaNL = 2;
BEGIN TRY
    BEGIN TRANSACTION;
        INSERT INTO HD_M (MaHD, MaMon, SoLuong, DonGia)
        SELECT @HD, m.MaMon, g.SoLuong, m.GiaBan
        FROM (VALUES (1, 2), (16, 1000)) AS g(MaMon, SoLuong)    -- món 1 (Cà phê đen) và món 16 (Bánh mì ốp la)
        JOIN Mon m ON m.MaMon = g.MaMon;

        UPDATE nl
        SET TonKho = nl.TonKho - x.CanDung
        FROM NguyenLieu nl
        JOIN (SELECT dl.MaNL, SUM(dl.SoLuong * g.SoLuong) AS CanDung
              FROM DinhLuong dl
              JOIN (VALUES (1, 2), (16, 1000)) AS g(MaMon, SoLuong) ON g.MaMon = dl.MaMon
              GROUP BY dl.MaNL) x ON x.MaNL = nl.MaNL;           -- trigger T1 bắn lỗi ở đây
    COMMIT TRANSACTION;
    PRINT N'Kịch bản 1B: lẽ ra phải thất bại!';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;   -- trigger đã tự ROLLBACK nên @@TRANCOUNT = 0; dòng này đề phòng lỗi khác
    PRINT N'Kịch bản 1B: THẤT BẠI đúng như mong đợi - đã hoàn tác: ' + ERROR_MESSAGE();
END CATCH
SELECT COUNT(*) AS SoDongSau_PhaiBangSoDongTruoc FROM HD_M WHERE MaHD = @HD;
SELECT TonKho AS TonKhoSua_Sau_PhaiNhuTruoc FROM NguyenLieu WHERE MaNL = 2;
GO

/* ---- Kịch bản 2: thanh toán; hóa đơn, bàn và điểm khách phải CÙNG thành công hoặc CÙNG hủy ---- */
-- Chuẩn bị: mở hóa đơn cho Bàn 8 (khách 20) và Bàn 10 (khách 20), gọi 1 món mỗi hóa đơn
DECLARE @HDa INT, @HDb INT;
EXEC sp_MoHoaDon @MaBan = 8,  @MaNV = 2, @MaKH = 20, @MaHD = @HDa OUTPUT;
EXEC sp_MoHoaDon @MaBan = 10, @MaNV = 2, @MaKH = 20, @MaHD = @HDb OUTPUT;
EXEC sp_GoiMon @MaHD = @HDa, @MaMon = 4, @SoLuong = 2;
EXEC sp_GoiMon @MaHD = @HDb, @MaMon = 6, @SoLuong = 1;
GO

-- 2A. THÀNH CÔNG: đóng hóa đơn Bàn 8, trả bàn, cộng điểm cho khách -> COMMIT
DECLARE @HD INT = (SELECT MaHD FROM HoaDon WHERE MaBan = 8 AND TrangThai = 'DangMo');
BEGIN TRY
    BEGIN TRANSACTION;
        UPDATE HoaDon SET TrangThai = 'DaThanhToan', ThoiGianDong = SYSDATETIME(), PhuongThucTT = 'The'
        WHERE MaHD = @HD;
        UPDATE Ban SET TrangThai = 'Trong' WHERE MaBan = 8;
        UPDATE KhachHang SET DiemTichLuy = DiemTichLuy + 10 WHERE MaKH = 20;
    COMMIT TRANSACTION;
    PRINT N'Kịch bản 2A: THÀNH CÔNG - đã COMMIT.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT N'Kịch bản 2A: THẤT BẠI - đã ROLLBACK: ' + ERROR_MESSAGE();
END CATCH
SELECT TrangThai FROM HoaDon WHERE MaHD = @HD;
SELECT TrangThai AS TrangThaiBan8 FROM Ban WHERE MaBan = 8;
GO

-- 2B. THẤT BẠI ở bước cuối: trừ điểm quá tay làm DiemTichLuy < 0 (vi phạm CHECK)
--     -> ROLLBACK khôi phục cả hóa đơn lẫn bàn đã sửa ở hai bước trước
DECLARE @HD INT = (SELECT MaHD FROM HoaDon WHERE MaBan = 10 AND TrangThai = 'DangMo');
BEGIN TRY
    BEGIN TRANSACTION;
        UPDATE HoaDon SET TrangThai = 'DaThanhToan', ThoiGianDong = SYSDATETIME(), PhuongThucTT = 'TienMat'
        WHERE MaHD = @HD;
        UPDATE Ban SET TrangThai = 'Trong' WHERE MaBan = 10;
        UPDATE KhachHang SET DiemTichLuy = DiemTichLuy - 99999 WHERE MaKH = 20;   -- lỗi CHECK
    COMMIT TRANSACTION;
    PRINT N'Kịch bản 2B: lẽ ra phải thất bại!';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT N'Kịch bản 2B: THẤT BẠI đúng như mong đợi - đã ROLLBACK: ' + ERROR_MESSAGE();
END CATCH
SELECT TrangThai AS TrangThaiHoaDon_PhaiVanLaDangMo FROM HoaDon WHERE MaHD = @HD;
SELECT TrangThai AS TrangThaiBan10_PhaiVanLaCoKhach FROM Ban WHERE MaBan = 10;
GO

-- Dọn dẹp: thanh toán các hóa đơn còn mở của Bàn 3, 7, 10 bằng thủ tục; chừa Bàn 9 mở để demo phân quyền ở file 07
DECLARE @Tien DECIMAL(14,0), @H3 INT, @H7 INT, @H10 INT;
SELECT @H3  = MaHD FROM HoaDon WHERE MaBan = 3  AND TrangThai = 'DangMo';
SELECT @H7  = MaHD FROM HoaDon WHERE MaBan = 7  AND TrangThai = 'DangMo';
SELECT @H10 = MaHD FROM HoaDon WHERE MaBan = 10 AND TrangThai = 'DangMo';
EXEC sp_ThanhToan @MaHD = @H3,  @PhuongThucTT = 'TienMat', @SoTienPhaiTra = @Tien OUTPUT;
EXEC sp_ThanhToan @MaHD = @H7,  @PhuongThucTT = 'The',     @SoTienPhaiTra = @Tien OUTPUT;
EXEC sp_ThanhToan @MaHD = @H10, @PhuongThucTT = 'TienMat', @SoTienPhaiTra = @Tien OUTPUT;

DECLARE @H9 INT;
EXEC sp_MoHoaDon @MaBan = 9, @MaNV = 4, @MaHD = @H9 OUTPUT;
EXEC sp_GoiMon @MaHD = @H9, @MaMon = 4,  @SoLuong = 2;
EXEC sp_GoiMon @MaHD = @H9, @MaMon = 14, @SoLuong = 1;
SELECT * FROM vw_MonCanCheBien;
GO

SET NOEXEC OFF;
GO
GO

/* ================= BẮT ĐẦU FILE 07_PhanQuyen_SaoLuu.sql ================= */
GO
/* =====================================================================
   07_PhanQuyen_SaoLuu.sql  -  PHÂN QUYỀN, SAO LƯU, PHỤC HỒI, PHƯƠNG ÁN HA
   Nguyên tắc quyền tối thiểu: mỗi vai trò chỉ được đúng phần việc của mình.
   Yêu cầu: SQL Server bật chế độ xác thực hỗn hợp (SQL Server and Windows Authentication)
            nếu muốn đăng nhập thật bằng các login bên dưới. Chạy file này bằng tài khoản sysadmin.
   Mật khẩu dưới đây chỉ là mật khẩu mẫu cho bài tập, KHÔNG dùng lại cho hệ thống thật.
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
   PHẦN A - TẠO LOGIN, USER, ROLE (4 vai trò)
   ===================================================================== */
-- Dọn nếu chạy lại
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'usr_phucvu')  DROP USER usr_phucvu;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'usr_thungan') DROP USER usr_thungan;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'usr_bep')     DROP USER usr_bep;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'usr_quanly')  DROP USER usr_quanly;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'PhucVu' AND type = 'R')  DROP ROLE PhucVu;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'ThuNgan' AND type = 'R') DROP ROLE ThuNgan;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'Bep' AND type = 'R')     DROP ROLE Bep;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'QuanLy' AND type = 'R')  DROP ROLE QuanLy;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'lg_phucvu')  DROP LOGIN lg_phucvu;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'lg_thungan') DROP LOGIN lg_thungan;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'lg_bep')     DROP LOGIN lg_bep;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'lg_quanly')  DROP LOGIN lg_quanly;
GO

CREATE LOGIN lg_phucvu  WITH PASSWORD = N'PhucVu#2026aB',  DEFAULT_DATABASE = QuanLyNhaHang;
CREATE LOGIN lg_thungan WITH PASSWORD = N'ThuNgan#2026aB', DEFAULT_DATABASE = QuanLyNhaHang;
CREATE LOGIN lg_bep     WITH PASSWORD = N'Bep#2026aBcd',   DEFAULT_DATABASE = QuanLyNhaHang;
CREATE LOGIN lg_quanly  WITH PASSWORD = N'QuanLy#2026aB',  DEFAULT_DATABASE = QuanLyNhaHang;
GO

CREATE USER usr_phucvu  FOR LOGIN lg_phucvu;
CREATE USER usr_thungan FOR LOGIN lg_thungan;
CREATE USER usr_bep     FOR LOGIN lg_bep;
CREATE USER usr_quanly  FOR LOGIN lg_quanly;

CREATE ROLE PhucVu;
CREATE ROLE ThuNgan;
CREATE ROLE Bep;
CREATE ROLE QuanLy;

ALTER ROLE PhucVu  ADD MEMBER usr_phucvu;
ALTER ROLE ThuNgan ADD MEMBER usr_thungan;
ALTER ROLE Bep     ADD MEMBER usr_bep;
ALTER ROLE QuanLy  ADD MEMBER usr_quanly;
GO

/* =====================================================================
   PHẦN B - GRANT / DENY / REVOKE
   Lưu ý: các thủ tục và view cùng chủ sở hữu dbo với bảng (ownership chaining),
   nên người dùng chỉ cần quyền EXECUTE / SELECT trên thủ tục / view mà không cần quyền trực tiếp trên bảng.
   ===================================================================== */
-- PhucVu: mở hóa đơn, gọi món, xem thực đơn và tình trạng bàn
GRANT EXECUTE ON sp_MoHoaDon TO PhucVu;
GRANT EXECUTE ON sp_GoiMon   TO PhucVu;
GRANT SELECT  ON vw_MenuDangBan TO PhucVu;
GRANT SELECT  ON Ban TO PhucVu;
-- Ví dụ REVOKE: lỡ cấp quyền xem khách hàng cho phục vụ, rồi thu hồi vì không cần thiết
GRANT  SELECT ON KhachHang TO PhucVu;
REVOKE SELECT ON KhachHang FROM PhucVu;

-- ThuNgan: thanh toán, xem hóa đơn; KHÔNG được sửa giá món
GRANT EXECUTE ON sp_ThanhToan TO ThuNgan;
GRANT SELECT  ON HoaDon   TO ThuNgan;
GRANT SELECT  ON HD_M     TO ThuNgan;
GRANT SELECT  ON Mon      TO ThuNgan;
GRANT SELECT  ON KhachHang TO ThuNgan;
DENY INSERT, UPDATE, DELETE ON Mon TO ThuNgan;

-- Bep: chỉ xem món cần chế biến qua view (không thấy giá, tiền, khách)
GRANT SELECT ON vw_MonCanCheBien TO Bep;

-- QuanLy: xem tất cả (tồn kho, doanh thu) nhưng không sửa dữ liệu
GRANT SELECT ON SCHEMA::dbo TO QuanLy;
DENY INSERT, UPDATE, DELETE ON SCHEMA::dbo TO QuanLy;
GRANT EXECUTE ON sp_BaoCaoDoanhThu TO QuanLy;
GO

/* =====================================================================
   PHẦN C - KIỂM CHỨNG TỪNG VAI TRÒ (EXECUTE AS USER = chạy thử với quyền của user đó)
   Có thể kiểm chứng thêm bằng cách đăng nhập SSMS với từng login ở trên.
   ===================================================================== */
-- ---- Bep: xem được món cần chế biến, KHÔNG xem được hóa đơn/tiền ----
EXECUTE AS USER = 'usr_bep';
SELECT SUSER_NAME() AS DangChayVoiQuyenCua;
SELECT * FROM vw_MonCanCheBien;                                                  -- ĐƯỢC
BEGIN TRY
    SELECT TOP 1 * FROM HoaDon;                                                  -- BỊ TỪ CHỐI
    PRINT N'LỖI: Bep không được xem HoaDon!';
END TRY
BEGIN CATCH
    PRINT N'Bep xem HoaDon - bị từ chối đúng: ' + ERROR_MESSAGE();
END CATCH
REVERT;
GO

-- ---- PhucVu: mở hóa đơn, gọi món; KHÔNG xem tồn kho, KHÔNG sửa giá, KHÔNG thanh toán ----
EXECUTE AS USER = 'usr_phucvu';
SELECT TOP 3 * FROM vw_MenuDangBan;                                              -- ĐƯỢC
DECLARE @HDp INT;
EXEC sp_MoHoaDon @MaBan = 11, @MaNV = 4, @MaHD = @HDp OUTPUT;                   -- ĐƯỢC
EXEC sp_GoiMon @MaHD = @HDp, @MaMon = 2, @SoLuong = 1;                           -- ĐƯỢC
PRINT N'PhucVu mở bàn 11 và gọi món - thành công.';
BEGIN TRY
    SELECT TOP 1 * FROM NguyenLieu;                                              -- BỊ TỪ CHỐI
    PRINT N'LỖI: PhucVu không được xem NguyenLieu!';
END TRY
BEGIN CATCH
    PRINT N'PhucVu xem NguyenLieu - bị từ chối đúng: ' + ERROR_MESSAGE();
END CATCH
BEGIN TRY
    UPDATE Mon SET GiaBan = 1 WHERE MaMon = 1;                                   -- BỊ TỪ CHỐI
    PRINT N'LỖI: PhucVu không được sửa giá!';
END TRY
BEGIN CATCH
    PRINT N'PhucVu sửa giá món - bị từ chối đúng: ' + ERROR_MESSAGE();
END CATCH
BEGIN TRY
    SELECT TOP 1 * FROM KhachHang;                                               -- BỊ TỪ CHỐI (đã REVOKE)
    PRINT N'LỖI: PhucVu không được xem KhachHang!';
END TRY
BEGIN CATCH
    PRINT N'PhucVu xem KhachHang - bị từ chối đúng: ' + ERROR_MESSAGE();
END CATCH
REVERT;
GO

-- ---- ThuNgan: thanh toán được; sửa giá món bị từ chối ----
EXECUTE AS USER = 'usr_thungan';
DECLARE @HDt INT = (SELECT MaHD FROM HoaDon WHERE MaBan = 9 AND TrangThai = 'DangMo');   -- ĐƯỢC xem HoaDon
DECLARE @TienT DECIMAL(14,0);
EXEC sp_ThanhToan @MaHD = @HDt, @PhuongThucTT = 'The', @SoTienPhaiTra = @TienT OUTPUT;  -- ĐƯỢC
SELECT @TienT AS ThuNganThanhToanBan9_SoTien;
BEGIN TRY
    UPDATE Mon SET GiaBan = 1 WHERE MaMon = 1;                                   -- BỊ TỪ CHỐI (DENY)
    PRINT N'LỖI: ThuNgan không được sửa giá!';
END TRY
BEGIN CATCH
    PRINT N'ThuNgan sửa giá món - bị từ chối đúng: ' + ERROR_MESSAGE();
END CATCH
BEGIN TRY
    EXEC sp_NhapKho @MaNCC = 1, @MaNV = 1, @MaNL = 1, @SoLuong = 1, @DonGiaNhap = 1000;  -- BỊ TỪ CHỐI
    PRINT N'LỖI: ThuNgan không được nhập kho!';
END TRY
BEGIN CATCH
    PRINT N'ThuNgan nhập kho - bị từ chối đúng: ' + ERROR_MESSAGE();
END CATCH
REVERT;
GO

-- ---- QuanLy: xem tồn kho, doanh thu; KHÔNG sửa dữ liệu, KHÔNG mở hóa đơn ----
EXECUTE AS USER = 'usr_quanly';
SELECT * FROM vw_TonKhoThap;                                                     -- ĐƯỢC
EXEC sp_BaoCaoDoanhThu @TuNgay = '2025-03-01', @DenNgay = '2025-03-03';          -- ĐƯỢC
BEGIN TRY
    UPDATE NguyenLieu SET TonKho = 0 WHERE MaNL = 1;                             -- BỊ TỪ CHỐI (DENY UPDATE)
    PRINT N'LỖI: QuanLy không được sửa dữ liệu!';
END TRY
BEGIN CATCH
    PRINT N'QuanLy sửa tồn kho - bị từ chối đúng: ' + ERROR_MESSAGE();
END CATCH
BEGIN TRY
    DECLARE @HDq INT;
    EXEC sp_MoHoaDon @MaBan = 12, @MaNV = 1, @MaHD = @HDq OUTPUT;               -- BỊ TỪ CHỐI (không có quyền EXECUTE)
    PRINT N'LỖI: QuanLy không được mở hóa đơn!';
END TRY
BEGIN CATCH
    PRINT N'QuanLy mở hóa đơn - bị từ chối đúng: ' + ERROR_MESSAGE();
END CATCH
REVERT;
GO

/* =====================================================================
   PHẦN D - SAO LƯU VÀ PHỤC HỒI (Full + Differential), phục hồi vào CSDL MỚI
   Chạy cả phần này trong MỘT lần (từ DECLARE đến hết). File sao lưu nằm ở thư mục Backup mặc định.
   ===================================================================== */
DECLARE @ThuMucBackup NVARCHAR(260), @DuongDanData NVARCHAR(260), @DuongDanLog NVARCHAR(260);
DECLARE @FileFull NVARCHAR(400), @FileDiff NVARCHAR(400), @Sql NVARCHAR(MAX);

EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
     N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', @ThuMucBackup OUTPUT;
SET @DuongDanData = CONVERT(NVARCHAR(260), SERVERPROPERTY('InstanceDefaultDataPath'));
SET @DuongDanLog  = CONVERT(NVARCHAR(260), SERVERPROPERTY('InstanceDefaultLogPath'));
SET @FileFull = @ThuMucBackup + N'\QuanLyNhaHang_Full.bak';
SET @FileDiff = @ThuMucBackup + N'\QuanLyNhaHang_Diff.bak';

-- 1) Sao lưu FULL
BACKUP DATABASE QuanLyNhaHang TO DISK = @FileFull WITH INIT, CHECKSUM, NAME = N'QuanLyNhaHang - Full';
PRINT N'Đã sao lưu Full: ' + @FileFull;

-- 2) Đổi dữ liệu SAU bản Full để chứng minh bản Differential ghi nhận phần thay đổi
INSERT INTO KhachHang (HoTen, SDT, DiemTichLuy) VALUES (N'Khách sau bản Full', '0900777777', 0);

-- 3) Sao lưu DIFFERENTIAL
BACKUP DATABASE QuanLyNhaHang TO DISK = @FileDiff WITH DIFFERENTIAL, INIT, CHECKSUM, NAME = N'QuanLyNhaHang - Diff';
PRINT N'Đã sao lưu Differential: ' + @FileDiff;

-- 4) Xóa CSDL phục hồi cũ (nếu có)
IF DB_ID(N'QuanLyNhaHang_Restore') IS NOT NULL
BEGIN
    ALTER DATABASE QuanLyNhaHang_Restore SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE QuanLyNhaHang_Restore;
END

-- 5) Phục hồi Full (NORECOVERY) rồi Differential (RECOVERY) vào CSDL mới QuanLyNhaHang_Restore
SET @Sql = N'RESTORE DATABASE QuanLyNhaHang_Restore FROM DISK = N''' + @FileFull + N'''
             WITH MOVE N''QuanLyNhaHang_Data'' TO N''' + @DuongDanData + N'QuanLyNhaHang_Restore.mdf'',
                  MOVE N''QuanLyNhaHang_Log''  TO N''' + @DuongDanLog  + N'QuanLyNhaHang_Restore.ldf'',
                  NORECOVERY;';
EXEC (@Sql);
SET @Sql = N'RESTORE DATABASE QuanLyNhaHang_Restore FROM DISK = N''' + @FileDiff + N''' WITH RECOVERY;';
EXEC (@Sql);

-- 6) Kiểm chứng: CSDL mới có đủ dữ liệu, kể cả dòng thêm sau bản Full
SELECT (SELECT COUNT(*) FROM QuanLyNhaHang.dbo.HoaDon)          AS HoaDon_GoC,
       (SELECT COUNT(*) FROM QuanLyNhaHang_Restore.dbo.HoaDon)  AS HoaDon_PhucHoi,
       (SELECT COUNT(*) FROM QuanLyNhaHang_Restore.dbo.KhachHang WHERE SDT = '0900777777') AS KhachSauBanFull_PhaiLa1;
GO

/* =====================================================================
   PHẦN E - PHƯƠNG ÁN TÍNH SẴN SÀNG CAO (HA) - tóm tắt, không bắt buộc triển khai
   (Nhóm chép vào báo cáo và viết thêm cho đủ khoảng một trang)
   ---------------------------------------------------------------------
   Bối cảnh: chuỗi nhà hàng/quán cà phê; ca bán hàng cao điểm 7h-23h; nếu hệ thống POS ngừng,
   quầy không lập được hóa đơn nên gây mất doanh thu trực tiếp.
   Yêu cầu đề xuất: RPO (mất dữ liệu tối đa) ~ 0-5 phút; RTO (thời gian khôi phục) < 15 phút.

   Phương án 1 (khuyến nghị): Always On Availability Group, 2 node đồng bộ (synchronous commit) cùng
     chi nhánh/trung tâm dữ liệu + 1 bản sao bất đồng bộ ở vị trí khác. Tự động chuyển dự phòng (failover),
     RPO = 0, RTO vài chục giây. Bản sao phụ có thể đọc (readable secondary) để chạy báo cáo doanh thu, giảm tải
     cho máy chính. Nhược điểm: cần bản SQL Server Enterprise (hoặc Basic AG trên Standard, giới hạn 1 CSDL) và Windows Failover Cluster.
   Phương án 2 (chi phí thấp): Log Shipping - sao lưu log mỗi 5 phút, gửi sang máy dự phòng và phục hồi liên tục.
     RPO ~ 5 phút, RTO ~ 10-15 phút (chuyển đổi thủ công). Dùng được trên bản Standard. Phù hợp quán nhỏ.
   Phương án 3 (nền tảng bắt buộc cho mọi phương án): lịch sao lưu Full hằng đêm + Differential 4 giờ/lần
     + Log 15 phút/lần (cần SQL Server Agent job), lưu bản sao ra ổ/đám mây khác, thử phục hồi định kỳ.
   Lý do chọn: dữ liệu giao dịch bán hàng phát sinh liên tục nên cần RPO nhỏ; mô hình FULL recovery đã bật ở file 01
     cho phép sao lưu log. Với quy mô 1 quán, Log Shipping + sao lưu là đủ; với chuỗi nhiều chi nhánh nên dùng Always On AG.
   ===================================================================== */

/* =====================================================================
   PHẦN F - ĐIỂM CỘNG: CHE DỮ LIỆU ĐỘNG (Dynamic Data Masking)
   Số điện thoại khách hàng và nhân viên chỉ hiện đầy đủ với người có quyền UNMASK (QuanLy, sysadmin).
   Thu ngân, phục vụ... vẫn đọc được bảng nhưng thấy số điện thoại đã bị che.
   Lưu ý: che dữ liệu chỉ ẩn khi hiển thị, KHÔNG thay cho phân quyền (GRANT/DENY ở phần B vẫn cần).
   Hàm che 'partial(3,"XXXX",3)': giữ 3 ký tự đầu, 3 ký tự cuối, ở giữa thay bằng XXXX.
   ===================================================================== */
ALTER TABLE KhachHang ALTER COLUMN SDT ADD MASKED WITH (FUNCTION = 'partial(3,"XXXX",3)');
ALTER TABLE NhanVien  ALTER COLUMN SDT ADD MASKED WITH (FUNCTION = 'partial(3,"XXXX",3)');
GO

-- QuanLy được xem số điện thoại thật; các vai trò khác không có quyền UNMASK nên thấy dữ liệu bị che
GRANT UNMASK TO QuanLy;
GO

-- Danh sách cột đang được che
SELECT OBJECT_NAME(object_id) AS Bang, name AS Cot, masking_function AS HamChe
FROM sys.masked_columns
ORDER BY Bang, Cot;
GO

-- Kiểm chứng: cùng một câu SELECT nhưng mỗi người thấy khác nhau
-- (1) ThuNgan: SDT bị che thành dạng 090XXXX001
EXECUTE AS USER = 'usr_thungan';
SELECT TOP 3 MaKH, HoTen, SDT FROM KhachHang ORDER BY MaKH;
REVERT;
GO
-- (2) QuanLy: có UNMASK nên thấy số thật
EXECUTE AS USER = 'usr_quanly';
SELECT TOP 3 MaKH, HoTen, SDT FROM KhachHang ORDER BY MaKH;
REVERT;
GO
-- (3) Tài khoản sysadmin đang chạy script cũng thấy số thật
SELECT TOP 3 MaKH, HoTen, SDT FROM KhachHang ORDER BY MaKH;
GO

SET NOEXEC OFF;
GO
GO

/* ================= BẮT ĐẦU FILE 08_ToiUu.sql ================= */
GO
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
GO

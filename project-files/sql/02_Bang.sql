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

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

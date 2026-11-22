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

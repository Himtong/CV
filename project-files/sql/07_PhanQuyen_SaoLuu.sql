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

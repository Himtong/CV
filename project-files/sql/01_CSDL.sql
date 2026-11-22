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

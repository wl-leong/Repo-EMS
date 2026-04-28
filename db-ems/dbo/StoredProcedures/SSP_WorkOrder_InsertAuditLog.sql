-- =============================================
-- Author:		  WL Leong
-- Create date: 2025-09-01
-- Description:	Logging
-- Used By:		

-- History: * Put the latest change on the top
-- DATE         VERSION #   NAME        DESCRIPTION
-- 2025-09-01	1.0         WL Leong	Initial version
-- =============================================
-- EXEC  SSP_WorkOrder_UpdateTargetCompleteDate 123, '2025-06-30', 1
-- select * from workOrderHeader
CREATE PROCEDURE [dbo].[SSP_WorkOrder_InsertAuditLog]
@workOrderHeaderId BIGINT,
@revision INT,
@logAction NVARCHAR(MAX), 
@userId INT
AS
BEGIN
	INSERT INTO history.workOrderAuditLog(workOrderHeaderId, revision, actionLog, userId, changeDateTime)
	SELECT @workOrderHeaderId, @revision, @logAction, @userId, getdate()

END

GO


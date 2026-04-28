-- =============================================
-- Author:		  WL Leong
-- Create date: 2025-07-20
-- Description:	Update Target Complete Date for each work order
-- Used By:		

-- History: * Put the latest change on the top
-- DATE         VERSION #   NAME        DESCRIPTION
-- 2025-09-01   3.0         WL Leong	Audit Log
-- 2025-08-18   2.0         ZY Wong     Standardize sp
-- 2025-07-20	1.0         WL Leong	Initial version
-- =============================================
-- EXEC  SSP_WorkOrder_UpdateTargetCompleteDate 123, '2025-07-30', 1
-- select * from workOrderHeader
-- select * from history.workOrderAuditLog
CREATE PROCEDURE [dbo].[SSP_WorkOrder_UpdateTargetCompleteDate]
@workOrderHeaderId BIGINT,
@NewTargetDate DATE,
@userId INT
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;

    BEGIN TRY

        DECLARE @errMessage VARCHAR(MAX);

        IF ISNULL(@NewTargetDate, '') = ''
        BEGIN
            SET @errMessage = 'Empty target date is not allowed.';
            THROW 60000, @errMessage, 1;
        END

        BEGIN TRANSACTION

            -- Update the target complete date in the work order line items
            DECLARE @updated TABLE (workOrderHeaderId BIGINT, workOrderName VARCHAR(50), oldDate DATE, newDate DATE, revision INT);
            DECLARE @workOrderName VARCHAR(50);

            UPDATE workOrderHeader SET  
                targetCompleteDate  = @NewTargetDate,
                updateDate = getdate(),
                updateBy = @userId,
				revision = revision + 1
            OUTPUT INSERTED.workOrderHeaderId, INSERTED.workOrderName, DELETED.targetCompleteDate, INSERTED.targetCompleteDate, INSERTED.revision
            INTO @updated
            WHERE workOrderHeaderId = @workOrderHeaderId

            SELECT @workOrderName = workOrderName
            FROM @updated

            IF @workOrderName IS NULL
            BEGIN
                SET @errMessage = 'No WO# records found with the specified ID.';
                THROW 60000, @errMessage, 1;
            END

			DECLARE @logAction NVARCHAR(MAX), @revision INT

			SET @revision = (SELECT MAX(revision) FROM @updated);

			SET @logAction = 
				(SELECT 'TargetCompleteDate' as field,
				  FORMAT(i.oldDate, 'yyyy-MM-ddTHH:mm:ssZ') AS [oldValue],
				  FORMAT(i.newDate, 'yyyy-MM-ddTHH:mm:ssZ') AS [newValue]
				FROM @updated i
				FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)

			EXEC dbo.SSP_WorkOrder_InsertAuditLog
				@workOrderHeaderId,
				@revision,
				@logAction, 
				@userId

        COMMIT TRANSACTION

        SET @errMessage = 'WO# ' + @workOrderName + ', target complete date success updated.'

        SELECT '_SUCCESS_' as status, @errMessage as returnMessage

        RETURN 0

    END TRY

    BEGIN CATCH

		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 

        IF @errMessage IS NULL
            SET @errMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE();

        SELECT '_FAILURE_' as status, @errMessage as returnMessage 

        RETURN -1

    END CATCH

END

GO


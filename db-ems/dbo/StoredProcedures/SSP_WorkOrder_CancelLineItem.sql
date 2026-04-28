-- =============================================
-- Author:		  WL Leong
-- Create date: 2025-07-20
-- Description:	Update Target Complete Date for each work order
-- Used By:		

-- History: * Put the latest change on the top
-- DATE         VERSION #   NAME        DESCRIPTION
-- 2025-09-01   3.0         WL Leong	Audit Log
-- 2025-08-18   2.0         ZY Wong     Standardize sp
-- 2025-07-20	1.0			WL Leong	Initial version
-- =============================================
-- EXEC [SSP_WorkOrder_CancelLineItem] 335, 1, 'testing bla blar blar'
CREATE PROCEDURE [dbo].[SSP_WorkOrder_CancelLineItem]
@workOrderLineItemId BIGINT,
@userId INT, 
@note VARCHAR(200)
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;

    BEGIN TRY

        DECLARE @errMessage VARCHAR(MAX);
  
        -- check @note is empty
        IF ISNULL(@note,'') = ''
        BEGIN
            SET @errMessage = 'Note is compulsory.';
            THROW 60000, @errMessage, 1; 
        END

        BEGIN TRANSACTION

             DECLARE @updated TABLE (soLineItemId BIGINT, oldQty INT, newQty INT, workOrderName VARCHAR(50), invId BIGINT, workOrderHeaderId INT);
            DECLARE @soLineItemId BIGINT, @updatedQty INT, @workOrderName VARCHAR(50), @invId INT, @workOrderHeaderId BIGINT;

            -- 1. Update the status of the line item to 'Cancelled'
            UPDATE workOrderLineItem SET 
                confirmQty = 0,
                workOrderItemNote = CASE WHEN ISNULL(@note,'') = '' THEN workOrderItemNote ELSE 
                        CASE WHEN ISNULL(workOrderItemNote,'') = '' THEN @note ELSE workOrderItemNote + ', ' + @note END
                        END,
                workOrderItemStatus = 5236, --cancel
                updateDate = GETDATE(),
                updateBy   = @userId
            OUTPUT INSERTED.soLineItemId, DELETED.confirmQty, INSERTED.confirmQty, INSERTED.workOrderName, INSERTED.invId, INSERTED.workOrderHeaderId 
            INTO @updated
            WHERE workOrderLineItemId = @workOrderLineItemId

            -- 2. Check if the update was successful
            SELECT TOP 1 @soLineItemId = soLineItemId, @updatedQty = newQty, @workOrderName = workOrderName, @invId = invId, @workOrderHeaderId = workOrderHeaderId
            FROM @updated

            IF @soLineItemId IS NULL
            BEGIN
                SET @errMessage = 'No line item found with the specified ID.';
                THROW 60000, @errMessage, 1;
            END

            UPDATE soLineItem  WITH (UPDLOCK, HOLDLOCK, ROWLOCK) SET 
                processQty = processQty - @updatedQty,
                updateDate = GETDATE(),
                updateBy   = @userId
            WHERE soLineItemId = @soLineItemId 

			UPDATE workOrderHeader  WITH (UPDLOCK, HOLDLOCK, ROWLOCK) SET 
				revision = revision + 1,
				updateDate = getdate(),
				updateBy = @userId
			WHERE workOrderHeaderId = @workOrderHeaderId

			DECLARE @logAction NVARCHAR(MAX), @revision INT

			SET @revision = (SELECT revision FROM workOrderHeader WHERE workOrderHeaderId = @workOrderHeaderId);

			SET @logAction = 
				(SELECT 'CancelItem' as field,
				  @workOrderLineItemId as workOrderLineItemId,
				  i.oldQty AS [oldValue],
				  i.newQty  AS [newValue]
				FROM @updated i
				FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)

			EXEC dbo.SSP_WorkOrder_InsertAuditLog
				@workOrderHeaderId,
				@revision,
				@logAction, 
				@userId

        COMMIT TRANSACTION

        DECLARE @inventorySku VARCHAR(50) = (SELECT inventorySku FROM md_Inventory where invId = @invId);

        SET @errMessage = 'WO# ' + @workOrderName + ', item ' + @inventorySku + ' success canceled.';

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


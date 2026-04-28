-- =============================================
-- Author:		WL Leong
-- Create date: 2025-07-20
-- Description:	Update Target Complete Date for each work order
-- Used By:		

-- History: * Put the latest change on the top
-- DATE         VERSION #   NAME        DESCRIPTION
-- 2025-09-01   4.0         WL Leong	Audit Log
-- 2025-08-22   3.0         WL Leong	Get confirmQty different and update soLineItem
-- 2025-08-18   2.0         ZY Wong     Standardize sp
-- 2025-07-20	1.0			WL Leong	Initial version
-- =============================================
-- select * from workOrderLineItem where workOrderlineItemId = 335
-- select * from workOrderHeader where workOrderHeaderId = 24
-- select * from history.workOrderAuditLog  
-- EXEC [SSP_WorkOrder_UpdateConfirmQty] 335, 410, 302, 'note', 1

CREATE PROCEDURE [dbo].[SSP_WorkOrder_UpdateConfirmQty]
@workOrderLineItemId BIGINT,
@workOrderQty INT,
@confirmQty INT,
@note VARCHAR(200),
@userId INT
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

        -- check @confirmQty > @workOrderQty
        IF @confirmQty > @workOrderQty
        BEGIN
            SET @errMessage = 'Confirm Qty cannot be greater than WO Qty.';
            THROW 60000, @errMessage, 1;
        END

        BEGIN TRANSACTION

            -- update qty
            UPDATE workOrderLineItem SET 
                qty = @workOrderQty,
				workOrderItemNote = CASE WHEN ISNULL(workOrderItemNote,'') = '' THEN '' ELSE workOrderItemNote + ', ' END + @note,
                updateDate = GETDATE(),
                updateBy   = @userId
            WHERE workOrderLineItemId = @workOrderLineItemId
                AND qty <> @workOrderQty

            -- update confirmQty
            DECLARE @updated TABLE (soLineItemId BIGINT, oldQty INT, newQty INT, workOrderName VARCHAR(50), invId BIGINT, workOrderHeaderId INT);
            DECLARE @soLineItemId BIGINT, @updatedQty INT, @workOrderName VARCHAR(50), @invId BIGINT, @workOrderheaderId BIGINT;
			DECLARE @changedQty INT

			SET @changedQty = (SELECT confirmQty FROM workOrderLineItem WHERE workOrderLineItemId = @workOrderLineItemId) - @confirmQty

            UPDATE workOrderLineItem SET 
                confirmQty = @confirmQty,
				workOrderItemNote = CASE WHEN ISNULL(workOrderItemNote,'') = '' THEN '' ELSE workOrderItemNote + ', ' END + @note,
                updateDate = GETDATE(),
                updateBy   = @userId
            OUTPUT INSERTED.soLineItemId, DELETED.confirmQty, INSERTED.confirmQty, INSERTED.workOrderName, INSERTED.invId, INSERTED.workOrderHeaderId 
            INTO @updated
            WHERE workOrderLineItemId = @workOrderLineItemId
 
            -- check if the update was successful
            SELECT TOP 1 @soLineItemId = soLineItemId, @updatedQty = newQty, @workOrderName = workOrderName, @invId = invId, @workOrderHeaderId = workOrderHeaderId 
            FROM @updated

            IF @soLineItemId IS NULL
            BEGIN
                SET @errMessage = 'No line item found with the specified ID.';
                THROW 60000, @errMessage, 1;
            END

            UPDATE soLineItem  WITH (UPDLOCK, HOLDLOCK, ROWLOCK) SET 
                processQty = processQty - @changedQty,
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
				(SELECT 'UpdateConfirmQty' as field,
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

        SET @errMessage = 'WO# ' + @workOrderName + ', item ' + @inventorySku + ' success updated.';

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


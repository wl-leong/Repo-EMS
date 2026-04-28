-- =============================================
-- Author:		WL Leong
-- Create date: 2023-06-08
-- Used By:	    EMS -> SO Module -> SO Listing -> Cancel SO
--				EMS -> PI Module -> PI Listing -> Cancel PI

-- Description : Cancel SO/PI 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-01-31	4.0			ZY Wong		Remove send email part, update apiStatus = '_CXL_'
-- 2024-01-25	3.0			WL Leong	Reopen status and cancel, update po to draft
-- 2024-01-22	2.0			ZY Wong		Add XACT_ABORT
-- 2023-06-08	1.0			WL Leong	Initial
-- ==========================================================================================
 --EXEC SSP_SalesOrder_CancelOrder 20441, 1
CREATE PROCEDURE [dbo].[SSP_SalesOrder_CancelOrder]
@soHeaderId BIGINT,
@reason VARCHAR(500),
@updateBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
--1105	Open SO
--1106	Confirm SO
--1107	Cancel SO
--1108	Close SO
		DECLARE @poQty INT = 0
		DECLARE @soName VARCHAR(50) = ''
		DECLARE @soStatus INT

		SELECT @soName = soName, @soStatus = soStatus
		FROM soHeader
		WHERE soHeaderId = @soHeaderId 

		IF @soStatus = 1108
		BEGIN
			SELECT '_ALERT_' as status, 'SO/PI# ' +  @soName + '  is/are already closed' AS returnMessage 

			RETURN -1
		END

		IF @soStatus = 1107
		BEGIN
			SELECT '_ALERT_' as status, 'SO/PI# ' +  @soName + '  is/are already canceled' AS returnMessage 

			RETURN -1
		END

		SELECT @poQty = ISNULL(SUM(poQty), 0)
		FROM soLineItem 
		WHERE soHeaderId = @soHeaderId
			AND soLineItemStatus <> 1107
 
 		BEGIN TRANSACTION
			IF @poQty = 0
			BEGIN
				UPDATE soHeader SET
					soStatus = 1107,
                    soNote = (CASE WHEN LEN(soNote) > 0 THEN soNote + '|' ELSE '' END) + @reason,
					apiStatus = '_CXL_',
					updateBy = @updateBy,
					updateDate = getdate()
				WHERE soHeaderId = @soHeaderId

				UPDATE soLineItem SET
					soLineItemStatus = 1107,
					updateBy = @updateBy,
					updateDate = getdate()
				WHERE  soHeaderId = @soHeaderId
				
				DECLARE @poCancel  TABLE (poHeaderId BIGINT);

  				UPDATE po SET
					poStatus = 1086,
					poCancelDate = getdate(),
					poCancelBy = @updateBy
				OUTPUT INSERTED.poId 
				INTO @poCancel 
				FROM  poHeader po
				WHERE po.poStatus = 2143	
					AND  po.poReferenceId = @soName
 
				UPDATE pol SET
					itemStatus = 1086,
					updateDate = getdate(),
					updateBy = @updateBy
				FROM poLineItem pol	
					INNER JOIN @poCancel p
						ON pol.poId = p.poHeaderId
				WHERE pol.itemStatus = 2143

				SELECT '_SUCCESS_' as status, 'SO/PI# '+ @soName + ' is canceled' AS returnMessage 
 			END
			ELSE
			BEGIN
				SELECT '_ALERT_' as status, 'SO/PI# ' + @soName + ' has raised PO, please cancel the PO before cancel the SO/PI' AS returnMessage 

				ROLLBACK TRANSACTION

				RETURN -1
			END

		COMMIT TRANSACTION

		RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 
 
		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as errorMessage

		RETURN -1
	END CATCH
END

GO


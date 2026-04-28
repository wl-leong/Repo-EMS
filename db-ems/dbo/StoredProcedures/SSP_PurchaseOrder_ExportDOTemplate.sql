-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-04-23
-- Used By:	    EMS -> PO Module -> PO Listing -> (status: Released) Export DO Template

-- Description : Export Released PO to DO template for user to upload in 'GRN -> Import'

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-04-23	1.0			ZY Wong 	Initial
-- ==========================================================================================
-- EXEC [SSP_PurchaseOrder_ExportDOTemplate] 9
CREATE PROCEDURE [dbo].[SSP_PurchaseOrder_ExportDOTemplate]
@poId BIGINT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY

            --DECLARE @poId BIGINT = 9

            DECLARE @ErrMessage VARCHAR(MAX);

            DROP TABLE IF EXISTS #poList;

            SELECT poName, poStatus
            INTO #poList
            FROM poHeader 
            WHERE poId = @poId

            IF (SELECT COUNT(1) FROM #poList WHERE poStatus NOT IN (1077)) > 0
            BEGIN
                SET @ErrMessage = (SELECT 'PO # ' + poName + ' not in RELEASED status are not able to export.' FROM #poList);
			    THROW 60000, @ErrMessage, 1;
            END

            DROP TABLE IF EXISTS #poItem;

            SELECT supplierSku, qty
            INTO #poItem
            FROM poLineItem 
            WHERE poId = @poId
                AND itemStatus = 1077 -- released

            DROP TABLE IF EXISTS #summary;

            SELECT poName, supplierSku, qty
            INTO #summary
            FROM #poList, #poItem

            DECLARE @todayDate VARCHAR(10) = (SELECT CONVERT(DATE, getdate()));

            SELECT TOP 1 'DO' as recordType, '' as doNo, @todayDate as column2, '' as column3, '' as column4, '' as column5, '' as column6
            FROM #summary
            UNION ALL
            SELECT 'DL' as recordType, '' as doNo, poName, '' as warehouseLabel, supplierSku, CAST(qty as varchar), '' as note
            FROM #summary

            RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0)
		BEGIN
			ROLLBACK TRANSACTION 
		END 

		IF (XACT_STATE()) = 1  
		BEGIN  
			COMMIT TRANSACTION ;     
		END;  

        IF @ErrMessage IS NULL 
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE()
 
		SELECT
			'_FAILURE_' as status, @ErrMessage as returnMessage

		RETURN -1
	END CATCH
END

GO



-- =============================================
-- Author:		WL Leong
-- Create date: 2024-04-01
-- Used By:	    EMS -> PO Module -> export Po

-- Description : 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-04-02	2.0			WL Leong	change to use JSon
-- 2024-04-01	1.0			WL Leong	Initial
-- ==========================================================================================

 --[dbo].[SSP_PurchaseOrder_ExportPOPdfItems] 10105, 1, 15
CREATE PROCEDURE [dbo].[SSP_PurchaseOrder_ExportPOPdfItems]
@json VARCHAR(MAX)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON;
	BEGIN TRY
		DECLARE @RaiseMessage VARCHAR(1000);

		DROP TABLE IF EXISTS #pdfInfo;

		SELECT poId, rowStart, rowEnd
		INTO #pdfInfo
		FROM  OPENJSON(@json) 
   			WITH (
				poId BIGINT			N'$.poId',
				rowStart INT		N'$.rowStart',
				rowEnd INT			N'$.rowEnd'
			)

		DECLARE @poId BIGINT, @rowStart INT, @rowEnd INT

		SELECT TOP 1 @poId = poId, @rowStart = rowStart, @rowEnd = rowEnd
		FROM #pdfInfo

		IF @poId IS NULL
		BEGIN

			SELECT '_ALERT_' as status, 'PO# pass in is invalid' AS returnMessage 

			RETURN -1
		END

		DROP TABLE IF EXISTS #order;

		SELECT 'TH' as rowType, supplierSku, SUM(qty) as qty, unitPrice, SUM(qty) * unitPrice as totalCost, ROW_NUMBER() OVER(ORDER BY supplierSku) as itemNo
		INTO #order
		FROM poLineItem 
		WHERE poId = @poId
		GROUP BY supplierSku, unitPrice

		DROP TABLE IF EXISTS #poLineItem;

		SELECT supplierSku, qty, soheaderId
		INTO #poLineItem
		FROM poLineItem p
			inner join soLineItem s
				ON p.soLineItemId = s.soLineItemId
		where poId = @poId
 
		DROP TABLE IF EXISTS #remarks;

		SELECT 'TL' as rowType, p.supplierSku, soName + ' *' + CAST(p.qty as VARCHAR) as remarks, itemNo
		INTO #remarks
		FROM #poLineItem p
			INNER JOIN soHeader s
				ON p.soHeaderID = s.soHeaderId
			INNER JOIN #order o
				ON p.supplierSKu = o.supplierSku
			 
		SELECT rowType, itemNo, supplierSku, qty, unitPrice, totalCost
		FROM #order
		WHERE itemNo BETWEEN @rowStart AND @rowEnd
		UNION
		SELECT rowType, itemNo, remarks, null, null, null
		FROM #remarks
		WHERE itemNo BETWEEN @rowStart AND @rowEnd

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
 
		SET @RaiseMessage =  ERROR_MESSAGE();

		SELECT '_FAILURE_' as execStatus, 'SSP_PurchaseOrder_ExportPOPdfItems : ' + @RaiseMessage as execMessage
	END CATCH
END

GO


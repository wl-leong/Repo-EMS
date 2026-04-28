
--1105	Open
--1106	Confirm
--1107	Cancel
--1108	Close

-- =============================================
-- Author:		WL Leong
-- Create date: 2024-03-09
-- Used By:	    EMS -> PO Module -> PO Rate Check

-- Description : Once foreign currency is changed, unit price is updated

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-03-21	2.0			WL Leong	Change supplierCost to homeCurrencyCost
-- 2024-03-09	1.0			WL Leong	Initial
-- ==========================================================================================
 
 --[dbo].[SSP_PurchaseOrder_UpdateItemCost] N'{"priceList":[{"poId":"39", "currencyRate":"4.6589"}]}', 1
CREATE PROCEDURE [dbo].[SSP_PurchaseOrder_UpdateItemCost]
@priceJson VARCHAR(MAX), 
@updateBy INT
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON;
	BEGIN TRY
		DECLARE @RaiseMessage varchar(max)

		DROP TABLE IF EXISTS #priceList                                
			
		SELECT poId, poDetailsId, unitCost
		INTO #priceList
		FROM  OPENJSON(@priceJson, '$.priceList') 
   			WITH (
                poId BIGINT	                N'$.poId',
				poDetailsId BIGINT	        N'$.poDetailsId',
				unitCost NUMERIC(14,4)	    N'$.unitCost'
			)
		
		IF (SELECT COUNT(1) FROM #priceList) > 0
		BEGIN
 			BEGIN TRANSACTION

			DECLARE @poId BIGINT, @poDetailsId BIGINT, @unitCost NUMERIC(14,4), @foreignCurrencyRate NUMERIC(14,6)

			SELECT TOP 1 @poId = poId, @poDetailsId = poDetailsId, @unitCost = unitCost
			FROM #priceList

            SELECT @foreignCurrencyRate = foreignCurrencyRate
            FROM poHeader
            WHERE poId = @poId

			UPDATE poLineItem SET
                unitPrice = @unitCost,
				homeCurrencyCost = @unitCost * @foreignCurrencyRate, 
                updateDate = getdate(),
                updateBy = @updateBy
			WHERE poDetailsId = @poDetailsId
 
			DECLARE @netTotal NUMERIC(18,4)

			SELECT @netTotal = SUM(unitPrice) 
			FROM poLineItem
			WHERE itemStatus <> 1086
				AND poId = @poId

			UPDATE poHeader SET
				poNetTotal = ISNULL(@netTotal, 0),
				poGrossTotal = ISNULL(@netTotal, 0) + ISNULL(poTax, 0) - ISNULL(poDiscount, 0),
				lastUpdatedDate = getdate(),
				updateBy = @updateBy
			WHERE poId = @poId	

			COMMIT TRANSACTION
		END
		ELSE
		BEGIN
			SELECT '_ALERT_' as status, 'No unit cost been updated '  as returnMessage

			RETURN -1
		END

		SELECT '_SUCCESS_' as status, 'Unit Cost has updated, PO Amount is being refreshed'  as returnMessage
 
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
 
		SET @RaiseMessage =  ERROR_MESSAGE();

		SELECT '_FAILURE_' as status, 'SSP_PurchaseOrder_UpdateItemCost : ' + @RaiseMessage as returnMessage
	END CATCH
END

GO



--1105	Open
--1106	Confirm
--1107	Cancel
--1108	Close

-- =============================================
-- Author:		WL Leong
-- Create date: 2023-08-28
-- Used By:	    EMS -> PO Module -> PO Received

-- Description : Received the delivery order and increase inventory warehouse

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-04-16	1.0			WL Leong	Initial
-- ==========================================================================================
/**
 EXEC SSP_POReceived_SelectItemDetails 1
 **/
 
CREATE PROCEDURE [dbo].[SSP_POReceived_SelectItemDetails]
@poRcvHeaderId BIGINT
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON;
	BEGIN TRY
		DECLARE @RaiseMessage varchar(max)

		DROP TABLE IF EXISTS #list;

		SELECT poRcvHeaderId,  poRcvLineItemId, poDetailsId, supplierSku, rcvQty, notes, poRcvLineItemStatus
		INTO #list
		FROM poReceivedLineItem 
		WHERE poRcvHeaderId = @poRcvHeaderId
		
        DROP TABLE IF EXISTS #header;

        SELECT poRcvHeaderId, warehouseId
        INTO  #header
        FROM poReceivedHeader
        WHERE poRcvHeaderId = @poRcvHeaderId

		DROP TABLE IF EXISTS #polist;

		SELECT poRcvLineItemId, h.warehouseId, pd.poName, pd.supplierSku, pd.qty as POQty, pd.rcvQty, notes, poRcvLineItemStatus
		INTO #polist
		FROM #list l 
			INNER JOIN poLineItem pd
				ON l.poDetailsId = pd.poDetailsId
            INNER JOIN #header h
                ON l.poRcvHeaderId = h.poRcvHeaderId
 
 
		SELECT poRcvLineItemId, poName, wh.label as warehouse, supplierSku, POQty, rcvQty, notes, mc.categoryName as poItemStatus 
		FROM #polist l
			INNER JOIN md_warehouse wh
				ON l.warehouseId = wh.warehouseId
			INNER JOIN md_MasterCategory mc
				ON l.poRcvLineItemStatus = mc.categoryId


	END TRY

	BEGIN CATCH
 
		SET @RaiseMessage =  ERROR_MESSAGE();

		SELECT '_FAILURE_' as execStatus, 'SSP_OrderProcess_ConvertToPurchaseOrder : ' + @RaiseMessage as execMessage
	END CATCH
END

GO


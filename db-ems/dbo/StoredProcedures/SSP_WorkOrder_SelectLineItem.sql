-- =============================================
-- Author:		  WL Leong
-- Create date: 2025-07-20
-- Description:	Work Order Details
-- Used By:		

-- History: * Put the latest change on the top
-- DATE			  VERSION #	NAME		  DESCRIPTION
-- 2025-07-20	1.0			  WL Leong	Initial version
-- =============================================
-- EXEC  SSP_WorkOrder_SelectLineItem 123
CREATE PROCEDURE [dbo].[SSP_WorkOrder_SelectLineItem]
@workOrderHeaderId BIGINT
AS
BEGIN
  SET NOCOUNT ON
  SET XACT_ABORT ON

    DROP TABLE IF EXISTS #woLineItem;

    SELECT workOrderLineItemId, workOrderName, soHeaderId, soName, soLineItemId, li.invId, inv.inventorySku
      , qty, confirmQty, produceQty  
      , workOrderItemNote, li.workOrderItemStatus, mc.categoryName as itemStatus 
    FROM workOrderLineItem li
        INNER JOIN md_inventory inv
          ON li.invId = inv.invId
        INNER JOIN md_masterCategory mc 
          ON li.workOrderItemStatus = mc.categoryId
    WHERE workOrderHeaderId = @workOrderHeaderId

 

  RETURN 0
END

GO


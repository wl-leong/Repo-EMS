-- =============================================
-- Author:		  WL Leong
-- Create date: 2025-07-20
-- Description:	Work Order Info 
-- Used By:		

-- History: * Put the latest change on the top
-- DATE			  VERSION #	NAME		  DESCRIPTION
-- 2025-07-20	1.0			  WL Leong	Initial version
-- =============================================
-- EXEC  SSP_WorkOrder_SelectHeaderInfo 123
CREATE PROCEDURE [dbo].[SSP_WorkOrder_SelectHeaderInfo]
@workOrderHeaderId BIGINT
AS
BEGIN
  SET NOCOUNT ON
  SET XACT_ABORT ON

    DROP TABLE IF EXISTS #woHeader;

    SELECT workOrderHeaderId, wo.workOrderName, wo.companyId, cs.customerId, cs.customerShortCode, thirdParty, wo.warehouseId, wh.locNo,
      workOrderDate, targetCompleteDate,  shipDate,
      workOrderNote, workOrderStatus, mc.categoryName as woStatus, createBy, createDate, updateBy, updateDate, apiStatus
    INTO #woHeader
    FROM workOrderHeader wo 
        INNER JOIN md_customer cs
          ON wo.customerId = cs.customerId
        INNER JOIN md_masterCategory mc 
          ON wo.workOrderStatus = mc.categoryId
        LEFT JOIN md_warehouse wh 
          ON wo.warehouseId = wh.warehouseId
    WHERE workOrderHeaderId = @workOrderHeaderId

    ALTER TABLE #woHeader ADD createUser VARCHAR(50);
    ALTER TABLE #woHeader ADD updateUser VARCHAR(50);

    UPDATE wo SET 
      createUser = u.userName
    FROM  #woHeader wo
      INNER JOIN md_user u 
        ON wo.createBy = u.userId;
    
    UPDATE wo SET 
      updateUser = u.userName
    FROM  #woHeader wo
      INNER JOIN md_user u 
        ON wo.updateBy = u.userId;

    SELECT workOrderHeaderId, workOrderName, companyId, customerId, customerShortCode, thirdParty, warehouseId, locNo,
      workOrderDate, targetCompleteDate,  shipDate,
      workOrderNote, workOrderStatus, woStatus, createUser, createDate, updateUser, updateDate, apiStatus
    FROM #woHeader;

  RETURN 0
END

GO


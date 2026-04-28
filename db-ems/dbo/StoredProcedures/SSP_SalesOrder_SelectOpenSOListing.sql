-- =============================================
-- Author:		WL Leong
-- Create date: 2023-06-08
-- Used By:	    EMS -> SO Module -> Open SO

-- Description : All Sales Order still remain uncancel/close

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-05-15	1.0			WL Leong	Initial
-- ==========================================================================================
--EXEC SSP_SalesOrder_SelectSOListing 11, 33
  
CREATE PROCEDURE [dbo].[SSP_SalesOrder_SelectOpenSOListing]
@companyId INT,
@customerId INT = 0
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		IF @customerId = 0 
            SET @customerId = NULL
        
        SELECT soHeaderId, customerId, soName, soDate, customerPO, earlyShipDate, lateShipDate, mc.categoryName as soStatus
        FROM soHeader li
            INNER JOIN md_MasterCategory mc
                ON soStatus = mc.categoryId
        WHERE li.soStatus NOT IN (1108, 1107)
            AND li.companyId = @companyId
            AND (customerId = @customerId OR @customerId IS NULL)
        ORDER BY earlyShipDate

 
	END TRY

	BEGIN CATCH
 
 
		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as errorMessage

		RETURN -1
	END CATCH
END

GO


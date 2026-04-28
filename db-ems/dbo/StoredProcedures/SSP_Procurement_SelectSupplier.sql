-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-03-21
-- Description:	Listing of supplier info for specific InvId 
-- Used By:		Procurement Module -> Pending List -> click on raw bom

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-03-21	1.0			ZY Wong		Initial
-- =============================================
-- EXEC [SSP_Procurement_SelectSupplier] 601
CREATE PROCEDURE [dbo].[SSP_Procurement_SelectSupplier] 
@invId BIGINT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
				
		--DECLARE @invId INT = 602
		
		SELECT sku.supplierId, sup.supplierCompanyName, sku.supCost
		FROM md_SupplierSku sku
			INNER JOIN md_Supplier sup
				ON sku.supplierId = sup.supplierId
				AND sup.status = 1
		WHERE sku.invId = @invId
			AND sku.statusFlag = 1
		ORDER BY supCost 

END

GO


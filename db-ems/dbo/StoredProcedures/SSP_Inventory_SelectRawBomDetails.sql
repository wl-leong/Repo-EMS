-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-03-20
-- Used By:	    EMS -> Inventory Module -> Inventory -> Raw Bom

-- Description : List of raw BOM details

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-03-20	1.0			WL Leong	Initial
-- ==========================================================================================
-- EXEC [SSP_Inventory_SelectRawBomDetails] 94
CREATE PROCEDURE [dbo].[SSP_Inventory_SelectRawBomDetails]
@invId BIGINT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
		
		--DECLARE @invId INT = 94;

		SELECT rbom.rawBomInvId, inv.itemCode as rawBomUpc, inv.modelNo, rbom.rawBomQty as rawQty
		FROM rawBom rbom
			INNER JOIN md_Inventory inv
				ON rbom.rawBomInvId = inv.invId
				AND rbom.companyId = inv.companyId
				AND inv.status = 1
		WHERE rbom.invId = @invId

END

GO


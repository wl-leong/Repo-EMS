-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-03-20
-- Used By:	    EMS -> Inventory Module -> Inventory -> Raw Bom

-- Description : List of raw BOM

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-04-08   1.1         ZY Wong     Change column to itemCode
-- 2024-03-20	1.0			ZY Wong		Initial
-- ==========================================================================================
-- EXEC [SSP_Inventory_RawBomListing] 4
CREATE PROCEDURE [dbo].[SSP_Inventory_RawBomListing]
@companyId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
		
		--DECLARE @companyId INT = 4;

		SELECT rbom.invId, inv.itemCode, inv.modelNo, COUNT(rbom.rawBomInvId) as countOfRawBom, 
			CASE WHEN rbom.status = 1 THEN 'Active' ELSE 'InActive' END as status
		FROM rawBom rbom
			INNER JOIN md_inventory inv
				ON rbom.invId = inv.invId
				AND rbom.companyId = inv.companyId
				AND inv.status = 1
		WHERE rbom.companyId = @companyId
		GROUP BY rbom.invId, inv.itemCode, inv.modelNo, CASE WHEN rbom.status = 1 THEN 'Active' ELSE 'InActive' END 

END

GO


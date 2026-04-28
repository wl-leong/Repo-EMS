-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-05-07
-- Used By:	    EMS -> PO Module -> PO Listing -> Export PO pdf ssrs
--
-- Description : Export Purchase Order report
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-05-07	1.0			ZY Wong 	Initial
-- ==========================================================================================
-- [SSP_PurchaseOrder_SSRS_SelectSupplierTerm] 16, 'PO'
CREATE PROCEDURE [dbo].[SSP_PurchaseOrder_SSRS_SelectSupplierTerm]
@poId BIGINT,
@module VARCHAR(3)
AS 
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

    --DECLARE @poId BIGINT = 16, @module VARCHAR(3) = 'PO'

    DROP TABLE IF EXISTS #poInfo;

    SELECT companyId, supplierId
    INTO #poInfo
    FROM poHeader 
    WHERE poId = @poId
    
    SELECT ct.termRow, ct.termCondition
    FROM #poInfo s
        INNER JOIN md_SupplierTerm ct
            ON s.companyId = ct.companyId
            AND s.supplierId = ct.supplierId
            AND ct.module = @module
    WHERE ct.statusFlag = 1

END

GO


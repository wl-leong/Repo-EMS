-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-08-29
-- Description:	Select inventory attribute details
-- Used By:		Inventory > Inventory Catalog

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-08-29	1.0			ZY Wong		Initial version
-- =============================================
-- [SSP_Inventory_SelectInventoryAttribute] 22642
CREATE PROCEDURE [dbo].[SSP_Inventory_SelectInventoryAttribute] 
@invId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

        --DECLARE @invId INT = 22642;

        DROP TABLE IF EXISTS #attributes;

        SELECT attributesId, invId, categoryId, [value] as attributeValue
        INTO #attributes
        FROM inventory_attributes 
        WHERE invId = @invId 

        ALTER TABLE #attributes ADD attributeName VARCHAR(50);

        UPDATE #attributes SET
            attributeName = UPPER(att.categoryName)
        FROM #attributes invatt
            INNER JOIN md_MasterCategory att
                ON invatt.categoryId = att.categoryId
                AND att.status = 1

        SELECT attributesId, invId, attributeName, attributeValue
        FROM #attributes

END

GO


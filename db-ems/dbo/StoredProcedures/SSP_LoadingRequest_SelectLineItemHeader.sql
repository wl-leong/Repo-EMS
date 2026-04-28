-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-04-24
-- Used By:	    EMS -> LR Module -> LR Listing -> View/ Edit -> Loading Request Item
--
-- Description : Get line item info for header part
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-04-24	1.0			WL LEONG    Initial version
-- ==========================================================================================
-- EXEC SSP_LoadingRequest_SelectLineItemHeader 10346,1 
CREATE PROCEDURE [dbo].[SSP_LoadingRequest_SelectLineItemHeader]
@lrHeaderId BIGINT,
@containerSeq INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY	

        --DECLARE @lrHeaderId BIGINT = 10346, @containerSeq INT = 1

        DROP TABLE IF EXISTS #lrContainer;

		SELECT lrContainerId, containerTypeId, containerSeq
		INTO #lrContainer
		FROM lrContainer
		WHERE lrHeaderId = @lrHeaderId
			AND containerSeq = @containerSeq

        ALTER TABLE #lrContainer ADD containerType VARCHAR(50);

        UPDATE #lrContainer SET
            containerType = ct.categoryName
        FROM md_MasterCategory ct
        WHERE #lrContainer.containerTypeId = ct.categoryId
        
		DROP TABLE IF EXISTS #containerItem;

		SELECT invId, qty
		INTO #containerItem
		FROM #lrContainer lr
			INNER JOIN lrLineItem li
				ON lr.lrContainerId = li.lrContainerId

        DROP TABLE IF EXISTS #itemInfo;

        CREATE TABLE #itemInfo (
            containerType VARCHAR(50), 
            dimension VARCHAR(50),
            CBM VARCHAR(50),
            grossWeight VARCHAR(50),
            totalItemCBM VARCHAR(50),
            totalItemGrossWeight VARCHAR(50)
        )

        INSERT INTO #itemInfo (containerType)
        SELECT DISTINCT containerType
        FROM #lrContainer

        DECLARE @containerTypeId INT = (SELECT DISTINCT containerTypeId FROM #lrContainer);

        UPDATE #itemInfo SET
            dimension = mc.attributeValue
        FROM md_MasterCategoryAttribute mc
        WHERE mc.attributeName = 'Dimension'
            AND masterCategoryId = @containerTypeId
 
        UPDATE #itemInfo SET
            CBM = mc.attributeValue
        FROM md_MasterCategoryAttribute mc
        WHERE mc.attributeName = 'cbm'
            AND masterCategoryId = @containerTypeId

        UPDATE #itemInfo SET
            grossWeight = mc.attributeValue
        FROM md_MasterCategoryAttribute mc
        WHERE mc.attributeName = 'Weight'
            AND masterCategoryId = @containerTypeId

 
        SELECT SUM(qty * inv.grossWeight) as itemWeight, 
            SUM(qty * inv.cbm) as iCbm
        INTO #itemAttribute
        FROM #containerItem lr
            INNER JOIN md_Inventory inv
                ON lr.invId = inv.invId
            
        UPDATE #itemInfo SET
            totalItemGrossWeight = itemWeight
        FROM #itemAttribute

        UPDATE #itemInfo SET
            totalItemCBM = iCbm
        FROM #itemAttribute

        SELECT DISTINCT containerType, dimension, cbm, grossWeight, totalItemCBM, totalItemGrossWeight
        FROM #itemInfo

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
 
		DECLARE @ErrMessage VARCHAR(1000)

        IF @ErrMessage IS NULL 
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE()

		SELECT
			'_FAILURE_' as status, @ErrMessage as returnMessage

		RETURN -1
	END CATCH
END

GO


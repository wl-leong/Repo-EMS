-- =============================================
-- Author:		WL Leong
-- Create date: 2024-03-20
-- Used By:	    EMS -> Inventory Module -> Inventory -> Import Raw Bom

-- Description : Import raw BOM from dump table

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-03-20	1.1			ZY Wong		Add in validataion of existing upc will gotta do in rawbom listing page
-- 2024-03-20	1.0			ZY Wong		Initial
-- ==========================================================================================
-- EXEC [SSP_Inventory_InsertRawBomByLog] 4, 'RawBOM_20240403_v1.csv', 1
CREATE PROCEDURE [dbo].[SSP_Inventory_InsertRawBomByLog]
@companyId INT,
@fileName VARCHAR(150),
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		BEGIN TRANSACTION
		
		--DECLARE @companyId INT = 4, @fileName VARCHAR(150) = 'RawBOM_20240403_v1.csv', @userId INT = 1;

		DECLARE @ErrMessage VARCHAR(MAX);

		DROP TABLE IF EXISTS #tempRawBom;

		SELECT upc, rawBomUpc, CONVERT(NUMERIC(18,4), rawBomQty) as rawBomQty
		INTO #tempRawBom
		FROM temp_rawBomLog
		WHERE fileName = @fileName

/*** Start: data validation ***/


		IF (SELECT COUNT(1) FROM #tempRawBom WHERE ISNUMERIC(rawBomQty) = 0) > 0
		BEGIN
			SET @ErrMessage = 'Invalid rawBomQty, not a numeric value.';
			THROW 60000, @ErrMessage, 1;
		END

		DROP TABLE IF EXISTS #existingBom;

		SELECT rb.upc, rb.rawBomUpc
		INTO #existingBom
		FROM rawBom rb
			INNER JOIN #tempRawBom trb
				ON rb.upc = trb.upc

		IF (SELECT COUNT(1) FROM #existingBom) > 0
		BEGIN
			SET @ErrMessage = (SELECT TOP 1 'UPC ' + upc + ' have BOM exists in the system, please go Raw BOM Listing page for further action' FROM #existingBom);
			THROW 60000, @ErrMessage, 1;
		END

		DROP TABLE IF EXISTS #inventory;

		SELECT invId, upc
		INTO #inventory
		FROM md_inventory
		WHERE status = 1
			AND companyId = @companyId

		DROP TABLE IF EXISTS #checkUpc;

		SELECT t.upc
		INTO #checkUpc
		FROM (
			SELECT upc as upc FROM #tempRawBom
			UNION  
			SELECT rawBomUpc as upc FROM #tempRawBom
			) t
			LEFT JOIN #inventory inv
				ON t.upc = inv.upc
		WHERE inv.invId IS NULL

		IF (SELECT COUNT(1) FROM #checkUpc) > 0
		BEGIN
			SET @ErrMessage = (SELECT TOP 1 'UPC ' + upc + ' not yet created' FROM #checkUpc);
			THROW 60000, @ErrMessage, 1;
		END
/*** End: data validation ***/

		DROP TABLE IF EXISTS #rawBomList;

		SELECT inv.invId, inv.upc, rawInv.invid as rawBomInvId, rawInv.upc as rawBomUpc, CONVERT(NUMERIC(13,1), t.rawBomQty) as rawBomQty
		INTO #rawBomList
		FROM #tempRawBom t
			INNER JOIN #inventory inv
				ON t.upc = inv.upc
			INNER JOIN #inventory rawInv
				ON t.rawBomUpc = rawInv.upc

		INSERT INTO rawBom (companyId, invId, upc, rawBomInvId, rawBomUpc, rawBomQty, status, enterBy, enterDate, updateBy, updateDate)	
		SELECT @companyId, invId, upc, rawBomInvId, rawBomUpc, rawBomQty, 1 as status, @userId, getdate(), @userId, getdate()
		FROM #rawBomList
		
		COMMIT TRANSACTION

		DELETE FROM temp_rawBomLog WHERE fileName = @fileName

		SELECT '_SUCCESS_' as status, 'Raw BOM has been successful create' as returnMessage
				
		RETURN 0
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
 
		DELETE FROM temp_rawBomLog WHERE fileName = @fileName

		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as returnMessage

		RETURN -1
	END CATCH
END

GO


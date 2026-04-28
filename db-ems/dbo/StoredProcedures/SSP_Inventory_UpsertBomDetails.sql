-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-03-20
-- Used By:	    EMS -> Inventory Module -> Inventory -> Raw Bom

-- Description : Edit raw bom details (add/delete/update)

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-04-08   1.1         ZY Wong     Change column to itemCode
-- 2024-03-20	1.0			ZY Wong		Initial
-- ==========================================================================================
-- EXEC [SSP_Inventory_UpsertBomDetails] N'{"rawBomList":[{"invId":94,"action":"AddRawBomDetails","rawBomInvId":"605","rawQty":"6"}]}', 1
CREATE PROCEDURE [dbo].[SSP_Inventory_UpsertBomDetails]
@Json VARCHAR(MAX),
@updateBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	
	BEGIN TRY
 
		DECLARE @ErrMessage VARCHAR(MAX);

		--DECLARE @Json VARCHAR(MAX) = 
		--	N'{"rawBomList":[{
		--		"invId":94,
		--		"action":"UpdateRawBomDetails",
		--		"rawBomInvId":"605",
		--		"rawQty":"6"
		--	}]}'

		--DECLARE @updateBy INT = 1;

		DROP TABLE IF EXISTS #rawBomDetails;

		SELECT * 
		INTO #rawBomDetails
		FROM  OPENJSON(@Json, '$.rawBomList') 
   			WITH (
				invId BIGINT					N'$.invId',
				actionType VARCHAR(50)			N'$.action',
				rawBomInvId BIGINT				N'$.rawBomInvId',
				rawBomQty VARCHAR(10)			N'$.rawQty'
			)

		DECLARE @invId BIGINT, @actionType VARCHAR(50), @rawBomInvId BIGINT;

		SELECT @invId = invId, @actionType = actionType, @rawBomInvId = rawBomInvId
		FROM #rawBomDetails

		DROP TABLE IF EXISTS #checkBomExists;

		SELECT DISTINCT rbom.companyId, rbom.rawBomId, d.invId, inv.itemCode, d.rawBomInvId, rinv.itemCode as rawBomUpc, CONVERT(NUMERIC(13,4), d.rawBomQty) as rawBomQty
		INTO #checkBomExists
		FROM #rawBomDetails d
			LEFT JOIN rawBom rbom
				ON rbom.invId = d.invId
				AND rbom.rawBomInvId = d.rawBomInvId
			INNER JOIN md_Inventory inv
				ON d.invId = inv.invId
				AND inv.status = 1
			INNER JOIN md_Inventory rinv
				ON d.rawBomInvId = rinv.invId
				AND rinv.status = 1

		BEGIN TRANSACTION		

		IF @actionType = 'AddRawBomDetails'
		BEGIN
			
			IF (SELECT COUNT(1) FROM #checkBomExists WHERE rawBomId IS NOT NULL) > 0
			BEGIN
				SET @ErrMessage = 'Item already created in Raw BOM';

				THROW 60000, @ErrMessage, 1;
			END
			ELSE
			BEGIN
				INSERT INTO rawBom (companyId, invId, rawBomInvId, rawBomQty, status, enterBy, enterDate, updateBy, updateDate)
				SELECT companyId, invId, rawBomInvId, rawBomQty, 1 as status, @updateBy, getdate(), @updateBy, getdate()
				FROM #checkBomExists
				WHERE rawBomId IS NULL
 						
				SET @ErrMessage = 'Raw BOM Details is successfully added.'
			END
		END

		IF @actionType = 'UpdateRawBomDetails'
		BEGIN
			IF (SELECT COUNT(1) FROM #checkBomExists WHERE rawBomId IS NULL) > 0
			BEGIN
				SET @ErrMessage = 'Item is not found in Raw BOM';

				THROW 60000, @ErrMessage, 1;
			END
			ELSE
			BEGIN
 				UPDATE rbom SET
					rawBomQty = d.rawBomQty, 
					updateBy = @updateBy,
					updateDate = getdate()
				FROM rawBom rbom
					INNER JOIN #checkBomExists d
						ON rbom.invId = d.invId
						AND rbom.rawBomInvId = d.rawBomInvId
				WHERE d.rawBomInvId IS NOT NULL
			
				SET @ErrMessage = 'Raw BOM Details is successfully updated.'
			END
		END

		IF @actionType = 'DeleteRawBomDetails'
		BEGIN
 			DELETE FROM rawBom 
			WHERE rawBomId IN
				(SELECT rawBomId 
				 FROM rawBom rbom
					INNER JOIN #rawBomDetails d
						ON rbom.invId = d.invId
						AND rbom.rawBomInvId = d.rawBomInvId
				)
			
			SET @ErrMessage = 'Raw BOM Details is successfully deleted.'
		END

		COMMIT TRANSACTION
		
        SELECT '_SUCCESS_' as status, @ErrMessage AS returnMessage

        RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END  
 
        IF @ErrMessage IS NULL 
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE()

		SELECT
			'_FAILURE_' as status, @ErrMessage as returnMessage

		RETURN -1
	END CATCH
END

GO


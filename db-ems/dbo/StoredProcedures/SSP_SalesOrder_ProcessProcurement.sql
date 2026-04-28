
-- =============================================
-- Author:		WL Leong
-- Create date: 2024-02-01
-- Used By:	    EMS -> PO Listing -> During Confirm SO

-- Description : 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-02-01	1.0			WL Leong	Initial
-- ==========================================================================================
-- EXEC [SSP_SalesOrder_ProcessProcurement] N'{"soList":[{"soHeaderId":"30880"}, {"soHeaderId":"30879"}]}', 1
CREATE PROCEDURE [dbo].[SSP_SalesOrder_ProcessProcurement]  
@Json VARCHAR(MAX),
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		BEGIN TRANSACTION

			--DECLARE @Json VARCHAR(MAX) = N'{"soList":[{"soHeaderId":"30880"}, {"soHeaderId":"30879"}]}', @userId INT = 1;

			DECLARE @ErrMessage VARCHAR(1000);

			DROP TABLE IF EXISTS #soList;

			SELECT * 
			INTO #soList
			FROM  OPENJSON(@Json, '$.soList') 
   				WITH (
					soHeaderId BIGINT			N'$.soHeaderId'
				)

			DECLARE @soHeaderId INT

			DECLARE CUR_so CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
			SELECT soHeaderId
			FROM #soList

			OPEN CUR_so
			FETCH NEXT FROM CUR_so INTO @soHeaderId

			WHILE @@FETCH_STATUS = 0
			BEGIN			
				DECLARE @companyId INT, @soName vARCHAR(30);

				SELECT @companyId = companyId, @soName = soName 
				FROM soHeader 
				WHERE soHeaderId = @soHeaderId

				DROP TABLE IF EXISTS #soLineItem;

				SELECT soLineItemId, invId, odrQty, odrQty - poQty as processQty
				INTO #soLineItem
				FROM soLineItem
				WHERE soHeaderId = @soHeaderId
 
				DROP TABLE IF EXISTS #rawBom;

				SELECT invId, rawBomInvId, rawBomQty
				INTO #rawBom
				FROM rawBom
				WHERE status = 1
					AND companyId = @companyId

				DROP TABLE IF EXISTS #missing;
 
				SELECT li.invId, inv.inventorySku
				INTO #missing
				FROM #soLineItem li
                    INNER JOIN md_Inventory inv 
                        ON li.invId = inv.invId
					LEFT JOIN #rawBom rb
						ON li.invId = rb.invId
				WHERE rb.invId IS NULL

				IF (SELECT COUNT(1) FROM #missing) > 0
				BEGIN
					SET @ErrMessage = (SELECT TOP 1 'inventorySku ' + inventorySku + ' product bom is not exists in the system, please go raw bom listing page to create' FROM #rawBom);
					THROW 60000, @ErrMessage, 1;
				END

				DECLARE @processList AS TABLE (procurementProcessId BIGINT, soLineItemId BIGINT, invId BIGINT, processQty INT)

				INSERT INTO procurementProcess(companyId, soHeaderId, soName, soLineItemId, invId, processQty, rawBomInvId, rawBomQty, rawBomTotalQty, status, enterBy, enterDate)
				OUTPUT INSERTED.procurementProcessId, INSERTED.soLineItemId, INSERTED.invId, INSERTED.processQty
				INTO @processList
				SELECT @companyId, @soHeaderId, @soName, soLineItemId, s.invId, processQty, rawBomInvId, rawBomQty, (processQty * rawBomQty) as rawBomTotalQty, 0 as status, @userId, getdate()
				FROM #soLineItem s
					INNER JOIN #rawBom rb
						ON s.invId = rb.invId

				IF (SELECT COUNT(1) FROM @processList) > 0
				BEGIN
					UPDATE s SET
						poQty = p.processQty,
						updateDate = getdate()
					FROM soLineItem s
						INNER JOIN @processList p
							ON s.soLineItemId = p.soLineItemId 

				END 
				ELSE
				BEGIN
					SET @ErrMessage = (SELECT 'SO# ' + @soName + ' procurement process is failed');
					THROW 60000, @ErrMessage, 1;
				END

				FETCH NEXT FROM CUR_so INTO @soHeaderId

			END
			CLOSE CUR_so
			DEALLOCATE CUR_so

		COMMIT TRANSACTION
		
		SELECT '_SUCCESS_' as status, 'Procurement process has been successful create' as returnMessage
				
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
 
 
		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as returnMessage

		RETURN -1
	END CATCH
END

GO


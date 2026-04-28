-- =============================================
-- Author:		WL Leong
-- Create date: 2023-12-10
-- Used By:	    EMS -> PO Module -> PO Listing -> Create New LR

-- Description : Load Request for factory, so they can prepare packing list for container loading

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-02-15	5.0			WL Leong	ConfirmQtt default same with lrQty
-- 2024-01-30	4.2			WL Leong	Add lrShipToId
-- 2024-01-29	4.1			ZY Wong		Fix poName repeating in error msg
-- 2024-01-29	4.0			WL Leong	Add another validation for 0 lines conversion
-- 2024-01-22	3.0			ZY Wong		Add XACT_ABORT
-- 2024-01-22	2.0			WL Leong	Change of some column
-- 2023-12-10	1.0			WL Leong	Initial
-- ==========================================================================================
/**
EXEC SSP_PurchaseOrder_ConvertNewLoadingRequest
N'{"poList":[{"poId":"42"}, {"poId":"43"}]}', 1
**/
--select * from poHeader
 
CREATE PROCEDURE [dbo].[SSP_PurchaseOrder_ConvertNewLoadingRequest]
@Json VARCHAR(MAX),
@createdBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		--DECLARE @Json VARCHAR(MAX)
		--DECLARE @createdBy INT = 1
		--SET @Json = N'{"poList":[{"poId":"3"}, {"poId":"8"}, {"poId":"11"}]}'
		
		-- Read json content
		DROP TABLE IF EXISTS #order;

		SELECT * 
		INTO #order
		FROM  OPENJSON(@Json, '$.poList') 
   			WITH (
				poId BIGINT			N'$.poId'
			)

		DROP TABLE IF EXISTS #poInfo;

		SELECT odr.poId, p.poName, p.poEarlyShipDate, p.companyId, p.supplierId, p.reference1, p.reference2, p.reference3, p.poStatus, p.poReferenceId, p.shipToId
		INTO #poInfo
		FROM poHeader p
			INNER JOIN #order odr
				ON p.poId = odr.poId

		IF (SELECT COUNT(DISTINCT supplierId) FROM #poInfo) > 1
		BEGIN
			SELECT '_ALERT_' as status, 'Different supplier cannot raise in 1 LR'  as returnMessage

			RETURN -1 
		END

		-- 1077 Released --> PO raised to factory
		IF (SELECT COUNT(1) FROM #poInfo WHERE poStatus <> 1077) > 0 
		BEGIN
			DECLARE @unRaisePO varchar(5000) 
				
			SELECT @unRaisePO = COALESCE(@unRaisePO + ', ' + poName, poName) 
			FROM #poInfo
			WHERE poStatus <> 1077

			ROLLBACK TRANSACTION
			SELECT '_ALERT_' as status, @unRaisePO + ' PO not yet raised to supplier'  as returnMessage

			RETURN -1 
		END

		DROP TABLE IF EXISTS #convertList;

		SELECT p.poId, p.poName, p.poReferenceId, poEarlyShipDate, p.companyId, p.supplierId, p.reference1, p.reference2, p.reference3, s.customerId, p.shipToId
		INTO #convertList
		FROM #poInfo p
			LEFT JOIN soHeader s
				ON p.poReferenceId = s.soName

		IF (SELECT COUNT(DISTINCT customerId) FROM #convertList) > 1 
		BEGIN
			SELECT '_ALERT_' as status, 'Different customer po cannot combine into 1 LR'  as returnMessage

			RETURN -1 
		END
		 
		IF (SELECT COUNT(DISTINCT shipToId) FROM #convertList) > 1 
		BEGIN
			SELECT '_ALERT_' as status, 'Different destination po cannot combine into 1 LR'  as returnMessage

			RETURN -1 
		END

		IF (SELECT COUNT(DISTINCT poEarlyShipDate) FROM #convertList) > 1 
		BEGIN
			SELECT '_ALERT_' as status, 'Different ship date please use LR Module to issue  LR'  as returnMessage

			RETURN -1 
		END

		DROP TABLE IF EXISTS #checkPartialLr;

  		SELECT DISTINCT p.poName, p.qty, p.lrQty
		INTO #checkPartialLr
		FROM #convertList odr
			INNER JOIN poLineItem p
				ON odr.poId = p.poId
		WHERE lrQty > 0

		IF (SELECT COUNT(1) FROM #checkPartialLr) > 0 
		BEGIN
			DECLARE @checkPartialLr varchar(5000) 
				
			SELECT @checkPartialLr = COALESCE(@checkPartialLr + ', ' + poName, poName) 
			FROM (SELECT DISTINCT poName FROM #checkPartialLr)g


			SELECT '_ALERT_' as status, @checkPartialLr + ' PO has partially request for LR, please use LR Module to issue LR'  as returnMessage

			RETURN -1 
		END

		IF (SELECT SUM(qty-lrQty) FROM #checkPartialLr ) > 0 
		BEGIN
			DECLARE @noConversion varchar(5000) 
				
			SELECT @noConversion = COALESCE(@noConversion + ', ' + poName, poName) 
			FROM  (SELECT DISTINCT poName FROM #checkPartialLr)g

			SELECT '_ALERT_' as status, @noConversion + ' all items under PO has been raised to LR'  as returnMessage

			RETURN -1 
		END
  

		BEGIN TRANSACTION
 
			DECLARE @companyId INT, @lrHeaderId BIGINT, @lrName VARCHAR(50) , @poId BIGINT
			DECLARE @tempLRName VARCHAR(50)
			DECLARE @poReference1 varchar(500), @poReference2 varchar(500), @poReference3 varchar(500)

			DECLARE CUR_lrConvertList CURSOR LOCAL FOR  
			SELECT DISTINCT poId 
			FROM #convertList 

			OPEN CUR_lrConvertList  
			FETCH NEXT FROM CUR_lrConvertList 
			INTO @poId 
 
			WHILE @@FETCH_STATUS=0
			BEGIN 
				DROP TABLE IF EXISTS #filtered;
				
				SELECT *
				INTO #filtered
				FROM #convertList
				WHERE poId = @poId

				
				SELECT @poReference1 = COALESCE(@poReference1 + ', ' + reference1, reference1),
					@poReference2 = COALESCE(@poReference2 + ', ' + reference2, reference3),
					@poReference3 = COALESCE(@poReference3 + ', ' + reference2, reference3)
				FROM #filtered

				SET @companyId = (SELECT TOP 1 companyId FROM #filtered);

				EXEC [dbo].[SSP_GetRunningNo] 'LR', @companyId, @lrName  output
			 
				IF @lrName IS NOT NULL
				BEGIN
					SET @tempLRName = 'tempLR_' + @lrName
 
				-- 2132 LR Open Status
					DECLARE @newLr table(lrHeaderId BIGINT, lrName VARCHAR(50))

					INSERT INTO lrHeader(companyId, supplierId, customerId, lrName, lrDate, lrShipToId, lrShipDate, lrContainerType, reference1, reference2, reference3, lrNote, lrStatus, 
						poId, poName, poReferenceId, enterBy, enterDate)
					OUTPUT INSERTED.lrHeaderId, INSERTED.lrName
					INTO @newLr
					SELECT DISTINCT odr.companyId, odr.supplierId, customerId, @tempLRName, getdate() as lrDate, shipToId, poEarlyShipDate as lrShipDate, 0, @poReference1, @poReference2, @poReference3, '' as lrNote, 2132 as lrStatus, 
						odr.poId, odr.poName, odr.poReferenceId, @createdBy, getdate()
					FROM #filtered odr
 
 
					SELECT @lrHeaderId = lrHeaderId, @lrName = lrName  
					FROM @newLr
			 
					IF @lrHeaderId IS NULL
					BEGIN
						ROLLBACK TRANSACTION
						SELECT '_FAILURE_' as status, 'LR number encounter creation problem' AS returnMessage 

						RETURN -1
					END
					ELSE
					BEGIN
						DECLARE @newLrLineItem table(poDetailsId BIGINT, lrQty INT)
			 
						INSERT INTO lrLineItem(lrHeaderId, lrName, supplierSku, invId, merchantSku, itemReference1, qty, confirmQty, itemNote, itemStatus, poDetailsId, poName, enterBy, enterDate)
						OUTPUT INSERTED.poDetailsId, INSERTED.qty
						INTO @newLrLineItem					
						SELECT @lrHeaderId, @lrName, supplierSku, invId, merchantSku, itemReference1, p.qty - p.lrQty, p.qty - p.lrQty, '' as itemNotes, 2132 as itemStatus, poDetailsId, p.poName, @createdBy, getdate()
						FROM #filtered odr
							INNER JOIN poLineItem p
								ON odr.poId = p.poId
 
						UPDATE pl SET
							lrQty = pl.lrQty + cl.lrQty
						FROM poLineItem pl
							INNER JOIN @newLrLineItem cl
								ON pl.poDetailsId = cl.poDetailsId

					END
				END
				ELSE
				BEGIN
					ROLLBACK TRANSACTION
					SELECT '_FAILURE_' as status, 'LR number encounter creation problem' AS returnMessage 
				
					RETURN -1
				END
	
				FETCH NEXT FROM CUR_lrConvertList 
				INTO @poId
			END

			CLOSE CUR_lrConvertList
			DEALLOCATE CUR_lrConvertList

		COMMIT TRANSACTION
		SELECT '_SUCCESS_' as status, 'LR# ' + @lrName + ' successfully created' AS returnMessage , @lrName as LR
				
		RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 
 
		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as returnMessage

		RETURN -1
	END CATCH
END

GO


-- =============================================
-- Author:		WL Leong
-- Create date: 2023-10-09
-- Used By:	    EMS

-- Description : Insert the SO template to soHeader, soLineItem

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-11-13   10.0        WL Leong    Add tagDivision for lineItem
-- 2024-06-26   9.0         ZY Wong     Add validation for expired shipdate
-- 2024-05-09   8.0         WL Leong    Need to validate also merchatSku & itemCode
-- 2024-04-16   7.1         ZY Wong     Add soItemDesc into soLineItem table
-- 2024-04-11	7.0			WL Leong	Add more validation
-- 2024-03-27	6.0			WL Leong	Insert to soLIneItemSplit
-- 2024-02-08	5.0			WL Leong	Fix multiple line and throw error
-- 2024-01-15	4.0			WL Leong	Add merchantSku
-- 2023-12-25	3.0			WL Leong	POD change shipToId
-- 2023-10-27	2.0			WL Leong	Combine multiple csPO to 1 SO based on shipdate
-- 2023-10-09	1.0			WL Leong	Initial
-- ========================================================================================== 
 ---EXEC SSP_SalesOrder_InsertNewOrderByFileLog '20240208034249_ImportSOTemplate_20231106.csv', 1

CREATE PROCEDURE [dbo].[SSP_SalesOrder_InsertNewOrderByFileLog_retired] 
@fileUploaded varchar(200) = '',
@createdBy INT
AS
BEGIN
SET DATEFORMAT ymd
SET XACT_ABORT ON
SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRANSACTION
		 
		DECLARE @ErrMessage VARCHAR(MAX);
		--DECLARE @fileUploaded varchar(100) = '20241202035250_ImportSOTemplate_20241202.csv', @createdBy INT = 1
		
		IF (SELECT COUNT(*) FROM  temp_SoFileLog WHERE fileLoaded = @fileUploaded) > 0
		BEGIN

			DROP TABLE IF EXISTS #tempSo;

			SELECT * 
			INTO #tempSo
			FROM temp_SoFileLog 
			WHERE fileLoaded = @fileUploaded
				AND companyId IS NOT NULL

			ALTER TABLE #tempSo ADD customerId INT;
			ALTER TABLE #tempSo ADD customerSkuId BIGINT
			ALTER TABLE #tempSo ADD invId BIGINT
			ALTER TABLE #tempSo ADD merchantSku VARCHAR(30)
            ALTER TABLE #tempSo ADD modelNo VARCHAR(50)
			ALTER TABLE #tempSo ADD tagDivision INT
			ALTER TABLE #tempSo ADD shpToId INT
			ALTER TABLE #tempSo ADD currencyCode INT
			ALTER TABLE #tempSo ADD csCost FLOAT
 
			--IF (SELECT COUNT(1) FROM #tempSo WHERE ISNULL(requestDate, '') = '') > 0
			--BEGIN
			--	SET @ErrMessage = 'Request date is compulsory';
			--	THROW 60000, @ErrMessage, 1;
			--END	

			IF (SELECT COUNT(1) FROM #tempSo WHERE ISNULL(customerName, '') = '') > 0
			BEGIN
				SET @ErrMessage = 'Customer name is compulsory';
				THROW 60000, @ErrMessage, 1;
			END

			IF (SELECT COUNT(1) FROM #tempSo WHERE ISNULL(customerPO, '') = '') > 0
			BEGIN
				SET @ErrMessage = 'Customer PO# is compulsory';
				THROW 60000, @ErrMessage, 1;
			END

			IF (SELECT COUNT(1) FROM #tempSo WHERE ISNULL(customerSku, '') = '') > 0
			BEGIN
				SET @ErrMessage = 'Customer Sku is compulsory';
				THROW 60000, @ErrMessage, 1;
			END

			IF (SELECT COUNT(1) FROM #tempSo WHERE ISNULL(csItemCode, '') = '') > 0
			BEGIN
				SET @ErrMessage = 'Customer Item Code is compulsory';
				THROW 60000, @ErrMessage, 1;
			END


			IF (SELECT COUNT(1) FROM #tempSo WHERE ISDATE(CAST(shipDate as varchar)) = 0) > 0
			BEGIN
				SET @ErrMessage = 'Invalid ship date, date format [yyyy-mm-dd]';
				THROW 60000, @ErrMessage, 1;
			END

            IF (SELECT COUNT(1) FROM #tempSo WHERE shipDate <= CONVERT(DATE, GETDATE())) > 0
            BEGIN
                SET @ErrMessage =   (SELECT 'Customer PO # ' + STRING_AGG(CONVERT(VARCHAR(max), customerPO), ',')  + ' have expired ship date'
                                    FROM (  SELECT customerPO 
                                            FROM #tempSo 
                                            WHERE shipDate <= CONVERT(DATE, GETDATE())
                                        )g 
                                    );
                THROW 60000, @ErrMessage, 1;
            END

			UPDATE solog SET
				customerId = cs.customerId
			FROM #tempSo solog 
				INNER JOIN md_customer cs
					ON solog.customerName = cs.customerName
					AND solog.companyId = cs.companyId
	
			IF (SELECT COUNT(1) FROM #tempSo WHERE customerId IS NULL) > 0
			BEGIN
				SELECT @ErrMessage = STRING_AGG(customerName,',' )
				FROM (SELECT DISTINCT customerName 
					  FROM  #tempSo 
                      WHERE ISNULL(customerId, '') = ''
                      ) g   

				SET @ErrMessage = @ErrMessage + ' customer has not setup in system';
				THROW 60000, @ErrMessage, 1;
			END

			IF (SELECT COUNT(*) FROM (SELECT solog.companyId, solog.customerId, solog.customerPO 
                                      FROM #tempSo solog 
								            INNER JOIN soHeader so 
									            ON solog.companyId = so.companyId 
									            AND solog.customerId = so.customerId 
									            AND (solog.customerPO = so.customerPO OR CHARINDEX(solog.customerPO, so.customerPO) > 0)
									)g 
				) > 0
			BEGIN
				SET @ErrMessage = 'Customer PO# already exists in system';
				THROW 60000, @ErrMessage, 1;
			END

	
			UPDATE solog SET 
				destination = ISNULL(md.shipToLabel, ''),
				shpToId = md.shipToId
			FROM #tempSo solog
				LEFT JOIN md_ShipToDestination md
					ON solog.destinationLabel = md.locNo
					AND solog.companyId = md.companyId
					AND solog.customerId = md.customerId
			WHERE ISNULL(destinationLabel, '') <> ''

			IF (SELECT COUNT(1) FROM #tempSo WHERE ISNULL(destination, '') = '') > 0
			BEGIN
				SELECT @ErrMessage = STRING_AGG(destinationLabel,',' )
				FROM (SELECT DISTINCT destinationLabel 
					  FROM  #tempSo 
                      WHERE ISNULL(destination, '') = ''
                      ) g  

				SET @ErrMessage = @ErrMessage + ' destination code not configured in system';
				THROW 60000, @ErrMessage, 1;
			END

			UPDATE solog SET 
				destinationLabel = md.locNo,
				shpToId = md.shipToId
			FROM #tempSo solog
				LEFT JOIN md_ShipToDestination md
					ON solog.destination = md.shipToLabel
					AND solog.companyId = md.companyId
					AND solog.customerId = md.customerId
			WHERE ISNULL(destination, '') <> ''
 
			IF (SELECT COUNT(1) FROM #tempSo WHERE ISNULL(destinationLabel, '') = '') > 0
			BEGIN
				SELECT @ErrMessage = STRING_AGG(destination,',' )
				FROM (SELECT DISTINCT destination 
					  FROM  #tempSo 
                      WHERE ISNULL(destinationLabel, '') = ''
                      ) g  

				SET @ErrMessage = @ErrMessage + ' destination not configured in system';

				THROW 60000, @ErrMessage, 1;
			END	
 
 			UPDATE solog SET
				customerSkuId = csSku.customerSkuId,
				currencyCode = csSku.currencyCode,
				csCost = csSku.csCost,
				tagDivision = csSku.tagDivision,
				invid = csSku.invId,
				itemDescription = csSku.itemDesc
			FROM #tempSo solog 
				INNER JOIN md_customerSku csSku
                    ON solog.customerSku = csSku.customerSku 
                    AND solog.companyId = csSku.companyId
                    AND solog.customerId = csSku.customerId
					AND solog.csItemCode = csSku.merchantSku
					AND csSku.statusflag = 1

			IF (SELECT COUNT(1) FROM #tempSo WHERE customerSkuId IS NULL) > 0
			BEGIN
				SELECT @ErrMessage = STRING_AGG(customerSku,',' )
				FROM (SELECT DISTINCT customerSku 
					  FROM  #tempSo 
                      WHERE customerSkuId IS NULL
                      ) g 

				SET @ErrMessage = @ErrMessage + ' customerSku has not setup in system';

				THROW 60000, @ErrMessage, 1;
			END
 
  			UPDATE  solog SET 
				itemDescription = CASE WHEN ISNULL(solog.itemDescription, '') = '' THEN inv.itemDesc ELSE solog.itemDescription END,
                modelNo = inv.modelNo
			FROM  #tempSo solog
				INNER JOIN md_inventory inv
					ON solog.companyId = inv.companyId
					AND solog.invId = inv.invID
					AND inv.status = 1
  
			UPDATE #tempSo SET 
				cancelDate = DATEADD(day, 7, shipDate)
			WHERE ISNULL(cancelDate, '') = ''
			
			DECLARE @companyId INT, @supplierId INT, @shipWay INT, @VeselBooking VARCHAR(20), @POL VARCHAR(20), @foreignCurrencyRate NUMERIC(13,4)

			SET @companyId = (SELECT TOP 1 companyId FROM #tempSo)
			SET @supplierId = (SELECT configValue FROM md_defaultConfig WHERE companyId = @companyId AND configName = 'DefaultSupplier');
			SET @shipWay = (SELECT configValue FROM md_defaultConfig WHERE companyId = @companyId AND configName = 'ShipWay');
			SET @VeselBooking = (SELECT configValue FROM md_defaultConfig WHERE companyId = @companyId AND configName = 'VesselBooking');
			SET @POL = (SELECT configValue FROM md_defaultConfig WHERE companyId = @companyId AND configName = 'POL');

			DECLARE @customerId INT, @shipDate DATE, @poType VARCHAR(20), @shpToId INT
			DECLARE @returnMessage VARCHAR(5000)

			DECLARE CUR_so CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
			SELECT DISTINCT customerId, shipDate, poType, shpToId
			FROM  #tempSo
 
			OPEN CUR_so
			FETCH NEXT FROM CUR_so INTO @customerId, @shipDate, @poType, @shpToId
 
			WHILE @@FETCH_STATUS = 0
			BEGIN
				
				DECLARE @soName VARCHAR(50) = '';

				EXEC [dbo].[SSP_GetRunningNo] 'SO', @companyId, @soName OUTPUT

				IF @soName IS NOT NULL
				BEGIN

					DECLARE @NewOrder table(soHeaderId BIGINT, customerId INT)
					DECLARE @tempSOName VARCHAR(50) = '', @soHeaderId BIGINT
				 
					DELETE FROM @NewOrder

					SET @tempSOName = 'tempSO_' + @soName
					-- 1105 SO Open Status
					
					DECLARE @customerPO VARCHAR(500)

					SELECT @customerPO = STUFF((
								SELECT ', ' + customerPO
								FROM (SELECT DISTINCT customerPO 
									  FROM  #tempSo 
									  WHERE customerId = @customerId
										AND shipDate = @shipDate
										AND shpToId = @shpToId
										AND poType = @poType) g  
								FOR XML PATH('')
								), 1, 2, '');

					INSERT INTO soHeader(companyId, customerId, supplierId, soName, soDate, customerPO, thirdParty, thirdPartyPO, 
						reference2, reference3, shipToId, shipWay, vesselBooking, 
						portOfLanding, portOfDestination, earlyShipDate, lateShipDate, soInvoice, soInvoiceDate, soNote, soStatus, createBy, createDate)
					OUTPUT INSERTED.soHeaderId, INSERTED.customerId 
					INTO @NewOrder
					SELECT DISTINCT companyId, customerId, ISNULL(@supplierId, 0), @tempSOName, getdate() as soDate, ISNULL(@customerPO, ''), ISNULL(thirdPartyCustomer, ''), ISNULL(thirdPartyPO, ''),
						poType, deptCode, shpToId, ISNULL(@shipWay, '0'), ISNULL(@VeselBooking, ''),
						ISNULL(@POL, ''), shpToId as POD, shipDate, cancelDate, '' as soInvoice, NULL as soInvoiceDate, '' as soNote, 1105 as soStatus, @createdBy, getdate()
					FROM #tempSo
					WHERE customerId = @customerId
						AND shipDate = @shipDate
 						AND shpToId = @shpToId
						AND poType = @poType

					SET @soHeaderId = (SELECT soHeaderId FROM @NewOrder)

					IF @soHeaderId IS NULL
					BEGIN
						SET @ErrMessage = 'SO/PI number encounter creation problem';

						THROW 60000, @ErrMessage, 1;
					END
					ELSE
					BEGIN 

						INSERT INTO soLineItem(soHeaderId, invId, customerSkuId, customerSku, soItemDesc, merchantSku, csCost, currencyCode, odrQty, 
								isItemPriceChanged, itemReference1, itemReference2, soLineItemStatus, createBy, createDate, tagDivision)
						SELECT @soHeaderId, invId, customerSkuId, customerSku, itemDescription, csItemCode as merchantSku, csCost, ISNULL(cd.categoryName, ''), SUM(orderQty) as orderQty,
								0 as isItemPriceChanged, modelNo, thirdPartyItemCode, 1105, @createdBy, getdate(), tagDivision
						FROM #tempSo s
							LEFT JOIN MD_MasterCategory cd
								ON s.currencyCode = cd.categoryId
						WHERE customerId = @customerId
							AND shipDate = @shipDate
 							AND shpToId = @shpToId
							AND poType = @poType
						GROUP BY invId, customerSkuId, customerSku, itemDescription, csItemCode, csCost, cd.categoryName, modelNo, thirdPartyItemCode,tagDivision

						SET @returnMessage = ISNULL(@returnMessage, '') + ' ' + @tempSOName
					END
				END
				ELSE
				BEGIN
					SET @ErrMessage = 'SO/PI prefix is not configured'; 

					THROW 60000, @ErrMessage, 1;
				END


	 		--COMMIT TRANSACTION

			DELETE FROM @NewOrder

			FETCH NEXT FROM CUR_so INTO @customerId, @shipDate, @poType, @shpToId
		END
		CLOSE CUR_so
		DEALLOCATE CUR_so
	END
	ELSE
	BEGIN
		SET @ErrMessage = 'No rows being processed ' + @fileUploaded;

		THROW 60000, @ErrMessage, 1;
	END

	DELETE FROM temp_SoFileLog WHERE fileLoaded = @fileUploaded

	SELECT '_SUCCESS_' as execStatus, @returnMessage + ' created successfully' as execMessage

	COMMIT TRANSACTION

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

		DELETE FROM temp_SoFileLog WHERE fileLoaded = @fileUploaded

		SET @ErrMessage =  ERROR_MESSAGE();

		SELECT '_FAILURE_' as execStatus, @ErrMessage as execMessage
	END CATCH

END

GO


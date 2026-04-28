-- =============================================
-- Author:		WL Leong
-- Create date: 2023-10-09
-- Used By:	    EMS

-- Description : Insert the SO template to soHeader, soLineItem

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-07-01   14.0        ZY Wong     Add new column EAN into soLineItem
-- 2025-06-19   13.0        WL Leong    itemReference1 will be based on merchantSku, else will base on modelNo
-- 2025-06-10   12.0        ZY Wong     Follow seq in file when insert line item (requested by yaoming)
-- 2025-03-04   11.1        ZY Wong     Merchant sku allowed null (validate only passed in)
-- 2025-03-03   11.0        ZY Wong     Restructure sp, split all records to single SO group by customerPo, fix empty row passed from files
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
 -- select * from temp_SoFileLog
CREATE PROCEDURE [dbo].[SSP_SalesOrder_InsertNewOrderByFileLog] 
@fileUploaded varchar(200) = '',
@createdBy INT
AS
BEGIN
SET DATEFORMAT ymd
SET XACT_ABORT ON
SET NOCOUNT ON;
	BEGIN TRY
		 
		DECLARE @ErrMessage VARCHAR(MAX);
		 --DECLARE @fileUploaded varchar(100) = '20260113111224_ImportSOTemplate_20260112.csv', @createdBy INT = 1
		
		IF (SELECT COUNT(*) FROM  temp_SoFileLog WHERE fileLoaded = @fileUploaded) > 0
		BEGIN

			DROP TABLE IF EXISTS #tempSo;

			SELECT sofilelog_Id, companyId, customerName, customerPO, thirdPartyCustomer, thirdPartyPO, poType, deptCode, csItemCode, thirdPartyitemCode, customerSku, 
                itemDescription, orderQty, shipDate, cancelDate, destinationLabel, destination, fileLoaded
			INTO #tempSo
			FROM temp_SoFileLog 
			WHERE fileLoaded =  @fileUploaded
				AND companyId IS NOT NULL
                AND ((CASE WHEN ISNULL(customerName,'') = '' THEN 1 ELSE 0 END) + 
                    (CASE WHEN ISNULL(customerPO,'') = '' THEN 1 ELSE 0 END)) < 2  --ignore empty line

            DECLARE @companyId INT = (SELECT TOP 1 companyId FROM #tempSo);

			ALTER TABLE #tempSo ADD customerId INT;
			ALTER TABLE #tempSo ADD customerSkuId BIGINT;
			ALTER TABLE #tempSo ADD invId BIGINT;
			ALTER TABLE #tempSo ADD merchantSku VARCHAR(30);
            ALTER TABLE #tempSo ADD EAN VARCHAR(50);
            ALTER TABLE #tempSo ADD modelNo VARCHAR(50);
			ALTER TABLE #tempSo ADD tagDivision INT;
			ALTER TABLE #tempSo ADD shpToId INT;
            ALTER TABLE #tempSo ADD pod INT;
			ALTER TABLE #tempSo ADD currencyCode INT;
			ALTER TABLE #tempSo ADD csCost FLOAT;

/*** Start: data validation ***/

            -- check customer name missing
			IF (SELECT COUNT(1) FROM #tempSo WHERE ISNULL(customerName, '') = '') > 0
			BEGIN
				SET @ErrMessage = 'Customer name is compulsory.';
				THROW 60000, @ErrMessage, 1;
			END

            -- check customer po missing
			IF (SELECT COUNT(1) FROM #tempSo WHERE ISNULL(customerPO, '') = '') > 0
			BEGIN
				SET @ErrMessage = 'Customer PO# is compulsory.';
				THROW 60000, @ErrMessage, 1;
			END

            -- check customer sku missing
			IF (SELECT COUNT(1) FROM #tempSo WHERE ISNULL(customerSku, '') = '') > 0
			BEGIN
				SET @ErrMessage = 'Customer Sku is compulsory.';
				THROW 60000, @ErrMessage, 1;
			END

            -- check cs item code missing
			--IF (SELECT COUNT(1) FROM #tempSo WHERE ISNULL(csItemCode, '') = '') > 0
			--BEGIN
			--	SET @ErrMessage = 'Customer Item Code is compulsory';
			--	THROW 60000, @ErrMessage, 1;
			--END

            -- check invalid ship date
			IF (SELECT COUNT(1) FROM #tempSo WHERE ISDATE(CAST(shipDate as varchar)) = 0) > 0
			BEGIN
				SET @ErrMessage = 'Invalid ship date, date format [yyyy-mm-dd].';
				THROW 60000, @ErrMessage, 1;
			END

            -- check expired ship date
            IF (SELECT COUNT(1) FROM #tempSo WHERE shipDate <= CONVERT(DATE, GETDATE())) > 0
            BEGIN
                SET @ErrMessage =   (SELECT 'Customer PO # ' + STRING_AGG(CONVERT(VARCHAR(max), customerPO), ',')  + ' have expired ship date.'
                                    FROM (  SELECT customerPO 
                                            FROM #tempSo 
                                            WHERE shipDate <= CONVERT(DATE, GETDATE())
                                        )g 
                                    );
                THROW 60000, @ErrMessage, 1;
            END

            -- check invalid customer
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

				SET @ErrMessage = 'Customer ' + @ErrMessage + ' not setup in system.';
				THROW 60000, @ErrMessage, 1;
			END

            -- check customer po exists
			IF (SELECT COUNT(*) FROM (SELECT solog.companyId, solog.customerId, solog.customerPO 
                                      FROM #tempSo solog 
								            INNER JOIN soHeader so 
									            ON solog.companyId = so.companyId 
									            AND solog.customerId = so.customerId 
									            AND (solog.customerPO = so.customerPO OR CHARINDEX(solog.customerPO, so.customerPO) > 0)
									)g 
				) > 0
			BEGIN
				SET @ErrMessage = (SELECT 'Customer PO# ' + STRING_AGG(CONVERT(VARCHAR(MAX),customerPO),', ') + ' already exists in system.'
                                    FROM (SELECT DISTINCT solog.companyId, solog.customerId, solog.customerPO 
                                            FROM #tempSo solog 
								                INNER JOIN soHeader so 
									                ON solog.companyId = so.companyId 
									                AND solog.customerId = so.customerId 
									                AND (solog.customerPO = so.customerPO OR CHARINDEX(solog.customerPO, so.customerPO) > 0)
                                        )g
                            );
				THROW 60000, @ErrMessage, 1;
			END

	        -- check invalid destination code 
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

				SET @ErrMessage = 'Destination code ' + @ErrMessage + ' not configured in system.';
				THROW 60000, @ErrMessage, 1;
			END

            -- check invalid destination
			UPDATE solog SET 
				destinationLabel = md.locNo,
				shpToId = md.shipToId,
                pod = (CASE WHEN md.pod IS NULL OR md.pod = '' THEN 0 ELSE md.pod END)
			FROM #tempSo solog
				LEFT JOIN md_ShipToDestination md
					ON solog.destination = md.shipToLabel
					AND solog.companyId = md.companyId
					AND solog.customerId = md.customerId
			WHERE ISNULL(destination, '') <> ''
 
 			IF (SELECT COUNT(1) FROM #tempSo WHERE pod = 0) > 0
			BEGIN
				SELECT @ErrMessage = STRING_AGG(destination,',' )
				FROM (SELECT DISTINCT destination 
					  FROM  #tempSo 
                      WHERE pod = 0
                      ) g  

				SET @ErrMessage = 'POD ' + @ErrMessage + ' is not configured in system.';

				THROW 60000, @ErrMessage, 1;
			END	

			IF (SELECT COUNT(1) FROM #tempSo WHERE ISNULL(destinationLabel, '') = '') > 0
			BEGIN
				SELECT @ErrMessage = STRING_AGG(destination,',' )
				FROM (SELECT DISTINCT destination 
					  FROM  #tempSo 
                      WHERE ISNULL(destinationLabel, '') = ''
                      ) g  

				SET @ErrMessage = 'Destination ' + @ErrMessage + ' not configured in system.';

				THROW 60000, @ErrMessage, 1;
			END	
 
            -- check invalid customer sku
            -- combination for mph: customerSku + merchantSku + companyId + customerId
            -- allow merchantSku pass in empty
 			UPDATE solog SET
				customerSkuId = csSku.customerSkuId,
				currencyCode = csSku.currencyCode,
				csCost = csSku.csCost,
				tagDivision = csSku.tagDivision,
				invid = csSku.invId,
				itemDescription = csSku.itemDesc,
				merchantSku = csSku.merchantSku,
                EAN = csSku.EAN
			FROM #tempSo solog 
				INNER JOIN md_customerSku csSku
                    ON solog.customerSku = csSku.customerSku 
                    AND solog.companyId = csSku.companyId
                    AND solog.customerId = csSku.customerId
					AND ISNULL(solog.csItemCode,'') = ISNULL(csSku.merchantSku,'')
					AND csSku.statusflag = 1
            

			IF (SELECT COUNT(1) FROM #tempSo WHERE customerSkuId IS NULL) > 0
			BEGIN
				SELECT @ErrMessage = STRING_AGG(customerSku,',' )
				FROM (SELECT DISTINCT customerSku 
					  FROM  #tempSo 
                      WHERE customerSkuId IS NULL
                      ) g 

				SET @ErrMessage = 'Customer Sku ' + @ErrMessage + ' not setup in system.';
				THROW 60000, @ErrMessage, 1;
			END
 
            -- update itemDescription
  			UPDATE  solog SET 
				itemDescription = CASE WHEN ISNULL(solog.itemDescription, '') = '' THEN inv.itemDesc ELSE solog.itemDescription END,
                modelNo = inv.modelNo
			FROM  #tempSo solog
				INNER JOIN md_inventory inv
					ON solog.companyId = inv.companyId
					AND solog.invId = inv.invID
					AND inv.status = 1
  
            -- update cancelDate
			UPDATE #tempSo SET 
				cancelDate = DATEADD(day, 7, shipDate)
			WHERE ISNULL(cancelDate, '') = ''

/*** End: data validation ***/
		    BEGIN TRANSACTION

			    DECLARE @supplierId INT, @shipWay INT, @VeselBooking VARCHAR(20), @POL VARCHAR(20), @foreignCurrencyRate NUMERIC(13,4);
 
			    SET @supplierId = (SELECT configValue FROM md_defaultConfig WHERE companyId = @companyId AND configName = 'DefaultSupplier');
			    SET @shipWay = (SELECT configValue FROM md_defaultConfig WHERE companyId = @companyId AND configName = 'ShipWay');
			    SET @veselBooking = (SELECT configValue FROM md_defaultConfig WHERE companyId = @companyId AND configName = 'VesselBooking');
			    SET @POL = (SELECT configValue FROM md_defaultConfig WHERE companyId = @companyId AND configName = 'POL');

                DECLARE @customerId INT, @customerPo VARCHAR(20), @returnMessage VARCHAR(5000);

			    DECLARE CUR_so CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
			    SELECT DISTINCT customerId, customerPo
			    FROM  #tempSo

			    OPEN CUR_so
                FETCH NEXT FROM CUR_so INTO @customerId, @customerPo
 
			    WHILE @@FETCH_STATUS = 0
			    BEGIN
				
				    DECLARE @soName VARCHAR(50) = '';

				    EXEC [dbo].[SSP_GetRunningNo] 'SO', @companyId, @soName OUTPUT

				    IF @soName IS NOT NULL
				    BEGIN

					    DECLARE @NewOrder TABLE (soHeaderId BIGINT, customerId INT);
					    DECLARE @tempSOName VARCHAR(50) = '', @soHeaderId BIGINT;
				 
					    DELETE FROM @NewOrder

					    SET @tempSOName = 'tempSO_' + @soName;

                        -- insert new SO
					    -- 1105 SO Open Status				
					    INSERT INTO soHeader(companyId, customerId, supplierId, soName, soDate, customerPO, thirdParty, thirdPartyPO, 
						    reference2, reference3, shipToId, shipWay, vesselBooking, 
						    portOfLanding, portOfDestination, earlyShipDate, lateShipDate, soInvoice, soInvoiceDate, soNote, soStatus, createBy, createDate)
					    OUTPUT INSERTED.soHeaderId, INSERTED.customerId 
					    INTO @NewOrder
					    SELECT DISTINCT companyId, customerId, ISNULL(@supplierId, 0), @tempSOName, getdate() as soDate, ISNULL(@customerPO, ''), ISNULL(thirdPartyCustomer, ''), ISNULL(thirdPartyPO, ''),
						    poType, deptCode, shpToId, ISNULL(@shipWay, '0'), ISNULL(@veselBooking, ''),
						    ISNULL(@POL, ''), POD as POD, shipDate, cancelDate, '' as soInvoice, NULL as soInvoiceDate, '' as soNote, 1105 as soStatus, @createdBy, getdate()
					    FROM #tempSo
					    WHERE customerId = @customerId
						    AND customerPo = @customerPo 		
 
					    SET @soHeaderId = (SELECT soHeaderId FROM @NewOrder);

					    IF @soHeaderId IS NULL
					    BEGIN
						    SET @ErrMessage = 'SO # encounter creation problem.';
						    THROW 60000, @ErrMessage, 1;
					    END
					    ELSE
					    BEGIN 

                            -- insert new SO item
						    INSERT INTO soLineItem(soHeaderId, invId, customerSkuId, customerSku, soItemDesc, merchantSku, EAN, csCost, currencyCode, odrQty, 
								    isItemPriceChanged, itemReference1, itemReference2, soLineItemStatus, createBy, createDate, tagDivision)
						    SELECT @soHeaderId, invId, customerSkuId, customerSku, itemDescription, csItemCode as merchantSku, EAN, csCost, ISNULL(cd.categoryName, ''), SUM(orderQty) as orderQty,
								    0 as isItemPriceChanged, CASE WHEN ISNULL(merchantSku, '') = '' THEN modelNo ELSE merchantSku END, thirdPartyItemCode, 1105, @createdBy, getdate(), tagDivision
						    FROM #tempSo s
							    LEFT JOIN MD_MasterCategory cd
								    ON s.currencyCode = cd.categoryId
						    WHERE customerId = @customerId
							    AND customerPo = @customerPo
						    GROUP BY sofilelog_Id, invId, customerSkuId, customerSku, itemDescription, csItemCode, EAN, csCost, cd.categoryName,  
								CASE WHEN ISNULL(merchantSku, '') = '' THEN modelNo ELSE merchantSku END, thirdPartyItemCode, tagDivision
                            ORDER BY sofilelog_Id  --follow seq in file

						    SET @returnMessage = CASE WHEN ISNULL(@returnMessage, '') = '' THEN @tempSOName ELSE @returnMessage + ', ' + @tempSOName END;
					    END
				    END
				    ELSE
				    BEGIN
					    SET @ErrMessage = 'SO prefix is not configured.'; 
					    THROW 60000, @ErrMessage, 1;
				    END

			        DELETE FROM @NewOrder

			        FETCH NEXT FROM CUR_so INTO @customerId, @customerPo
		        END
		        CLOSE CUR_so
		        DEALLOCATE CUR_so

	        COMMIT TRANSACTION

	    END
	    ELSE
	    BEGIN
		    SET @ErrMessage = 'No rows being processed ' + @fileUploaded;
		    THROW 60000, @ErrMessage, 1;
	    END

	    DELETE FROM temp_SoFileLog WHERE fileLoaded = @fileUploaded

	    SELECT '_SUCCESS_' as execStatus, 'SO # ' + @returnMessage + ' created successfully.' as execMessage

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

		--DELETE FROM temp_SoFileLog WHERE fileLoaded = @fileUploaded

        IF @ErrMessage IS NULL
		    SET @ErrMessage =  ERROR_MESSAGE();

		SELECT '_FAILURE_' as execStatus, @ErrMessage as execMessage

	END CATCH

END

GO


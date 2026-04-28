
--1105	Open
--1106	Confirm
--1107	Cancel
--1108	Close

-- =============================================
-- Author:		WL Leong
-- Create date: 2023-08-28
-- Used By:	    EMS -> SO Module -> SO Convert PO

-- Description : Once the SO is confirmed, can multi select to convert PO 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-09-17	13.0        WL Leong	Fix soHeaderId for add line itemId
-- 2025-09-12   12.0        WL Leong	Raise a already exists PO, will only insert the diff soLineItem
-- 2025-05-06   11.0        ZY Wong     Pass merchantSku & itemReference2(EAN) into soLineItem 
-- 2025-05-03   10.0        WL Leong    Use thirdParty to keep the thirdParty customerCode
-- 2025-04-23   9.0         ZY Wong     Standardize error message handling
-- 2025-03-20   8.0         WL Leong    Default raise SO is draft, if tagDivision has value then confirm the lineitem, if all lineitem is confirm then confirm SO#
-- 2025-03-03   7.0         WL Leong    change parameter to NVARCHAR
-- 2024-12-31   6.2         ZY Wong     Add apiStatus
-- 2024-11-26   6.1         WL Leong	add locNo
-- 2024-11-26   6.0         WL Leong	raise PO to factory, tagDivision = "Others" SO# status will be Draft, else will be Confirmed
-- 2024-04-22   5.0         ZY Wong     Add validation for qty > odrQty
-- 2024-04-08   4.0         ZY Wong     Change column to itemCode
-- 2024-04-05	3.0			WL Leong	Validate home currency cost
-- 2024-02-28	2.0			WL Leong	FIx the poReferenceId to correct column
-- 2023-06-08	1.0			WL Leong	Initial
-- ==========================================================================================
-- update soHeader set sostatus = 1105 where soName = 'FNP-SO-24-00035'
 --[dbo].[SSP_PurchaseOrder_RaiseInternalPO] N'{"poList":[{"poId":"1789"}]}', 1
CREATE PROCEDURE [dbo].[SSP_PurchaseOrder_RaiseInternalPO]
@Json NVARCHAR(MAX), 
@updateBy INT
AS
BEGIN
    SET XACT_ABORT ON;
    SET NOCOUNT ON;

	    BEGIN TRY
			DECLARE @returnMessage VARCHAR(MAX);
			DECLARE @result TABLE (poRefName VARCHAR(20), poQty INT);
            DELETE FROM @result


			--DECLARE @Json varchar(MAX) = N'{"poList":[{"poId":"7"}]}'
			--DECLARE @updateBy INT = 1

			DROP TABLE IF EXISTS #poList                                
			
			SELECT * 
			INTO #poList
			FROM  OPENJSON(@Json, '$.poList') 
   				WITH (
					poId BIGINT	N'$.poId'
				)			

			DROP TABLE IF EXISTS #poConvertList;
 
			SELECT p.poId, p.companyId, p.supplierId, p.poName, p.poDate, p.poReferenceId, p.shipToId, p.shipvia, p.vesselBooking, p.portofLanding, p.portOfDestination, p.poEarlyShipDate, p.poLateShipDate, 
				p.reference1, p.reference2, p.reference3, p.poStatus, p.locNo, p.customerCode
			INTO #poConvertList
			FROM poHeader p  
				INNER JOIN #poList ls
					ON p.poId = ls.poId	 
				 
			IF (SELECT COUNT(1) FROM #poConvertList where poStatus <> 1085) > 0
			BEGIN
                SET @returnMessage = (SELECT 'PO# ' + STRING_AGG(CONVERT(VARCHAR(MAX), poName), ',') + ' not yet approved, only approved PO can raise to supplier.'
			                            FROM (SELECT DISTINCT poName
                                                FROM #poConvertList 
                                                WHERE poStatus <> 1085)g
                                        );
			    THROW 60000, @returnMessage, 1;
			END


			DROP TABLE IF EXISTS #customerPOList;

			SELECT p.poId, p.companyId, p.supplierId, p.poName, p.poDate, p.poReferenceId, p.shipToId, p.shipvia, p.vesselBooking, p.portofLanding, p.portOfDestination, p.poEarlyShipDate, p.poLateShipDate, 
				p.reference1, p.reference2, p.reference3, p.locNo, p.customerCode,
				li.poDetailsId, li.supplierSku, li.currencyCode, li.invId, li.itemCode, li.unitPrice, li.qty, li.itemStatus, li.itemReference1, li.itemReference2, li.homeCurrencyCost, li.merchantSku, li.poItemDesc, li.soLineItemId
			INTO #customerPOList
			FROM #poConvertList p
				INNER JOIN poLineItem li
					ON p.poId = li.poId
			WHERE li.qty - li.rcvQty > 0
				AND li.itemStatus = 1085

			IF (SELECT COUNT(1) FROM #customerPOList) = 0
			BEGIN
				SET @returnMessage = 'No available qty to be convert.';
			    THROW 60000, @returnMessage, 1;
			END
			
			--IF (SELECT COUNT(1) FROM #customerPOList WHERE unitPrice = 0) > 0
			--BEGIN
			--	SET @returnMessage = 'Unit Cost 0 cannot Raise PO';
			--  THROW 60000, @returnMessage, 1;
			--END

			--IF (SELECT COUNT(1) FROM #customerPOList WHERE homeCurrencyCost = 0) > 0
			--BEGIN
			--	SET @returnMessage = 'Home Currency Cost 0 cannot Raise PO, please contact supervisor to key in daily currency rate';
			--  THROW 60000, @returnMessage, 1;
			--END

            DROP TABLE IF EXISTS #chkSoQty;

            SELECT l.soLineItemId, l.qty, sli.odrQty
            INTO #chkSoQty
            FROM #customerPOList l
                INNER JOIN soLineItem sli
                    ON l.soLineItemId = sli.soLineItemId

            IF (SELECT COUNT(1) FROM #chkSoQty WHERE qty > odrQty) > 0
            BEGIN
                SET @returnMessage = 'PO qty cannot more than SO order qty.';
			    THROW 60000, @returnMessage, 1;
            END

   --         DROP TABLE IF EXISTS #lrInfo;

   --         SELECT p.poDetailsId, p.soLineItemId, p.poId, p.poName, p.qty, lr.qty as lrQty
   --         INTO #lrInfo
   --         FROM #customerPOList p 
   --             INNER JOIN lrLineItem lr
   --                 ON p.soLineItemId = lr.solineItemId
   --                 AND lr.itemStatus = 2129

			--IF (SELECT COUNT(1) FROM #lrInfo) = 0
			--BEGIN
			--	SET @returnMessage = 'Please create/approve LR before raise to supplier.';
			--	THROW 60000, @returnMessage, 1;
			--END

			--IF (SELECT COUNT(1) FROM #lrInfo GROUP BY soLineItemId HAVING SUM(qty) <> SUM(lrQty)) = 0
			--BEGIN
			--	SET @returnMessage = 'PO qty is different with lr qty.';
			--	THROW 60000, @returnMessage, 1;
			--END

		BEGIN TRANSACTION

			DECLARE @poId BIGINT, @companyId INT, @supplierId INT, @poName VARCHAR(50), @foreignCurrencyRate NUMERIC(13,4);
			DECLARE @poRaise VARCHAR(200);

			DECLARE CUR_poConvertList CURSOR LOCAL FOR  
			SELECT DISTINCT poId, companyId, supplierId , poName
			FROM #customerPOList 

			OPEN CUR_poConvertList  
			FETCH NEXT FROM CUR_poConvertList 
			INTO @poId, @companyId, @supplierId, @poName
 
			WHILE @@FETCH_STATUS=0
			BEGIN 
				DECLARE @poCompanyId INT = (SELECT internal_branchId FROM MD_supplier WHERE supplierId =  @supplierId);
				DECLARE @poSupplierId INT = (SELECT configValue FROM md_DefaultConfig WHERE companyId = @poCompanyId AND configName = 'DefaultSupplier');
				DECLARE @poCustomerId INT = (SELECT customerId FROM MD_customer WHERE companyId = @poCompanyId AND internal_branchId = @companyId);
				DECLARE @warehouseId INT = (SELECT TOP 1 warehouseId FROM MD_Warehouse WHERE companyId = @companyId);
				DECLARE @shipToId INT = (SELECT TOP 1 shipToId FROM md_ShipToDestination WHERE warehouseId = @warehouseId);
				DECLARE @shipWay INT = (SELECT TOP 1 shipVia FROM #customerPOList WHERE poId = @poId);

				DECLARE @soName VARCHAR(50);
			 
				DROP TABLE IF EXISTS #soLineItem;

				SELECT po.poDetailsId, po.poId, po.supplierSku, sk.invId, sk.customerSkuId, po.unitPrice, po.qty, po.itemReference1, po.itemReference2, po.currencyCode, po.merchantSku, 
                    CASE WHEN ISNULL(po.poItemDesc, '') = '' THEN sk.itemDesc ELSE po.poItemDesc END as poItemDesc,  po.soLineItemId, sk.tagDivision
				INTO #soLineItem
				FROM #customerPOList po
					LEFT JOIN MD_customerSku sk
						ON po.supplierSKu = sk.customerSku
						AND sk.companyId = @poCompanyId
						AND sk.customerId = @poCustomerId
						AND sk.statusflag = 1

 
				IF (SELECT COUNT(1) FROM #soLineItem where customerSkuId IS NULL) > 0
				BEGIN
					SET @returnMessage = (SELECT 'Supplier Sku ' + STRING_AGG(CONVERT(VARCHAR(MAX), supplierSku), ', ') +  ' not yet created in supplier side.'
					                        FROM (SELECT DISTINCT supplierSku
                                                    FROM #soLineItem
					                                WHERE customerSkuId IS NULL
                                                )g
                                        );
					THROW 60000, @returnMessage, 1;
				END
 
				IF @shipToId IS NULL
				BEGIN
					SET @returnMessage = 'Customer warehouse not yet setup in the system.';
                    THROW 60000, @returnMessage, 1; 
				END
				
				DECLARE @supplierSoHeaderId BIGINT = (SELECT soHeaderId FROM soHeader WHERE customerPO = @poName AND companyId = @poCompanyId);
				

				IF @supplierSoHeaderId IS NULL
				BEGIN

					EXEC [dbo].[SSP_GetRunningNo] 'SO', @poCompanyId, @soName OUTPUT

					IF @soName IS NOT NULL
					BEGIN

						DECLARE @NewOrder TABLE(soHeaderId BIGINT, customerId INT);
						DECLARE @poLineItem TABLE(poDetailsId BIGINT);
						DECLARE @tempSOName VARCHAR(50), @soHeaderId BIGINT;
						DELETE FROM @NewOrder
						DELETE FROM @poLineItem
				 
						SET @tempSOName = 'tempSO_' + @soName;
						-- 1105 SO Open Status
					
						DECLARE @customerPO VARCHAR(500);

						SET @customerPO = (SELECT STRING_AGG(CONVERT(VARCHAR(MAX),poName), ', ')
											FROM (SELECT DISTINCT poName 
													FROM  #customerPOList 
													WHERE poId = @poId) g  
											);							
 
						-- default SO status = 1106 confirm 
						INSERT INTO soHeader(locNo, companyId, customerId, supplierId, soName, soDate, customerPO, thirdParty, thirdPartyPO, reference1, reference2, reference3, 
							shipToId, shipWay, vesselBooking, 
							portOfLanding, portOfDestination, earlyShipDate, lateShipDate, soInvoice, soInvoiceDate, soNote, soStatus, createBy, createDate, apiStatus)
						OUTPUT INSERTED.soHeaderId, INSERTED.customerId 
						INTO @NewOrder
						SELECT DISTINCT locNo, @poCompanyId as companyId, 
							@poCustomerId as customerId, ISNULL(@poSupplierId, 0) as supplierId, 
							@tempSOName as soName, getdate() as soDate, ISNULL(@customerPO, '') as customerPO,  
							customerCode as thirdParty, ISNULL(reference1, '') as thirdPartyPO, poReferenceId, 
							'' as reference2, '' as reference3, ISNULL(@shipToId, 0) as shipToId, ISNULL(@shipWay, '') as shipWay, vesselBooking,
							portOfLanding, portOfDestination, poEarlyShipDate, poLateShipDate, '' as soInvoice, NULL as soInvoiceDate, '' as soNote, 1105 as soStatus, @updateBy, getdate(), NULL as apiStatus
						FROM  #customerPOList 
						WHERE poId = @poId
	 
						SET @soHeaderId = (SELECT soHeaderId FROM @NewOrder);

						IF @soHeaderId IS NULL
						BEGIN
							SET @returnMessage = 'SO number encounter creation problem.';
							THROW 60000, @returnMessage, 1;
						END
						ELSE  
						BEGIN
							INSERT INTO soLineItem(soHeaderId, ref_poLineItemId, invId, customerSkuId, customerSku, csCost, currencyCode, odrQty, 
								itemReference1, itemReference2, soLineItemStatus, merchantSku, soItemDesc, tagDivision, createBy, createDate)
							OUTPUT INSERTED.ref_poLineItemId
							INTO @poLineItem
							SELECT @soHeaderId, poDetailsId, invId, customerSkuId, supplierSku, unitPrice, currencyCode, SUM(qty), 
								itemReference1, itemReference2,
								CASE WHEN tagDivision = 3234 THEN 1105 ELSE 1106 END as soLineItemStatus, merchantSku, poItemDesc, tagDivision, @updateBy, getdate()
							FROM #soLineItem 
							WHERE poId = @poId
							GROUP BY poDetailsId, invId, customerSkuId, supplierSku, unitPrice, currencyCode, 
								itemReference1, itemReference2, merchantSku, poItemDesc, tagDivision
						END
 
						-- If line item status is draft cannot found means it is confirmed
						IF (SELECT COUNT(1) FROM soLineItem WHERE soLineItemStatus = 1105 AND soHeaderId = @soHeaderId) = 0
						BEGIN
							UPDATE soLineItem SET
								soLineItemStatus = 1106
							WHERE soHeaderId = @soHeaderId

							UPDATE soHeader SET
								soStatus = 1106,
								apiStatus = '_NEW_',
								soName = REPLACE(soName, 'tempSO_', '')
							WHERE soHeaderId = @soHeaderId
						END 


						IF (SELECT COUNT(*) FROM @poLineItem) = 0
						BEGIN
							SET @returnMessage = 'SO line items encounter creation problem.';
							THROW 60000, @returnMessage, 1;
						END
					END
					ELSE
					BEGIN
						SET @returnMessage = 'SO number prefix is not configured in the system.';
							THROW 60000, @returnMessage, 1;
					END
				END
				ELSE
				BEGIN
					UPDATE supplierli SET
						odrQty = li.ttlQty,
						updateDate = getdate(),
						updateBy = @updateBy
					FROM soLineItem supplierli
						INNER JOIN (SELECT poDetailsId, SUM(qty) as ttlQty FROM #soLineItem WHERE poId = @poId GROUP BY poDetailsId ) li
							ON supplierli.ref_poLineItemId = li.poDetailsId 
					WHERE supplierli.soheaderId = @supplierSoHeaderId
 
					INSERT INTO soLineItem(soHeaderId, ref_poLineItemId, invId, customerSkuId, customerSku, csCost, currencyCode, odrQty, 
						itemReference1, soLineItemStatus, createBy, createDate)
					SELECT @supplierSoHeaderId, poDetailsId, p.invId, p.customerSkuId, supplierSku, unitPrice, p.currencyCode, SUM(qty), 
						p.itemReference1, 1105, @updateBy, getdate()
					FROM #soLineItem p
						LEFT JOIN soLineItem supplierli
							ON p.poDetailsId = supplierli.ref_poLineItemId
					WHERE poId = @poId
						AND supplierli.soLineItemId IS NULL
					GROUP BY poDetailsId, p.invId, p.customerSkuId, supplierSku, unitPrice, p.currencyCode, unitPrice, 
						p.itemReference1
				END
			
			    UPDATE poHeader SET
				    poStatus = 1077
			    WHERE poId = @poId

			    UPDATE poLineItem SET
				    itemStatus = 1077
			    WHERE poId = @poId

			    DELETE FROM @NewOrder
			
			    INSERT INTO @result(poRefName, poQty)
			    SELECT poName, SUM(qty)
			    FROM #customerPOList
			    WHERE poId = @poId
			    GROUP BY poName
			
			    FETCH NEXT FROM CUR_poConvertList 
			    INTO @poId, @companyId, @supplierId, @poName
		    END

		    CLOSE CUR_poConvertList
		    DEALLOCATE CUR_poConvertList

		COMMIT TRANSACTION
		
		SET @returnMessage = (SELECT STRING_AGG(CONVERT(VARCHAR(MAX), poRefName) + ' : ' + CAST(poQty as VARCHAR) + ' item Qty has raised', ', ')
                                FROM @result
                            );

		SELECT '_SUCCESS_' as execStatus, @returnMessage  as execMessage

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

        IF @returnMessage IS NULL 
            SET @returnMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE()

		SELECT '_FAILURE_' as execStatus, @returnMessage as execMessage

        RETURN -1
	END CATCH
END

GO


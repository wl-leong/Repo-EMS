-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-05-13
-- Used By:	    EMS -> SO Module -> Import Loading Planning

-- Description : 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-05-13	1.0			ZY Wong 	Initial
-- ==========================================================================================
 
-- EXEC [SSP_LoadingRequest_InsertByFileLog] 11, '20240513035536_LR-1.xlsx', 1
CREATE PROCEDURE [dbo].[SSP_LoadingPlanning_InsertByFileLog]
@companyId INT,
@fileLoaded VARCHAR(150),
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY	
            --DECLARE @companyId INT = 11, @fileLoaded VARCHAR(150) = '20240513035536_LR-1.xlsx', @userId INT = '1';

            DECLARE @ErrMessage VARCHAR(MAX);

            DROP TABLE IF EXISTS #tempLP;

            SELECT companyId, containerType, containerSeq, customerName, merchantSku, lrQty, shipDate, shipToLabel, ISNULL(notes,'') as itemNote
            INTO #tempLP
            FROM temp_loadingLlanningLog
            WHERE fileLoaded = @fileLoaded
                AND companyId = @companyId
                AND ISNULL(containerType,'') <> '' AND ISNULL(containerSeq,'') <> ''
 

            IF (SELECT COUNT(1) FROM #tempLP) = 0
            BEGIN
                SET @ErrMessage = 'No data found in '+ @fileLoaded;
			    THROW 60000, @ErrMessage, 1;
            END

            ALTER TABLE #tempLP ADD containerTypeId INT;
            ALTER TABLE #tempLP ADD customerId INT;
            ALTER TABLE #tempLP ADD lateShipDate DATE;
            ALTER TABLE #tempLP ADD shipToId BIGINT;
            ALTER TABLE #tempLP ADD invId BIGINT;
                        
/*** Start: data validation ***/
            
            IF (SELECT COUNT(1) FROM #tempLP WHERE ISNULL(customerName,'') = ''
                    OR ISNULL(merchantSku,'') = ''
                    OR ISNULL(lrQty,'') = ''
                    OR ISNULL(shipDate,'') = ''
                    OR ISNULL(shipToLabel,'') = '' ) > 0
            BEGIN
                SET @ErrMessage = (SELECT 'Customer Name/ Customer Sku/ Lr Qty/ Ship Date/ ShipTo Label are compulsory.');
			    THROW 60000, @ErrMessage, 1;
            END

            IF (SELECT COUNT(1) FROM #tempLP WHERE ISNUMERIC(lrQty) = 0 OR lrQty <= 0 OR ISNUMERIC(containerSeq) = 0 OR containerSeq <= 0) > 0
            BEGIN
                SET @ErrMessage = 'Invalid Container Seq/ Lr Qty, not a positive integer value.';
			    THROW 60000, @ErrMessage, 1;
            END

            UPDATE lp SET
                containerTypeId = ct.categoryId
            FROM #tempLP lp
                INNER JOIN md_mastercategory ct
                    ON lp.containerType = ct.categoryName
                    AND ct.categoryparentId = 3153  -- containerType

            DECLARE @containerTypeList VARCHAR(200) = (SELECT STRING_AGG(CONVERT(VARCHAR(max), categoryName), ', ') FROM md_mastercategory WHERE categoryparentId = 3153)

            IF (SELECT COUNT(1) FROM #tempLP WHERE containerTypeId IS NULL) > 0
            BEGIN
                SET @ErrMessage = 'Invalid Container Type. [' + @containerTypeList + ']';
			    THROW 60000, @ErrMessage, 1;
            END

            IF (SELECT TOP 1 COUNT(DISTINCT containerTypeId) FROM #tempLP GROUP BY containerSeq HAVING COUNT(DISTINCT containerTypeId) > 1) > 0
            BEGIN
                SET @ErrMessage =   (SELECT 'Container Seq ' + STRING_AGG(CONVERT(NVARCHAR(max), containerSeq), ',') + ' have more than ONE Container Type.' as errorMsg
                                        FROM (SELECT containerSeq, COUNT(DISTINCT containerTypeId) as countContainerType 
                                                FROM #tempLP 
                                                GROUP BY containerSeq
                                                HAVING COUNT(DISTINCT containerTypeId) > 1)g
                                        );
            THROW 60000, @ErrMessage, 1;                
            END 

            UPDATE lp SET
                customerId = c.customerId
            FROM #tempLP lp
                INNER JOIN md_Customer c
                    ON lp.customerName = c.customerName
                    AND lp.companyId = c.companyId
                    AND c.[status] = 1

            IF (SELECT COUNT(1) FROM #tempCsSku WHERE customerId IS NULL) > 0
            BEGIN
                SET @ErrMessage =   (SELECT 'Customer ' + STRING_AGG(CONVERT(VARCHAR(max), customerName), ',')  + ' not found in the system.'
                                    FROM (  SELECT DISTINCT customerName 
                                            FROM #tempLP 
                                            WHERE customerId IS NULL
                                        )g 
                                    );
                THROW 60000, @ErrMessage, 1;
            END

            IF (SELECT COUNT(DISTINCT customerId) FROM #tempLP) > 1
            BEGIN
                SET @ErrMessage = 'File uploaded have more than ONE customer.';
                THROW 60000, @ErrMessage, 1;
            END

            IF (SELECT COUNT(DISTINCT shipDate) FROM #tempLP) > 1
            BEGIN
                SET @ErrMessage = 'File uploaded have different ship Date.';
                THROW 60000, @ErrMessage, 1;
            END 

            UPDATE lp SET
                shipToId = st.shipToId,
                lateShipDate = DATEADD(day, 8, shipDate)
            FROM #tempLP lp
                INNER JOIN md_shipToDestination st
                    ON lp.shipToLabel = st.shipToLabel
                    AND lp.customerId = st.customerId
                    AND lp.companyId = st.companyId

            IF (SELECT COUNT(DISTINCT shipToId) FROM #tempLP) > 1
            BEGIN
                SET @ErrMessage = 'File uploaded have more than ONE destination.';
                THROW 60000, @ErrMessage, 1;
            END

            UPDATE lr SET
                invId = sku.invId
            FROM #tempLP lp
                INNER JOIN md_CustomerSku sku
                    ON lp.merchantSku = sku.merchantSku
                    AND lp.customerId = sku.customerId
                    AND lp.companyId = sku.companyId
                    AND sku.statusflag = 1

            IF (SELECT COUNT(1) FROM #tempLP WHERE invId IS NULL) > 0
            BEGIN 
                SET @ErrMessage = (SELECT 'Merchant Sku ' + STRING_AGG(CONVERT(NVARCHAR(max), merchantSku), ',') + ' not found in the system.'
                                     FROM (SELECT DISTINCT merchantSku 
                                            FROM #tempLP 
                                            WHERE invId IS NULL)g
                                    );
			    THROW 60000, @ErrMessage, 1;
            END
         
/*** End: data validation ***/
/*
		    BEGIN TRANSACTION
		
                DECLARE @lpName VARCHAR(50) = '', @tempLPName VARCHAR(50);

                EXEC [dbo].[SSP_GetRunningNo] 'LPLN', @companyId, @lpName OUTPUT

                IF @lpName IS NOT NULL
                BEGIN
                    SET @tempLPName = 'tempLP_' + @lpName

                    DECLARE @newLp TABLE (loadingPlanningId BIGINT, lpName VARCHAR(50))
                    DECLARE @loadingPlanningId BIGINT;
                    
                -- create LP header
                    INSERT INTO loadingPlanning (companyId, supplierId, lrName, lrDate, lrShipDate, lrStatus, enterBy, enterDate)          
                    OUTPUT INSERTED.lrHeaderId, INSERTED.lrName
                    INTO @newLr
                    SELECT DISTINCT @companyId, @supplierId, @tempLRName as lrName, getdate() as lrDate, @earlyShipDate, 2132 as lrStatus, @userId, getdate() as enterDate
 
         
                    SELECT @lrHeaderId = lrHeaderId, @lrName = lrName
                    FROM @newLr

                    IF @lrHeaderId IS NULL
                    BEGIN
                        SET @ErrMessage = 'LR number encounter creation problem.'; 
                        THROW 60000, @ErrMessage, 1;
                    END
 
                    DECLARE @newLrLineItem TABLE (poLineItemId BIGINT, qty INT)

                    INSERT INTO lrLineItem (lrHeaderId, lrName, soHeaderId, soLineItemId, poHeaderId, poLineItemId, earlyShipDate, lateShipDate, shipToId, supplierSku, invId, qty, confirmQty, containerTypeId, containerSeq, 
                                    itemNote, itemStatus, enterBy, enterDate)
                    OUTPUT INSERTED.poLineItemId, INSERTED.qty
                    INTO @newLrLineItem
                    SELECT @lrHeaderId, @lrName, soHeaderId, soLineItemId, poHeaderId, poLineItemId, earlyShipDate, lateShipDate, shipToId, supplierSku, invId, lrQty, 0 as confirmQty, containerTypeId, containerSeq, 
                            itemNote, 2132 as itemStatus, @userId, getdate() as enterDate
                    FROM #tempLP lr
                    
                    IF (SELECT COUNT(1) FROM @newLrLineItem) < 1
                    BEGIN
                        SET @ErrMessage = 'Insert LR LineItem failed.'; 
                        THROW 60000, @ErrMessage, 1;
                    END

                    UPDATE pl SET
                        lrQty = pl.lrQty + l.qty,
                        updateBy = @userId,
                        updateDate = getdate()
                    FROM poLineItem pl
                        INNER JOIN (SELECT poLineItemId, SUM(qty) as qty FROM @newLrLineItem GROUP BY poLineItemId) l
                            ON pl.poDetailsId = l.poLineItemId
                END
                ELSE
                BEGIN  
                    SET @ErrMessage = 'LR number encounter creation problem'; 
                    THROW 60000, @ErrMessage, 1;
                END

		    COMMIT TRANSACTION

		--DELETE FROM temp_lrLog WHERE fileLoaded = @fileLoaded

		SELECT '_SUCCESS_' as status, 'LR has been successful import. LR # ' + @lrName as returnMessage
*/				
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
 
		--DELETE FROM temp_lrLog WHERE fileLoaded = @fileLoaded

        IF @ErrMessage IS NULL 
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE()

		SELECT
			'_FAILURE_' as status, @ErrMessage as returnMessage

		RETURN -1
	END CATCH
END

GO


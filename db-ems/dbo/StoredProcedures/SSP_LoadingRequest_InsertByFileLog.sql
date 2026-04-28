-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-05-13
-- Used By:	    EMS -> LR Module -> Import LR

-- Description : 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-08-13   11.0        ZY Wong     Remove cartonMaterial, cartonQty
-- 2025-06-05   10.2        ZY Wong     Remove validation for cartonMaterial exists in system, only check for empty if any of cartonMaterial/cartonQty/qtyPerCarton passed in
-- 2025-05-28   10.1        ZY Wong     Add poDetailsId, Add validation if pod empty
-- 2025-05-27   10.0        WL Leong 	Get the portId from import file, add cartonMaterial, cartonQty, qtyPerCarton 
-- 2025-05-02   9.0         ZY Wong     Remove pass notes into lrHeader.lrNote, pass notes into lrContainer.notes, add validation check same container seq have more than 1 notes
-- 2025-04-29   8.0         ZY Wong     Add validation check open lr qty
-- 2025-03-24   7.0         ZY Wong     Add lrNote for lrHeader, remove pass in notes for lrLineItem and lrContainer
-- 2025-03-11   6.0         ZY Wong     Add validation check invalid pod, use portId value for [shipToId] column
-- 2025-01-02   5.0         WL Leong 	Denormalise lrLineItem to lrContainer
-- 2024-06-19   4.0         ZY Wong     Add latest column
-- 2024-06-04   3.0         ZY Wong     Allow different shipTo but with same pod
-- 2024-05-16	2.0			WL Leong 	Add cargo ready date = 2 days before earlyshipdate
-- 2024-05-13	1.0			ZY Wong 	Initial
-- ==========================================================================================
-- SELECT * FROM temp_lrLog order by 1 desc 
-- EXEC [SSP_LoadingRequest_InsertByFileLog] 11, '20250528073131_LR-Template-2025-05-28-03-46-13-211.xlsx', 1
CREATE PROCEDURE [dbo].[SSP_LoadingRequest_InsertByFileLog]
@companyId INT,
@fileLoaded VARCHAR(150),
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY	
    /** 1 file = 1 LR , multiple container seq is allowed **/

        --DECLARE @companyId INT = 11, @fileLoaded VARCHAR(150) = '20250528073131_LR-Template-2025-05-28-03-46-13-211.xlsx', @userId INT = '1';
        SET DATEFORMAT YMD
 
        DECLARE @ErrMessage VARCHAR(MAX);

        DROP TABLE IF EXISTS #tempLR;

        SELECT DISTINCT companyId, poName, customerPo, pod, productName, supplierSku, merchantSku, lrQty, CONVERT(VARCHAR(10), shipDate, 126) as shipDate, containerType, containerSeq, ISNULL(notes,'') as notes
			, qtyPerCarton, poDetailsId
		INTO #tempLR
        FROM temp_lrLog
        WHERE fileLoaded = @fileLoaded
            AND companyId = @companyId
            AND ISNULL(poName,'') <> ''

        IF (SELECT COUNT(1) FROM #tempLR) = 0
        BEGIN
            SET @ErrMessage = 'No data found in '+ @fileLoaded;
			THROW 60000, @ErrMessage, 1;
        END

        ALTER TABLE #tempLR ADD poId BIGINT;
        ALTER TABLE #tempLR ADD supplierId INT;
        ALTER TABLE #tempLR ADD lateShipDate DATE;
        ALTER TABLE #tempLR ADD portId INT;

        ALTER TABLE #tempLR ADD invId BIGINT;
        ALTER TABLE #tempLR ADD soLineItemId BIGINT;
        ALTER TABLE #tempLR ADD containerTypeId INT;
        ALTER TABLE #tempLR ADD soHeaderId BIGINT;
		ALTER TABLE #tempLR ADD lrContainerId BIGINT;
                        
/*** Start: data validation ***/
            
        -- check empty value
        IF (SELECT COUNT(1) FROM #tempLR WHERE ISNULL(customerPo,'') = '' OR ISNULL(pod,'') = '' OR ISNULL(supplierSku,'') = '' OR ISNULL(merchantSku,'') = '' OR ISNULL(lrQty,'') = ''
                OR ISNULL(shipDate,'') = '' OR ISNULL(containerType,'') = '' OR ISNULL(containerSeq,'') = '' OR ISNULL(poDetailsId,'') = '') > 0
        BEGIN
            SET @ErrMessage = (SELECT 'Customer PO/ POD/ Supplier Sku/ Merchant Sku/ Lr Qty/ Ship Date/ Container Type/ Container Seq/ PO Details ID are compulsory.');
			THROW 60000, @ErrMessage, 1;
        END

        -- check invalid numeric for lrQty, containerSeq
        IF (SELECT COUNT(1) FROM #tempLR WHERE ISNUMERIC(lrQty) = 0 OR lrQty <= 0 
            OR ISNUMERIC(containerSeq) = 0 OR containerSeq <= 0) > 0
        BEGIN
            SET @ErrMessage = 'Invalid Lr Qty/ Container Seq, not a positive integer value.';
			THROW 60000, @ErrMessage, 1;
        END

        UPDATE #tempLR SET
            portId = p.portId
        FROM md_port p
        WHERE #tempLR.pod = p.portName
 
        -- check multiple pod
        IF (SELECT COUNT(DISTINCT portId) FROM #tempLR) > 1
        BEGIN
            SET @ErrMessage = 'Multiple POD is not allowed in 1 LR.';
            THROW 60000, @ErrMessage, 1;
        END

        -- check expired ship date
        IF (SELECT COUNT(1) FROM #tempLR WHERE shipDate <= CONVERT(DATE, GETDATE())) > 0
        BEGIN
            SET @ErrMessage =   (SELECT 'PO # ' + STRING_AGG(CONVERT(VARCHAR(max), poName), ',')  + ' have expired ship date.'
                                FROM (  SELECT DISTINCT poName 
                                        FROM #tempLR 
                                        WHERE shipDate <= CONVERT(DATE, GETDATE())
                                    )g 
                                );
            THROW 60000, @ErrMessage, 1;
        END

        -- check multiple ship date
        IF (SELECT COUNT(DISTINCT shipDate) FROM #tempLR) > 1
        BEGIN
            SET @ErrMessage =   (SELECT 'PO # ' + STRING_AGG(CONVERT(VARCHAR(max), poName), ',')  + ' have different ship date.'
                                FROM (  SELECT DISTINCT poName 
                                        FROM #tempLR 
                                    )g 
                                );
            THROW 60000, @ErrMessage, 1;
        END

        UPDATE lr SET
            poId = p.poId,
            supplierId = p.supplierId
        FROM #tempLR lr
            INNER JOIN poHeader p
                ON lr.poName = p.poName
                AND lr.companyId = p.companyId

        -- check invalid PO
        IF (SELECT COUNT(1) FROM #tempLR WHERE poId IS NULL) > 0
        BEGIN
            SET @ErrMessage =   (SELECT 'PO # ' + STRING_AGG(CONVERT(VARCHAR(max), poName), ',')  + ' not found in the system.'
                                FROM (  SELECT DISTINCT poName 
                                        FROM #tempLR 
                                        WHERE poId IS NULL
                                    )g 
                                );
            THROW 60000, @ErrMessage, 1;
        END  
        
        -- check multiple supplier
        IF (SELECT COUNT(DISTINCT supplierId) FROM #tempLR) > 1
        BEGIN
            SET @ErrMessage = 'PO # from file uploaded have more than ONE supplier.';
            THROW 60000, @ErrMessage, 1;
        END        
                 
        -- check invalid poDetailsId
        DROP TABLE IF EXISTS #checkPoItems;

        SELECT lr.poId, lr.poDetailsId, pli.invId, pli.soLineItemId
        INTO #checkPoItems
        FROM #tempLR lr
            LEFT JOIN poLineItem pli 
                ON lr.poId = pli.poId
                AND lr.poDetailsId = pli.poDetailsId

        IF (SELECT COUNT(1) FROM #checkPoItems WHERE invId IS NULL) > 0
        BEGIN
            SET @ErrMessage =   (SELECT 'PO Details Id ' + STRING_AGG(CONVERT(VARCHAR(max), poDetailsId), ',')  + ' not found in the system.'
                                FROM (  SELECT DISTINCT poDetailsId 
                                        FROM #checkPoItems 
                                        WHERE invId IS NULL
                                    )g 
                                );
            THROW 60000, @ErrMessage, 1;
        END
            
        UPDATE lr SET
            invId = pli.invId,
            soLineItemId = pli.soLineItemId
        FROM #tempLR lr
            INNER JOIN #checkPoItems pli
                ON lr.poDetailsId = pli.poDetailsId

        -- check open lr qty
        DROP TABLE IF EXISTS #checkLrQty;

        SELECT poId, poDetailsId, poName, supplierSku, SUM(CONVERT(INT, lrQty)) as newLrQty
        INTO #checkLrQty
        FROM #tempLR
        GROUP BY poId, poDetailsId, poName, supplierSku

        ALTER TABLE #checkLrQty ADD openLrQty INT;

        UPDATE clr SET
            openLrQty = pli.qty - pli.lrQty
        FROM #checkLrQty clr
            INNER JOIN poLineItem pli
                ON clr.poDetailsId = pli.poDetailsId

        IF (SELECT COUNT(1) FROM #checkLrQty WHERE newLrQty > openLrQty) > 0
        BEGIN
            SET @ErrMessage =   (SELECT STRING_AGG(CONVERT(NVARCHAR(max), errorMsg), ' ')
                                    FROM ( SELECT poName, 'Supplier Sku ' + STRING_AGG(CONVERT(NVARCHAR(max), supplierSku), ',') + ' (' + poName + ') have LR qty more than PO order qty.' as errorMsg
                                        FROM (SELECT poName, supplierSku 
                                                FROM #checkLrQty 
                                                WHERE newLrQty > openLrQty ) h
                                        GROUP BY poName
                                    )g
                                );
            THROW 60000, @ErrMessage, 1;                
        END

        -- check invalid supplier sku
        IF (SELECT COUNT(1) FROM #tempLR WHERE invId IS NULL) > 0
        BEGIN 
            SET @ErrMessage = (SELECT 'Supplier Sku ' + STRING_AGG(CONVERT(NVARCHAR(max), supplierSku), ',') + ' not found in the system.'
                                    FROM (SELECT DISTINCT supplierSku 
                                        FROM #tempLR 
                                        WHERE invId IS NULL)g
                                );
			THROW 60000, @ErrMessage, 1;
        END

        -- check invalid item sku for that PO
        IF (SELECT COUNT(1) FROM #tempLR WHERE poDetailsId IS NULL) > 0
        BEGIN
            SET @ErrMessage = (SELECT STRING_AGG(CONVERT(NVARCHAR(max), errorMsg), '.')
                                    FROM (SELECT poName, 'Supplier Sku ' + STRING_AGG(CONVERT(NVARCHAR(max), supplierSku), ',') + ' not found in PO # ' + poName as errorMsg 
                                        FROM (SELECT poName, supplierSku 
                                                FROM #tempLR 
                                                WHERE poDetailsId IS NULL) h
                                        GROUP BY poName
                                        )g
                                );
			THROW 60000, @ErrMessage, 1;
        END
      
        UPDATE lr SET
            containerTypeId = ct.categoryId
        FROM #tempLR lr
            INNER JOIN md_mastercategory ct
                ON lr.containerType = ct.categoryName
                AND ct.categoryparentId = 3153  -- containerType

        DECLARE @containerTypeList VARCHAR(200) = (SELECT STRING_AGG(CONVERT(VARCHAR(max), categoryName), ', ') FROM md_mastercategory WHERE categoryparentId = 3153);

        -- check invalid container type
        IF (SELECT COUNT(1) FROM #tempLR WHERE containerTypeId IS NULL) > 0
        BEGIN
            SET @ErrMessage = 'Invalid Container Type. [' + @containerTypeList + ']';
			THROW 60000, @ErrMessage, 1;
        END

        -- check multiple container type 
        IF (SELECT TOP 1 COUNT(DISTINCT containerTypeId) FROM #tempLR GROUP BY containerSeq HAVING COUNT(DISTINCT containerTypeId) > 1) > 0
        BEGIN
            SET @ErrMessage =   (SELECT 'Container Seq ' + STRING_AGG(CONVERT(NVARCHAR(max), containerSeq), ',') + ' have more than ONE Container Type.' as errorMsg
                                    FROM (SELECT containerSeq, COUNT(DISTINCT containerTypeId) as countContainerType 
                                            FROM #tempLR 
                                            GROUP BY containerSeq
                                            HAVING COUNT(DISTINCT containerTypeId) > 1)g
                                    );
        THROW 60000, @ErrMessage, 1;                
        END

        -- check same container seq have more than 1 notes
        IF (SELECT TOP 1 COUNT(DISTINCT notes) FROM #tempLR GROUP BY containerSeq HAVING COUNT(DISTINCT notes) > 1) > 0
        BEGIN
            SET @ErrMessage =   (SELECT 'Container Seq ' + STRING_AGG(CONVERT(NVARCHAR(max), containerSeq), ',') + ' have more than ONE Notes.' as errorMsg
                                    FROM (SELECT containerSeq, COUNT(DISTINCT notes) as countNotes 
                                            FROM #tempLR 
                                            GROUP BY containerSeq
                                            HAVING COUNT(DISTINCT notes) > 1)g
                                    );
        THROW 60000, @ErrMessage, 1;                
        END


        UPDATE lr SET
            soHeaderId = s.soHeaderId
        FROM #tempLR lr
            INNER JOIN soLineItem s
                ON lr.soLineItemId = s.soLineItemId

        UPDATE #tempLR SET
			lateShipDate = DATEADD(DAY, 9, shipDate) 

/*** End: data validation ***/

        DECLARE @supplierId INT = (SELECT TOP 1 supplierId FROM #tempLR);
        DECLARE @shipDate DATE = (SELECT TOP 1 shipDate FROM #tempLR);

		BEGIN TRANSACTION
		
            DECLARE @lrName VARCHAR(50) = '', @tempLRName VARCHAR(50);

            EXEC [dbo].[SSP_GetRunningNo] 'LR', @companyId, @lrName OUTPUT

            IF @lrName IS NOT NULL
            BEGIN
                SET @tempLRName = 'tempLR_' + @lrName;

                DECLARE @newLr TABLE (lrHeaderId BIGINT, lrName VARCHAR(50));
				DECLARE @newLrContainer TABLE (lrContainerId BIGINT, containerSeq INT);
                DECLARE @lrHeaderId BIGINT, @lrContainerId BIGINT;

                INSERT INTO lrHeader (companyId, supplierId, lrName, lrDate, lrShipDate, lrStatus, enterBy, enterDate)          
                OUTPUT INSERTED.lrHeaderId, INSERTED.lrName
                INTO @newLr
                SELECT DISTINCT @companyId, @supplierId, @tempLRName as lrName, getdate() as lrDate, @shipDate, 2132 as lrStatus, @userId, getdate() as enterDate
        
                SELECT @lrHeaderId = lrHeaderId, @lrName = lrName
                FROM @newLr

                IF @lrHeaderId IS NULL
                BEGIN
                    SET @ErrMessage = 'LR number encounter creation problem.'; 
                    THROW 60000, @ErrMessage, 1;
                END

				INSERT INTO lrContainer(lrHeaderId, lrName, containerTypeId, containerSeq, portId, earlyShipDate, lateShipDate, notes, cargoReadyDate, containerStatus, enterBy, enterDate)
				OUTPUT INSERTED.lrContainerId, INSERTED.containerSeq
				INTO @newLrContainer
				SELECT DISTINCT @lrHeaderId, @lrName, containerTypeId, containerSeq, portId, shipDate, lateShipDate, notes, DATEADD(Day, -2, shipDate) as cargoReadyDate, 2132 as containerStatus, @userId, getdate() as enterDate
				FROM #tempLR lr
 
				UPDATE #tempLR SET
					lrContainerId = n.lrContainerId
				FROM @newLrContainer n
				WHERE #tempLR.containerSeq = n.containerSeq

                DECLARE @newLrLineItem TABLE (poDetailsId BIGINT, qty INT)

                INSERT INTO lrLineItem (lrHeaderId, lrName, lrContainerId, soHeaderId, soLineItemId, poId, poDetailsId, supplierSku, invId, qty, confirmQty, itemStatus, enterBy, enterDate, qtyPerCarton)
                OUTPUT INSERTED.poDetailsId, INSERTED.qty
                INTO @newLrLineItem
                SELECT @lrHeaderId, @lrName, lrContainerId, soHeaderId, soLineItemId, poId, poDetailsId, supplierSku, invId, CONVERT(INT, lrQty), 0 as confirmQty, 2132 as itemStatus, @userId, getdate() as enterDate, qtyPerCarton
				FROM #tempLR lr
                    
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
                    INNER JOIN (SELECT poDetailsId, SUM(qty) as qty FROM @newLrLineItem GROUP BY poDetailsId) l
                        ON pl.poDetailsId = l.poDetailsId
            END
            ELSE
            BEGIN  
                SET @ErrMessage = 'LR number encounter creation problem.'; 
                THROW 60000, @ErrMessage, 1;
            END

		COMMIT TRANSACTION

		--DELETE FROM temp_lrLog WHERE fileLoaded = @fileLoaded

        SET @ErrMessage = 'LR has been successful import. LR # ' + @lrName;

		SELECT '_SUCCESS_' as status, @ErrMessage as returnMessage
				
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


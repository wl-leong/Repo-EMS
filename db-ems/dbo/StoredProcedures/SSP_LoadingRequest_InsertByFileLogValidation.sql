-- =============================================
-- Author:		ZY Wong
-- Create date: 2025-04-30
-- Used By:	    EMS -> LR Module -> Import LR

-- Description : Check partial lr qty and throw confirmation alert

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-04-30	1.0			ZY Wong 	Initial
-- ==========================================================================================
/**
EXEC [SSP_LoadingRequest_InsertByFileLogValidation] 11,'20250610033721_LR-Template-2025-06-10-partial.xlsx',1
**/

CREATE PROCEDURE [dbo].[SSP_LoadingRequest_InsertByFileLogValidation]
@companyId INT,
@fileLoaded VARCHAR(150),
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
        
        /*
        DECLARE @companyId INT = 11, @fileLoaded VARCHAR(150) = '20250429050909_LR-Template-2025-04-29-04-36-06-412.xlsx', @userId INT = 1,
        @isAlert INT, @alertMessage VARCHAR(200) 
        */

        DECLARE @ErrMessage VARCHAR(MAX);
        DECLARE @isAlert INT, @alertMessage VARCHAR(200);


        DROP TABLE IF EXISTS #tempLR;

        SELECT DISTINCT companyId, poName, customerPo, pod, productName, supplierSku, merchantSku, lrQty, CONVERT(VARCHAR(10), shipDate, 126) as shipDate, containerType, containerSeq, ISNULL(notes,'') as notes
            , qtyPerCarton, poDetailsId
        INTO #tempLR
        FROM temp_lrLog
        WHERE fileLoaded = @fileLoaded
            AND companyId = @companyId
            AND ISNULL(poName,'') <> ''

        ALTER TABLE #tempLR ADD poId BIGINT;
        ALTER TABLE #tempLR ADD invId BIGINT;
        ALTER TABLE #tempLR ADD soLineItemId BIGINT;
                                    
        UPDATE lr SET
            poId = p.poId
        FROM #tempLR lr
            INNER JOIN poHeader p
                ON lr.poName = p.poName
                AND lr.companyId = p.companyId
            
        UPDATE lr SET
            invId = pli.invId,
            soLineItemId = pli.soLineItemId
        FROM #tempLR lr
            INNER JOIN poLineItem pli
                ON lr.supplierSku = pli.supplierSku
                AND lr.merchantSku = pli.merchantSku
                AND lr.poId = pli.poId

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

        -- check partial lr qty
        IF (SELECT COUNT(1) FROM #checkLrQty WHERE newLrQty <> openLrQty AND newLrQty <= openLrQty) > 0
        BEGIN
            SET @ErrMessage =   ( SELECT 'Supplier Sku ' + supplierSku + ' (' + poName + ') have LR qty ' + CAST(newLrQty as VARCHAR) + 
                                                ' from file and remaining PO order qty are ' + CAST(openLrQty as VARCHAR) + ', are you sure to create partial LR?' as errorMsg
                                        FROM (SELECT TOP 1 poName, supplierSku, newLrQty, openLrQty 
                                                FROM #checkLrQty 
                                                WHERE newLrQty <> openLrQty 
                                                    AND newLrQty <= openLrQty) h
                                    
                                );
        END

        IF @ErrMessage IS NOT NULL
        BEGIN
            SET @isAlert = 1;
            SET @alertMessage = @ErrMessage;
        END
        ELSE
        BEGIN
            SET @isAlert = 0;
            SET @alertMessage = @ErrMessage;
        END

        SELECT @isAlert as isAlert, @alertMessage as alertMessage

    END

GO


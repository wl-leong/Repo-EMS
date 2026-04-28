-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-05-13
-- Used By:	    EMS -> PO Module -> PO Listing -> (status: Approved/ Released) Export LR Template

-- Description : Export PO to LR template for user to upload in 'LR -> Import', allow multiselect

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-08-13   5.0         ZY Wong     Remove cartonMaterial, cartonQty
-- 2025-05-28   4.0         ZY Wong     Return cartonMaterial, cartonQty, qtyPerCarton, poDetailsId
-- 2024-05-11   3.0         ZY Wong     Change get portName from md_Port
-- 2024-06-19	2.3		    WL Leong 	Change to use SO Header
-- 2024-06-17	2.2			WL Leong 	Add in product name
-- 2024-06-06	2.1			WL Leong 	Add in POD, merchantSku
-- 2024-06-05	2.0			WL Leong 	Add in customer po#
-- 2024-05-13	1.0			ZY Wong 	Initial
-- ==========================================================================================
-- EXEC SSP_SalesOrder_ExportLRTemplate N'{"soList":[{"soHeaderId":"41416"}]}'
 
CREATE PROCEDURE [dbo].[SSP_SalesOrder_ExportLRTemplate]
@Json NVARCHAR(MAX)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
            
            --DECLARE @Json NVARCHAR(MAX) = N'{"soList":[{"soHeaderId":"20833"},{"soHeaderId":"20838"}]}';

            DECLARE @ErrMessage VARCHAR(MAX);

            DROP TABLE IF EXISTS #soList;

			SELECT * 
			INTO #soList
			FROM  OPENJSON(@Json, '$.soList') 
   				WITH (
					soHeaderId BIGINT	N'$.soHeaderId'
				)

            DROP TABLE IF EXISTS #soInfo;
  
            SELECT l.soHeaderId, so.soName, so.soStatus 
            INTO #soInfo
            FROM #soList l
                INNER JOIN soHeader so
                    ON l.soHeaderId = so.soHeaderId

            IF (SELECT COUNT(1) FROM #soInfo WHERE soStatus NOT IN (2125)) > 0
            BEGIN
                SET @ErrMessage = (SELECT 'SO # ' + STRING_AGG(CONVERT(VARCHAR(max), soName), ',') + ', only [IN PRODUCTION] SO''s are allowed to export.' 
                                    FROM (SELECT soName 
                                            FROM #soInfo 
                                            WHERE soStatus NOT IN (2125))g
                                   );
			    THROW 60000, @ErrMessage, 1;
            END


            DROP TABLE IF EXISTS #poInfo;
  
            SELECT po.poId, po.poName, po.poStatus, po.companyId, po.shipToId, st.pod, po.reference1, po.supplierId, CONVERT(VARCHAR(8), REPLACE(po.poEarlyShipDate,'-','')) as shipDate
            INTO #poInfo
            FROM #soInfo s
                INNER JOIN poHeader po
                   ON s.soName = po.poReferenceId
                INNER JOIN md_shipToDestination st
                    ON po.shipToid = st.shipToId

            ALTER TABLE #poInfo ADD portName VARCHAR(50);

            UPDATE #poInfo SET
                portName = p.portName
            FROM md_Port p
            WHERE #poInfo.pod = p.portId
 
            IF (SELECT COUNT(1) FROM #poInfo WHERE poStatus NOT IN (1077, 1085)) > 0  -- approved, released
            BEGIN
                SET @ErrMessage = (SELECT 'PO # ' + STRING_AGG(CONVERT(VARCHAR(max), poName), ',') + ', only APPROVED/ RELEASED PO''s are allowed to export.' 
                                    FROM (SELECT poName 
                                            FROM #poInfo 
                                            WHERE poStatus NOT IN (1077, 1085))g
                                   );
			    THROW 60000, @ErrMessage, 1;
            END

            DECLARE @companyId INT = (SELECT TOP 1 companyId FROM #poInfo);
            DECLARE @supplierId INT = (SELECT TOP 1 supplierId FROM #poInfo);

            DROP TABLE IF EXISTS #poItem;

            SELECT po.poName, po.reference1, po.portName as pod, pl.invId, supplierSku, pl.merchantSku, pl.qty-lrQty as qty, shipDate, poDetailsId
            INTO #poItem
            FROM poLineItem pl
                INNER JOIN #poInfo po
                    ON pl.poId = po.poId
            WHERE pl.itemStatus IN (1077, 1085) -- approved, released   
                AND pl.qty-lrQty > 0

            SELECT poName, reference1 as customerPo, pod, inv.productName, p.supplierSku, merchantSku, qty, shipDate, '' as containerType, '' as containerSeq, '' as notes, 
                '' as qtyPerCarton, poDetailsId
            FROM #poItem p 
                INNER JOIN md_inventory inv
                    ON p.invId = inv.invId
            ORDER BY poName
 
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
 
        IF @ErrMessage IS NULL 
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE()
 
		SELECT
			'_FAILURE_' as status, @ErrMessage as returnMessage

		RETURN -1
	END CATCH
END

GO


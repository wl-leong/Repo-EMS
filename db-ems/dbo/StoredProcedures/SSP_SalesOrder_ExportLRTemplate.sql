-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-05-13
-- Description: Export Approved/ Released PO to LR template for user to upload in 'LR Module -> Import LR', allow multiselect
-- Used By:		EMS -> SO Module -> SO Listing -> (PO status: Approved/ Released) Export LR Template
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2026-10-02	6.0			ZY Wong		Restructure sp, link poLineItem via soLineItemId
-- 2025-08-13	5.0			ZY Wong		Remove cartonMaterial, cartonQty
-- 2025-05-28	4.0			ZY Wong		Return cartonMaterial, cartonQty, qtyPerCarton, poDetailsId
-- 2024-05-11	3.0			ZY Wong		Change get portName from md_Port
-- 2024-06-19	2.3			WL Leong	Change to use SO Header
-- 2024-06-17	2.2			WL Leong	Add in product name
-- 2024-06-06	2.1			WL Leong	Add in POD, merchantSku
-- 2024-06-05	2.0			WL Leong	Add in customer po#
-- 2024-05-13	1.0			ZY Wong		Initial
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
 
			SELECT so.soHeaderId, so.soName, so.soStatus, li.soLineItemId
			INTO #soInfo
			FROM #soList l
				INNER JOIN soHeader so
					ON l.soHeaderId = so.soHeaderId
				INNER JOIN soLineItem li
					ON so.soHeaderId = li.soHeaderId

			IF EXISTS (SELECT 1 FROM #soInfo WHERE soStatus NOT IN (2125))  -- so: in production
			BEGIN
				SET @ErrMessage = (SELECT 'SO # ' + STRING_AGG(CONVERT(VARCHAR(MAX), soName), ',') + ', only [IN PRODUCTION] SO''s are allowed to export.' 
									FROM (SELECT DISTINCT soName 
											FROM #soInfo 
											WHERE soStatus NOT IN (2125))g
								   );
				THROW 60000, @ErrMessage, 1;
			END

			DROP TABLE IF EXISTS #poInfo;

			SELECT po.poId, po.poName, po.shipToId, po.reference1, CONVERT(VARCHAR(8), REPLACE(po.poEarlyShipDate,'-','')) as shipDate, po.poStatus, li.poDetailsId
			INTO #poInfo
			FROM #soInfo s
				INNER JOIN poLineItem li
					ON s.soLineItemId = li.soLineItemId
				INNER JOIN poHeader po
				   ON li.poId = po.poId

			ALTER TABLE #poInfo ADD portId VARCHAR(50);
			ALTER TABLE #poInfo ADD pod VARCHAR(50);

			UPDATE #poInfo SET
				portId = st.pod
			FROM md_shipToDestination st
			WHERE #poInfo.shipToId = st.shipToId

			UPDATE #poInfo SET
				pod = p.portName
			FROM md_Port p
			WHERE #poInfo.portId = p.portId
 
			IF EXISTS (SELECT 1 FROM #poInfo WHERE poStatus NOT IN (1077, 1085))  -- po: approved, released
			BEGIN
				SET @ErrMessage = (SELECT 'PO # ' + STRING_AGG(CONVERT(VARCHAR(MAX), poName), ',') + ', only APPROVED/ RELEASED PO''s are allowed to export.' 
									FROM (SELECT DISTINCT poName 
											FROM #poInfo 
											WHERE poStatus NOT IN (1077, 1085))g
								   );
				THROW 60000, @ErrMessage, 1;
			END

			DROP TABLE IF EXISTS #poItem;

			SELECT po.poName, po.reference1, po.pod, li.invId, li.supplierSku, li.merchantSku, li.qty - li.lrQty as qty, po.shipDate, li.poDetailsId
			INTO #poItem
			FROM poLineItem li
				INNER JOIN #poInfo po
					ON li.poDetailsId = po.poDetailsId
			WHERE li.itemStatus IN (1077, 1085) -- po: approved, released   
				AND li.qty - li.lrQty > 0

			SELECT p.poName, p.reference1 as customerPo, p.pod, inv.productName, p.supplierSku, p.merchantSku, p.qty, p.shipDate, '' as containerType, '' as containerSeq, '' as notes, 
				'' as qtyPerCarton, p.poDetailsId
			FROM #poItem p 
				INNER JOIN md_inventory inv
					ON p.invId = inv.invId
			ORDER BY p.poName

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
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

			SELECT soHeaderId
			INTO #soList
			FROM OPENJSON(@Json, '$.soList') 
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

			SELECT po.poName, po.shipToId, po.reference1, CONVERT(VARCHAR(8), REPLACE(po.poEarlyShipDate,'-','')) as shipDate, po.poStatus, 
				li.poDetailsId, li.invId, inv.productName, li.supplierSku, li.merchantSku, li.qty - li.lrQty as qty
			INTO #poInfo
			FROM #soInfo s
				INNER JOIN poLineItem li
					ON s.soLineItemId = li.soLineItemId
				INNER JOIN poHeader po
					ON li.poId = po.poId
				INNER JOIN md_Inventory inv
					ON li.invId = inv.invId
			WHERE li.itemStatus IN (1077, 1085) -- po: approved, released   
				AND li.qty - li.lrQty > 0

			IF EXISTS (SELECT 1 FROM #poInfo WHERE poStatus NOT IN (1077, 1085))  -- po: approved, released
			BEGIN
				SET @ErrMessage = (SELECT 'PO # ' + STRING_AGG(CONVERT(VARCHAR(MAX), poName), ',') + ', status is not APPROVED/ RELEASED. Please check the PO status before export.' 
									FROM (SELECT DISTINCT poName 
											FROM #poInfo 
											WHERE poStatus NOT IN (1077, 1085))g
								   );
				THROW 60000, @ErrMessage, 1;
			END

			IF NOT EXISTS (SELECT 1 FROM #poInfo)
			BEGIN
				SET @ErrMessage = 'No pending PO items found for the selected SO# to export.';
				THROW 60000, @ErrMessage, 1;
			END

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
 
			SELECT poName, reference1 as customerPo, pod, productName, supplierSku, merchantSku, qty, shipDate, '' as containerType, '' as containerSeq, '' as notes, '' as qtyPerCarton, poDetailsId
			FROM #poInfo 
			ORDER BY poName, poDetailsId

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
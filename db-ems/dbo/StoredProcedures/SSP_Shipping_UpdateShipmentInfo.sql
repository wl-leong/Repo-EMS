-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-05-27
-- Used By:	    EMS -> Shipment Module -> Shipment Document -> Update shipment info

-- Description : 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-01-14	2.0			WL Leong	PickUpAddrId cannot change after process
-- 2024-05-27	1.0			ZY Wong 	Initial
-- ==========================================================================================
/*

*/
 
CREATE PROCEDURE [dbo].[SSP_Shipping_UpdateShipmentInfo]
@Json VARCHAR(MAX),
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		--DECLARE @Json VARCHAR(MAX) = 
		--	N'{"shipmentList":[{
		--	       "shipmentId":1,
		--	       "customerInvoiceNo":"",
		--	       "pickUpAddrId":"1027",
		--	       "shipToId":"8",
		--	       "pol":"PORT KLANG",
		--	       "pod":"MOBILE",
		--	       "note":""
		--	}]}'
		--	, @userId INT = 1;

		DECLARE @returnMessage VARCHAR(1000);
 
        DROP TABLE IF EXISTS #shipment;

        SELECT shipmentId, customerInvoiceNo, shipToId, pol, pod, note
        INTO #shipment 
        FROM OPENJSON(@Json, '$.shipmentList') 
   				WITH (
					shipmentId BIGINT				    N'$.shipmentId',
                    customerInvoiceNo VARCHAR(50)       N'$.customerInvoiceNo',
                    pickUpAddrId INT                    N'$.pickUpAddrId',
                    shipToId INT                        N'$.shipToId',
                    pol VARCHAR(100)                    N'$.pol',
                    pod VARCHAR(100)                    N'$.pod',
                    note VARCHAR(30)                    N'$.note'
                )
        
        ALTER TABLE #shipment ADD companyId INT;

        UPDATE #shipment SET
            companyId = shp.companyId
        FROM shipmentHeader shp
        WHERE shp.shipmentId = #shipment.shipmentId

        DROP TABLE IF EXISTS #chkDestination;

        SELECT s.companyId, pck.companyId as pickUpCompanyId, s.pickUpAddrId, st.companyId as shipToCompanyId, s.shipToId
        INTO #chkDestination
        FROM #shipment s
            INNER JOIN md_Warehouse pck
                ON s.pickUpAddrId = pck.warehouseId 
            INNER JOIN md_ShipToDestination st
                ON s.shipToId = st.shipToId

        IF (SELECT COUNT(1) FROM #chkDestination WHERE pickUpCompanyId <> companyId) > 0
        BEGIN
			SET @returnMessage = 'Invalid Ship From.';
			THROW 60000, @returnMessage, 1;
        END

        IF (SELECT COUNT(1) FROM #chkDestination WHERE shipToCompanyId <> companyId) > 0
        BEGIN
			SET @returnMessage = 'Invalid Ship To.';
			THROW 60000, @returnMessage, 1;
        END

		BEGIN TRANSACTION

		    UPDATE shp SET
                customerInvoiceNo = CASE WHEN s.customerInvoiceNo IS NULL THEN shp.customerInvoiceNo ELSE s.customerInvoiceNo END,
                shipToId = CASE WHEN s.shipToId IS NULL THEN shp.shipToId ELSE s.shipToId END,
			    pol = CASE WHEN s.pol IS NULL THEN shp.pol ELSE s.pol END,
			    pod = CASE WHEN s.pod IS NULL THEN shp.pod ELSE s.pod END,
			    note = CASE WHEN s.note IS NULL THEN shp.note ELSE s.note END,	
			    updateBy = @userId,
			    updateDate = getdate()
		    FROM shipmentHeader shp
                INNER JOIN #shipment s
		            ON shp.shipmentId = s.shipmentId
 
		COMMIT TRANSACTION
        
        SELECT '_SUCCESS_' as status, 'Shipment info success update.' as returnMessage

		RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 
 
		IF @returnMessage IS NULL
            SET @returnMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE()
 
		SELECT
			'_FAILURE_' as status, @returnMessage as returnMessage

		RETURN -1
	END CATCH
END

GO


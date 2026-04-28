-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-05-27
-- Used By:	    EMS -> Shipment Module -> Shipment Document -> Update shipment freight

-- Description : 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-06-17   2.0         ZY Wong     Same lr having same haulier & vessel
-- 2024-05-27	1.0			ZY Wong 	Initial
-- ==========================================================================================
/*
EXEC [SSP_Shipping_UpdateShipmentFreight] 
N'{"shipmentFreightList":[{"shipmentId":1,"containerNo":"1","containerSealNo":"1","containerMaxGross":"111.2200","containerTare":"111.2200","containerPullInDate":"2024-06-10",
	"containerPullOutDate":"2024-06-11","haulier":"1","vessel":"3168","ETD":"2024-06-11","ETA":"2024-06-20"}]}', 1
*/
 
CREATE PROCEDURE [dbo].[SSP_Shipping_UpdateShipmentFreight]
@Json VARCHAR(MAX),
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		--DECLARE @Json VARCHAR(MAX) = 
		--	N'{"shipmentFreightList":[{
		--	       "shipmentId":1,
  --                 "containerNo":"1",	   
		--	       "containerSealNo":"1",
		--	       "containerMaxGross":"111.2200",
		--	       "containerTare":"111.2200",
		--	       "containerPullInDate":"2024-06-10",
		--	       "containerPullOutDate":"2024-06-11",
		--	       "haulier":"1",
  --                 "vessel":"3168",
  --                 "ETD":"2024-06-11",
  --                 "ETA":"2024-06-20"
		--	}]}'
		--	, @userId INT = 1;

		DECLARE @returnMessage VARCHAR(1000);
 
        DROP TABLE IF EXISTS #shipmentFreight;

        SELECT shipmentId, containerNo, 
            CASE WHEN ISNULL(containerSealNo,'') = '' THEN '' ELSE containerSealNo END as containerSealNo, 
            CASE WHEN ISNULL(containerMaxGross,'') = '' THEN '0.0000' ELSE CAST(containerMaxGross as DECIMAL(18,4)) END as containerMaxGross, 
            CASE WHEN ISNULL(containerTare,'') = '' THEN '0.0000' ELSE CAST(containerTare as DECIMAL(18,4)) END as containerTare, 
            CASE WHEN ISNULL(containerPullInDate,'') = '' THEN NULL ELSE CONVERT(DATETIME, containerPullInDate) END as containerPullInDate, 
            CASE WHEN ISNULL(containerPullOutDate,'') = '' THEN NULL ELSE CONVERT(DATETIME, containerPullOutDate) END as containerPullOutDate, 
            haulier, vessel, 
            CASE WHEN ISNULL(ETD,'') = '' THEN NULL ELSE CONVERT(DATE, ETD) END as ETD, 
            CASE WHEN ISNULL(ETA,'') = '' THEN NULL ELSE CONVERT(DATE, ETA) END as ETA
        INTO #shipmentFreight 
        FROM OPENJSON(@Json, '$.shipmentFreightList') 
   				WITH (
					shipmentId BIGINT				            N'$.shipmentId',
                    containerNo VARCHAR(100)                    N'$.containerNo',
                    containerSealNo VARCHAR(100)                N'$.containerSealNo',
                    containerMaxGross VARCHAR(10)               N'$.containerMaxGross',
                    containerTare VARCHAR(10)                   N'$.containerTare',
                    containerPullInDate VARCHAR(10)             N'$.containerPullInDate',
                    containerPullOutDate VARCHAR(10)            N'$.containerPullOutDate',
                    haulier INT                                 N'$.haulier',
                    vessel INT                                  N'$.vessel',
                    ETD VARCHAR(10)                             N'$.ETD',
                    ETA VARCHAR(10)                             N'$.ETA'
                )
        
        --ALTER TABLE #shipmentFreight ADD forwarderId INT;
        --ALTER TABLE #shipmentFreight ADD haulierId INT;
        --ALTER TABLE #shipmentFreight ADD vesselId INT;
        
        --UPDATE shp SET
        --    forwarderId = s.forwarderId
        --FROM #shipmentFreight shp
        --    INNER JOIN shipmentHeader s
        --        ON shp.shipmentId = s.shipmentId

        --UPDATE shp SET 
        --    haulierId = h.haulierId
        --FROM #shipmentFreight shp
        --    INNER JOIN md_haulier h
        --        ON shp.haulier = h.haulier
        --        AND shp.forwarderId = h.forwarderId
        --        AND h.statusFlag = 1

        --IF (SELECT COUNT(1) FROM #shipmentFreight WHERE haulierId IS NULL) > 0
        --BEGIN
        --    SET @returnMessage = 'Haulier is not found in system.';
        --    THROW 60000, @returnMessage,1;
        --END

        --UPDATE shp SET 
        --    vesselId = vs.categoryId
        --FROM #shipmentFreight shp
        --    INNER JOIN md_masterCategory vs
        --        ON shp.vessel = vs.categoryName
        --        AND vs.status = 1

        --IF (SELECT COUNT(1) FROM #shipmentFreight WHERE vesselId IS NULL) > 0
        --BEGIN
        --    SET @returnMessage = 'Vessel is not found in system.';
        --    THROW 60000, @returnMessage,1;
        --END

		BEGIN TRANSACTION

            DECLARE @lrHeader TABLE(lrHeaderId BIGINT, haulierId INT, vesselId INT);

		    UPDATE shp SET
                containerNo = CASE WHEN ISNULL(s.containerNo,'') = '' THEN shp.containerNo ELSE s.containerNo END,
                containerSealNo = s.containerSealNo,
            	containerMaxGross = s.containerMaxGross,
                containerTare = s.containerTare,
			    containerPullInDate = s.containerPullInDate,
			    containerPullOutDate = s.containerPullOutDate,
			    haulierId = s.haulier,	
                vesselId = s.vessel,
                ETD = s.ETD,
                ETA = s.ETA,
			    updateBy = @userId,
			    updateDate = getdate()
            OUTPUT INSERTED.lrHeaderId, INSERTED.haulierId, INSERTED.vesselId
            INTO @lrHeader
		    FROM shipmentHeader shp
                INNER JOIN #shipmentFreight s
		            ON shp.shipmentId = s.shipmentId

            -- same lr having same haulier & vessel
            UPDATE shp SET
                haulierId = lr.haulierId,	
                vesselId = lr.vesselId
            FROM shipmentHeader shp
                INNER JOIN @lrHeader lr
                    ON shp.lrHeaderId = lr.lrHeaderId
 
		COMMIT TRANSACTION
        
        SELECT '_SUCCESS_' as status, 'Shipment Freight success update.' as returnMessage

		RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 
 
		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as returnMessage

		RETURN -1
	END CATCH
END

GO


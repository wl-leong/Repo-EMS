-- =============================================
-- Author:		WL Leong
-- Create date: 2023-06-08
-- Used By:	    EMS -> SO Module -> SO Listing -> Create New Order

-- Description : Sales Order for factory, Performa Invoice for Marketing Department

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-04-22   4.0         ZY Wong     Change to get pod using shipToId
-- 2024-01-22	3.0			ZY Wong		Add XACT_ABORT
-- 2023-12-08	2.0			WL Leong	Adjust json string customerPo datatype
-- 2023-06-08	1.0			WL Leong	Initial
-- ==========================================================================================
--EXEC SSP_SalesOrder_InsertNewOrder
--N'{"companyId":4,"customerId":3,"supplierId":6,"customerPO":"MPP120230217","soDate":"2023-03-06T00:00:00","customerPO":"","otherPO":"","shipToId":8,"shipWay":0,"vesselBooking":0,"pol":"PORT KLANG","pod":"","earlyShipDate":"2023-05-29T11:17:41.8886594+08:00","lateShipDate":"2023-05-29T11:17:41.8886594+08:00","soInvAmnt":0.0,"soInvoice":"","reference1":"","reference2":"","soNote":"","soInvoice":""}'
--, 1
--select * from soHeader
 
CREATE PROCEDURE [dbo].[SSP_SalesOrder_InsertNewOrder]
@orderJson VARCHAR(MAX),
@createdBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		BEGIN TRANSACTION
 
		DECLARE @errorMessage As VARCHAR(200)

		-- Read json content
		DROP TABLE IF EXISTS #orderHeader;

		SELECT * 
		INTO #orderHeader
		FROM  OPENJSON(@orderJson) 
  			WITH (
				soName VARCHAR(50)			N'$.soName', 
				companyId INT				N'$.companyId', 
				customerId INT				N'$.customerId',
				supplierId INT				N'$.supplierId',
				customerPO VARCHAR(200)		N'$.customerPO', 
				soDate DATE					N'$.soDate',
				thirdPartyPO VARCHAR(50)	N'$.thirdPartyPO',
				thirdParty VARCHAR(50)		N'$.thirdParty',
				shipToId INT				N'$.shipToId',
				shipWay INT					N'$.shipWay', 
				vesselBooking VARCHAR(50)	N'$.vesselBooking',
				pol VARCHAR(50)				N'$.pol',
				pod VARCHAR(50)				N'$.pod', 
				earlyShipDate DATE			N'$.earlyShipDate',
				lateShipDate DATE			N'$.lateShipDate',
				soInvoice VARCHAR(500)		N'$.soInvoice',
				soInvoiceDate DATE			N'$.soInvoiceDate',
				reference1 VARCHAR(1000)	N'$.reference1',
				reference2 VARCHAR(1000)	N'$.reference2',
				soNote VARCHAR(5000)		N'$.soNote',
				soStatus INT				N'$.soStatus'
			) 
 
			DECLARE @tempSOName VARCHAR(100)


			DECLARE @companyId INT, @soName VARCHAR(50), @soHeaderId BIGINT, @customerId INT
			DECLARE @NewOrder table(soHeaderId BIGINT , customerId INT)

			SET @companyId = (SELECT TOP 1 companyId FROM #orderHeader);

			EXEC [dbo].[SSP_GetRunningNo] 'SO', @companyId, @soName  output

			IF @soName IS NOT NULL
			BEGIN
				SET @tempSOName = 'tempSO_' + @soName

                DECLARE @shipToId INT = (SELECT TOP 1 shipToId FROM #orderHeader);
                DECLARE @pod INT = (SELECT pod FROM md_ShipToDestination WHERE shipToId = @shipToId);

				-- 1105 SO Open Status
				INSERT INTO soHeader(companyId, customerId, supplierId, soName, soDate, customerPO, thirdParty, thirdPartyPO, 
                    shipToId, shipWay, vesselBooking, portOfLanding, portOfDestination, earlyShipDate, lateShipDate, 
                    soInvoice, soInvoiceDate, soNote, soStatus, createBy, createDate)
				OUTPUT INSERTED.soHeaderId, INSERTED.customerId 
				INTO @NewOrder
				SELECT companyId, customerId, supplierId, @tempSOName, getdate() as soDate, ISNULL(customerPO, ''),  ISNULL(thirdParty, ''), ISNULL(thirdPartyPO, ''), 
                    shipToId, shipWay, ISNULL(vesselBooking, ''), pol, @pod, earlyShipDate, ISNULL(lateShipDate, DATEADD(DAY, 7, earlyShipDate)), 
					ISNULL(soInvoice, ''), soInvoiceDate, ISNULL(soNote, ''), 1105 as soStatus, @createdBy, getdate()
				FROM #orderHeader
 

				SELECT @soHeaderId = soHeaderId, @customerId = customerId FROM @NewOrder
			 
				IF @soHeaderId IS NULL
				BEGIN
					SELECT '_FAILURE_' as status, 'SO/PI number encounter creation problem' AS returnMessage 

					RETURN -1
				END
			END
			ELSE
			BEGIN
				SELECT '_FAILURE_' as status, 'SO/PI number encounter creation problem' AS returnMessage 
				
				RETURN -1
			END
		
		SELECT '_SUCCESS_' as status, 'SO# ' + @tempSOName + ' successfully created' AS returnMessage , @soHeaderId as soHeaderId

		COMMIT TRANSACTION

		RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 
 
		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as errorMessage

		RETURN -1
	END CATCH
END

GO


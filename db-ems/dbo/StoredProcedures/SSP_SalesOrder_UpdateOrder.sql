-- =============================================
-- Author:		WL Leong
-- Create date: 2023-06-08
-- Used By:	    EMS -> SO Module -> SO Listing -> Create New Order

-- Description : Sales Order for factory, Performa Invoice for Marketing Department

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-03-17   8.0         ZY Wong     Change to get pod using shipToId
-- 2024-02-28	7.0			WL Leong	Add poNote also got lastUpdatedDate
-- 2024-02-23	6.0			ZY Wong		Add validation for earlyShipDate
-- 2024-01-24	5.0			WL Leong	Allowed Reopen Mode to update also PO
-- 2024-01-22	4.0			ZY Wong		Add XACT_ABORT
-- 2024-01-18	3.1			WL Leong	Allowed Reopen Mode to update 
-- 2024-01-18	3.0			WL Leong	Update LastUpdateDate if earlyshipdate is changed
-- 2023-12-08	2.0			WL Leong	Adjust json string customerPo datatype
-- 2023-06-08	1.0			WL Leong	Initial
---- ==========================================================================================
--EXEC SSP_SalesOrder_UpdateOrder
--N'{"soHeaderId":10013,"soName":"MPP2333","companyId":4,"customerId":3,"supplierId":6,"customerPO":"MPP120230217","soDate":"2023-03-06T00:00:00","customerPO":"","otherPO":"","shipToId":8,"shipWay":0,"vesselBooking":0,"pol":"PORT KLANG","pod":"","earlyShipDate":"2023-05-29T11:17:41.8886594+08:00","lateShipDate":"2023-05-29T11:17:41.8886594+08:00","soInvAmnt":0.0,"soInvoice":"","reference1":"","reference2":"","soNote":"","soInvoice":"", "soStatus":"1105"}'
--, 1

 
CREATE PROCEDURE [dbo].[SSP_SalesOrder_UpdateOrder]
@orderJson VARCHAR(MAX),
@updatedBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		BEGIN TRANSACTION
 
		DECLARE @errorMessage As VARCHAR(200)
		--DECLARE @updatedBy INT = 2
		--DECLARE @orderJson VARCHAR(MAX)
		--SET @orderJson = '{"companyId":"4","soName":"tempSO_FNP23-06046","soHeaderId":"10052","customerId":"19","supplierId":"39","customerPO":"YWT-00010623","soDate":"2023-06-22","customerPO":"xxx123","otherPO":"","shipToId":"293","shipWay":"1125","vesselBooking":"asdf","pol":"xxx12345","pod":"293","earlyShipDate":"2023-06-06","lateShipDate":"2023-06-30","soInvAmnt":"0.0","soInvoice":"\"\"","soInvoiceDate":"2023-06-23","soNote":"","soStatus":1105}'
		-- Read json content
		DROP TABLE IF EXISTS #orderHeader;

		SELECT * 
		INTO #orderHeader
		FROM  OPENJSON(@orderJson) 
  			WITH (
				soHeaderId INT				N'$.soHeaderId', 
				soName VARCHAR(50)			N'$.soName', 
				companyId INT				N'$.companyId', 
				customerId INT				N'$.customerId',
				supplierId INT				N'$.supplierId',
				customerPO VARCHAR(200)		N'$.customerPO', 
				soDate DATE					N'$.soDate',
				thirdPartyPO VARCHAR(50)	N'$.thirdPartyPO',
				thirdParty VARCHAR(50)		N'$.thirdParty',
				shipToId INT				N'$.shipToId',
				shipWay VARCHAR(50)			N'$.shipWay', 
				vesselBooking VARCHAR(50)	N'$.vesselBooking',
				pol VARCHAR(50)				N'$.pol',
				--pod VARCHAR(50)				N'$.pod', 
				earlyShipDate DATE			N'$.earlyShipDate',
				lateShipDate DATE			N'$.lateShipDate',
				soInvoice VARCHAR(500)		N'$.soInvoice',
				soInvoiceDate DATE			N'$.soInvoiceDate',
				reference1 VARCHAR(1000)	N'$.reference1',
				reference2 VARCHAR(1000)	N'$.reference2',
				soNote VARCHAR(5000)		N'$.soNote',
				soStatus INT				N'$.soStatus'
			) 

 		DECLARE @soName varchar(50);
		SET @soName = (SELECT soName FROM #orderHeader);

		IF (SELECT soStatus FROM soHeader WHERE soName = @soName) NOT IN (1105, 1106, 2144)
		BEGIN
			SELECT '_ALERT_' as status, 'SO# ' + @soName + ' is not in OPEN/ CONFIRMED state, no update is allowed' AS returnMessage 

			--RETURN -1
		END

		IF (SELECT earlyShipDate FROM #orderHeader) < CONVERT(DATE, GETDATE())  
			OR (SELECT lateShipDate FROM #orderHeader) < CONVERT(DATE, GETDATE())
		BEGIN
			SELECT '_ALERT_' as status, 'Please choose a valid Early Ship Date' as returnMessage
		END

        DECLARE @shipToId INT = (SELECT TOP 1 shipToId FROM #orderHeader);
        DECLARE @pod INT = (SELECT pod FROM md_ShipToDestination WHERE shipToId = @shipToId);

		DROP TABLE IF EXISTS #reopenEditShipDate; 

		SELECT odr.soName, odr.soHeaderId, odr.earlyShipDate as newShipDate, sod.earlyShipDate, sod.soStatus
		INTO #reopenEditShipDate
		FROM #orderHeader odr 
			INNER JOIN soHeader sod
				ON odr.soHeaderId = sod.soHeaderId
		WHERE odr.earlyShipDate <> sod.earlyShipDate
			AND sod.soStatus = 2144 -- reopenStatus
			AND odr.earlyShipDate >= CONVERT(DATE, GETDATE())


		UPDATE sod SET
			customerId = oh.customerId,
			supplierId = oh.supplierId, 
			customerPO = oh.customerPO, 
			thirdParty  = oh.thirdParty, 
			thirdPartyPO  = oh.thirdPartyPO, 
			shipToId  = oh.shipToId, 
			shipWay  = oh.shipWay, 
			vesselBooking = oh.vesselBooking, 
			portOfLanding = oh.pol, 
			--portOfDestination = oh.pod, 
            portOfDestination = @pod,
			earlyShipDate = oh.earlyShipDate, 
			lateShipDate = oh.lateShipDate, 
			soInvoice = CASE WHEN oh.soInvoice = '' THEN sod.soInvoice ELSE oh.soInvoice END, 
			soInvoiceDate = CASE WHEN oh.soInvoiceDate = '' THEN sod.soInvoiceDate ELSE oh.soInvoiceDate END, 
			soNote = oh.soNote, 
			lastUpdatedDate =  CASE 
									WHEN sod.earlyShipDate <> oh.earlyShipDate AND sod.soStatus = 2144 THEN getdate()
									WHEN sod.soNote <> oh.soNote AND sod.soStatus = 2144 THEN getdate()
									ELSE sod.lastUpdatedDate 
								END,
			soStatus = oh.soStatus, 
			updateBy = @updatedBy, 
			updateDate = getdate()
		FROM soHeader sod
			INNER JOIN #orderHeader oh
				ON sod.soHeaderId = oh.soHeaderId
		WHERE sod.soStatus IN (1105, 1106, 2144)
			AND oh.earlyShipDate >= CONVERT(DATE, GETDATE())

  		UPDATE po SET
			poEarlyShipDate = newShipDate,
			polateShipDate = DATEADD(DAY, 7, newShipDate),
			updateDate = getdate(),
			updateBy = @updatedBy
		FROM  poHeader po
			INNER JOIN #reopenEditShipDate ed
				ON po.poReferenceId = ed.soName

		SELECT '_SUCCESS_' as status, 'SO# ' + @soName + ' successfully updated' AS returnMessage 

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
 
 
 
 --select * from soHeader

GO


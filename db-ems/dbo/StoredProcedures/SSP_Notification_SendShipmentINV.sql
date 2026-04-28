-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-02-29
-- Used By:	    EMS -> Shipping Module -> Shipping Monitoring -> Send RTGR
--
-- Description : 
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-02-29	1.0			ZY Wong		Initial
-- ==========================================================================================
-- EXEC [SSP_Notification_SendShipmentINV] 'MSHP-FNP-2402002',1
CREATE PROCEDURE [dbo].[SSP_Notification_SendShipmentINV]
@BOL VARCHAR(80),
@updateBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY	

		--DECLARE @BOL VARCHAR(80) = 'MSHP-FNP-2402002'
		DECLARE @returnMessage VARCHAR(1000);

		DROP TABLE IF EXISTS #shipment;

		SELECT shp.shipmentId, shp.shipId, shipmentDate, BOL, soName, soReferenceid, reference1, numberOfPallets, bolTotalPallets, shipmentWeight, boltotalshipmentweight, pickupAddrId, containerType, scac, companyId, apiStatus, 0 as statusFlag, CAST('' as VARCHAR(150)) as returnMessage
		INTO #shipment
		FROM shipmentHeader shp
		WHERE BOL = @BOL

		IF ISNULL(@BOL, '') = ''
		BEGIN
			SET @returnMessage = 'BOL # is empty';
			THROW 60000, @returnMessage, 1
		END

		IF (SELECT COUNT(1) FROM #shipment WHERE apiStatus <> '_ASN_') > 0
		BEGIN
			UPDATE #shipment SET
				statusFlag = -2,
				returnMessage = 'BOL ' + @BOL + ' is/are not able to Send INV'
			FROM #shipment 
			WHERE apiStatus <> '_ASN_'
		END

		IF (SELECT COUNT(1) FROM #shipment WHERE statusFlag = 0) > 0
		BEGIN
			
	--		DECLARE @containerType  VARCHAR(2), @bolTotalShipWeight DECIMAL(18,4), @bolTotalPallets INT, @companyId INT, @pickupAddrId INT;
	--		DECLARE @company VARCHAR(50), @email VARCHAR(100), @totalOrders INT, @totalOrdersQty INT;
	--		DECLARE @shipToLocNo VARCHAR(20), @shipToLabel VARCHAR(20),@addressname VARCHAR(100), @address VARCHAR(200), @address2 VARCHAR(200), @address3 VARCHAR(500)
			
	--		SELECT @containerType = containerType, @bolTotalShipWeight = bolTotalShipmentWeight, @bolTotalPallets = bolTotalPallets, @companyId = companyId, @pickupAddrId = pickupAddrId
	--		FROM #shipment



	--		SELECT @company = companyShortCode, @email = emailAddress
	--		FROM md_Company 
	--		WHERE companyId = @companyId

	--		SELECT @shipToLocNo = locNo, @shipToLabel = shipToLabel, @addressName = shipToName , @address = shipToAddressLine1 + ', ',
	--			@address2 = CASE WHEN LEN(shipToAddressLine2) > 0 THEN (shipToAddressLine2 + ', ') ELSE (shipToCity + ', ' + shipToState + ' ' + shipToPostCode + ', ' + categoryName) END,
	--			@address3 = CASE WHEN LEN(shipToAddressLine2) > 0 THEN (shipToCity + ', ' + shipToState + ' ' + shipToPostCode + ', ' + categoryName) ELSE '' END
	--		FROM shipmentAddress  addr
	--			INNER JOIN #shipment shp
	--				ON addr.shipmentId = shp.shipmentId
	--			INNER JOIN md_MasterCategory ctry
	--				ON addr.country = ctry.categoryId
	--				AND ctry.categoryParentID = 1 --country


	--		DROP TABLE IF EXISTS #shipmentList; 

	--		SELECT shp.shipId, SUM(shipQty) as ttlShipQty, shipmentWeight, soName, soReferenceid, reference1
	--		INTO #shipmentList
	--		FROM #shipment shp
	--			INNER JOIN shipmentLineItem sli
	--				ON shp.shipmentId = sli.shipmentId
	--		GROUP BY shp.shipId, shipmentWeight, soName, soReferenceid, reference1

	--		DROP TABLE IF EXISTS #shipmentItem; 

	--		SELECT customerSku, merchantSku, shipQty
	--		INTO #shipmentItem
	--		FROM #shipment shp
	--			INNER JOIN shipmentLineItem sli
	--				ON shp.shipmentId = sli.shipmentId

	--		SELECT @totalOrdersQty = SUM(ttlShipQty), @totalOrders = COUNT(shipId)
	--		FROM #shipmentList


	--/** end: content prepration **/

	--		DECLARE @TableHead VARCHAR(MAX), @Body NVARCHAR(MAX) = '',  		
	--			@TableHead2 VARCHAR(MAX), @Body2 NVARCHAR(MAX) = '', 
	--			@TableHead3 VARCHAR(MAX), @Body3 NVARCHAR(MAX) = '', 
	--			@TableTail VARCHAR(MAX), @Subject VARCHAR(200)
			
	--		SET @Subject = 'EMS BOL ' + @BOL + ' Routing Instructions  ' + convert(VARCHAR, getdate(), 106)

	--		SET @TableTail = '<tr></table></body></html>' ;
	
	--		SET @TableHead = '<html><head>' + '<style>'
	--			+ 'table, tr {border:hidden;} '
	--			+ 'td {border: none;border-width: 0px;padding-left:5px;padding-right:5px;padding-top:1px;padding-bottom:1px;font: 11px arial} '
	--			+ 'tr {border: none;border-width: 0px} '
	--			+ '</style>' + '</head>' + '<body>' 
	--			+ '<table cellpadding=0 cellspacing=0 border=0>' 
	--			+ '<td><b>BOL</b></td><td>' + CAST(@BOL as VARCHAR) +'</td><tr>'
	--			+ '<td><b>Total Orders per BOL</b></td><td>' + CAST(@totalOrders as VARCHAR) +'</td><tr>'
	--			+ '<td><b>Total Pallets per BOL</b></td><td>' + CAST(@bolTotalPallets as VARCHAR) +'</td><tr><br>'
	--			+ '<td><b>Total Quantity per BOL</b></td><td>' + CAST(@totalOrdersQty as VARCHAR) +'</td><tr>'
	--			+ '<td><b>Total Weight per BOL (kg)</b></td><td>' + CAST(@bolTotalShipWeight as VARCHAR) +'</td><tr><br>'
 --				+ '<td colspan=2><b>Ship To</b></td><tr>'
	--			+ '<td><b>Ship To Destination</b></td><td>' + CAST(@shipToLabel as VARCHAR) +'</td><tr>'
	--			+ '<td><b>Address Name</b></td><td>' + CAST(@addressName as VARCHAR) +'</td><tr>'
	--			+ '<td><b>Address</b></td><td>' + CAST(@address as VARCHAR) +'</td><tr>'
	--			+ '<td></td><td>' + CAST(@address2 as VARCHAR) +'</td><tr>'
	--			+ '<td></td><td>' + CAST(@address3 as VARCHAR) +'</td><tr>'
	--			+ '</table>'

	--		SET @TableHead2 = '</table><br><br><table cellpadding=0 cellspacing=0 border=0>' 
	--				+ '<td bgcolor=#E6E6FA><b>Ship #</b></td>'
	--				+ '<td bgcolor=#E6E6FA><b>Total Quantity</b></td>'
	--				+ '<td bgcolor=#E6E6FA><b>Total Weight (kg)</b></td>'
	--				+ '<td bgcolor=#E6E6FA><b>SO #</b></td>'
	--				+ '<td bgcolor=#E6E6FA><b>SO Reference Id</b></td>'
	--				+ '<td bgcolor=#E6E6FA><b>Reference 1</b></td>'

	--		SET @Body2 = ( SELECT    
	--								td = shipId, '',
	--								td = ttlShipQty, '',
	--								td = shipmentWeight, '',
	--								td = soName, '',
	--								td = soReferenceId, '',
	--								td = reference1, ''
	--						FROM    #shipmentList
	--						ORDER BY ttlShipQty DESC
	--					FOR   XML RAW('tr'),
	--							ELEMENTS
	--					)
 --			-- 20230308
	--		SET @TableHead3 = '</table><br><br><table cellpadding=0 cellspacing=0 border=0>' 
	--				+ '<td bgcolor=#E6E6FA><b>Customer SKU</b></td>'
	--				+ '<td bgcolor=#E6E6FA><b>Merchant SKU</b></td>'
	--				+ '<td bgcolor=#E6E6FA><b>Ship Quantity</b></td>'

	--		-- 20230308
	--		SET @Body3 = ( SELECT    
	--								td = customerSku, '',
	--								td = merchantSku, '',
	--								td = shipQty, ''
	--						FROM    #shipmentItem
	--						ORDER BY shipQty DESC
	--					FOR   XML RAW('tr'),
	--							ELEMENTS
	--					)
 
	--		SELECT  @Body = @TableHead + ISNULL(@Body, '') + @TableHead2 + ISNULL(@Body2, '') + @TableHead3 + ISNULL(@Body3, '') + @TableTail 
		
	--		DECLARE @mailId BIGINT, @emailList VARCHAR(MAX) = ''

	--		DECLARE @emailCategoryId INT = (SELECT emailCategoryId FROM md_EmailCategory WHERE companyId = @companyId AND menuLevel0Id = 9 AND actionName IN ('New PI', 'New SO'))

			--SELECT @emailList = STUFF((SELECT ';' + emailAddress
			--							FROM md_EmailList
			--							WHERE emailCategoryId = @emailCategoryId
			--								AND companyId = @companyId
			--							FOR XML PATH('')) ,1,1,'')

			--EXEC @mailId = msdb.dbo.sp_send_dbmail 
			--	@profile_name = 'Notification',
			--	@recipients = @email,
			--	@copy_recipients = @emailList,
			--	@subject = @Subject,
			--	@body = @Body ,
			--	@body_format = 'HTML' ;

			--UPDATE shp SET
			--	apiStatus = '_RTGR_',
			--	carrierPickupDate = getdate()
			--FROM shipmentHeader shp
			--WHERE BOL = @BOL

			-- html for testing purpose only
			--select @subject + '<br><br>' + @body

			SELECT '_SUCCESS_' as status, 'BOL '+ @BOL + ' has/have send shipment INV email' AS returnMessage 
		END
		ELSE
		BEGIN
			SELECT '_FAILURE_' as status, returnMessage FROM #shipment
		END

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


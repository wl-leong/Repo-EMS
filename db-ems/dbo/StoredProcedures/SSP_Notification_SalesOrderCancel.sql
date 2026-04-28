-- =============================================
-- Author:		ZY Wong
-- Create date: 2023-11-06
-- Description:	Send email notification if sales order is cancel
-- Used By:		Email Notification -> Cancell SO/PI

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-10-28   1.2         ZY Wong     Remove @isMarketing variable, subject standardize to 'Sales Order'
-- 2024-04-08   1.1         ZY Wong     Change column to itemCode
-- 2023-11-06	1.0			ZY Wong		Initial version
-- =============================================
-- EXEC [dbo].[SSP_Notification_SalesOrderCancel]
CREATE PROCEDURE [dbo].[SSP_Notification_SalesOrderCancel]
AS
BEGIN
SET NOCOUNT ON
	BEGIN TRY

--1105	Draft
--1106	Confirmed
--1107	Cancel
--1108	Close
--2125	In Production

		DROP TABLE IF EXISTS #orderList;

		SELECT DISTINCT companyId, soHeaderId
		INTO #orderList
		FROM soHeader so
		WHERE apiStatus = '_CXL_'
			AND soName NOT LIKE 'tempSO%'  -- exclude temp SO

		DECLARE @companyId INT, @soHeaderId BIGINT

		DECLARE CUR_so CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
		SELECT DISTINCT companyId, soHeaderId
		FROM #orderList

		OPEN CUR_so
		FETCH NEXT FROM CUR_so INTO @companyId, @soHeaderId

		WHILE @@FETCH_STATUS = 0
		BEGIN

			DECLARE @company VARCHAR(50), @email VARCHAR(100), @isMarketing BIT;
			
			SELECT @company = companyShortCode, @email = emailAddress, @isMarketing = isMarketing
			FROM md_Company 
			WHERE companyId = @companyId

			DECLARE @soName VARCHAR(50), @customerPO VARCHAR(200), @shipDate VARCHAR(10), @shipTo VARCHAR(50), @ttlQty INT, @poName VARCHAR(50), @cancelDate VARCHAR(10);

			SELECT @soName = soName, @customerPO = customerPO, @shipDate = earlyShipDate, @shipTo = ISNULL(st.shipToLabel,''), @poName = poName, @cancelDate = CONVERT(DATE, so.updateDate)
			FROM soHeader so
				LEFT JOIN md_shipToDestination st
					ON so.shipToId = st.shipToId
				LEFT JOIN md_shipToDestination pod
					ON so.portOfDestination = st.shipToId
				LEFT JOIN poHeader po
					ON so.soName = po.poReferenceId
			WHERE so.companyId = @companyId
				AND soHeaderId = @soHeaderId

			DROP TABLE IF EXISTS #itemList; 

			SELECT itemCode, modelNo, customerSku, ISNULL(merchantSku,'') as merchantSku, odrQty, inventorySKU, itemDesc
			INTO #itemList
			FROM  soLineItem li
				INNER JOIN md_Inventory inv
					ON li.invId = inv.invId
			WHERE soHeaderId = @soHeaderId

			SET @ttlQty = (SELECT SUM(odrQty) FROM #itemList)

	/** end: content prepration **/

			DECLARE @TableHead VARCHAR(MAX), @Body NVARCHAR(MAX) = '',  		
				@TableHead2 VARCHAR(MAX), @Body2 NVARCHAR(MAX) = '', 
				@TableTail VARCHAR(MAX), @Subject VARCHAR(200)
			
			SET @Subject = '[REVISED CANCEL] - Sales Order # ' + @soName + ' Cancel at ' + CONVERT(VARCHAR, @cancelDate, 106)

			SET @TableTail = '<tr></table></body></html>' ;
	
			IF @poName IS NOT NULL
			BEGIN
				SET @TableHead = '<html><head>' + '<style>'
					+ 'table, tr {border:hidden;} '
					+ 'td {border: none;border-width: 0px;padding-left:5px;padding-right:5px;padding-top:1px;padding-bottom:1px;font: 11px arial} '
					+ 'tr {border: none;border-width: 0px} '
					+ '</style>' + '</head>' + '<body>' 
					+ '<table cellpadding=0 cellspacing=0 border=0>' 
					+ '<td><b>Cancel Date</b></td><td>' + CAST(@cancelDate as VARCHAR) +'</td><tr>' 
					+ '<td><b>PO #</b></td><td>' + CAST(@poName as VARCHAR) +'</td><tr>' 
					+ '<td><b>SO #</b></td><td>' + CAST(@soName as VARCHAR) +'</td><tr>'
					+ '<td><b>Customer PO #</b></td><td>' + CAST(@customerPO as VARCHAR(MAX)) +'</td><tr>'						
					+ '<td><b>Ship Date</b></td><td>' + CAST(@shipDate as VARCHAR) +'</td><tr>'
					+ '<td><b>Total Order Quantity</b></td><td>' + CAST(@ttlQty as VARCHAR) +'</td><tr>'
 					+ '<td><b>Ship To Destination</b></td><td>' + CAST(@shipTo as VARCHAR) +'</td><tr>'
					+ '</table>'
			END
			ELSE
			BEGIN
				SET @TableHead = '<html><head>' + '<style>'
					+ 'table, tr {border:hidden;} '
					+ 'td {border: none;border-width: 0px;padding-left:5px;padding-right:5px;padding-top:1px;padding-bottom:1px;font: 11px arial} '
					+ 'tr {border: none;border-width: 0px} '
					+ '</style>' + '</head>' + '<body>' 
					+ '<table cellpadding=0 cellspacing=0 border=0>' 
					+ '<td><b>Cancel Date</b></td><td>' + CAST(@cancelDate as VARCHAR) +'</td><tr>' 
					+ '<td><b>SO #</b></td><td>' + CAST(@soName as VARCHAR) +'</td><tr>'
					+ '<td><b>Customer PO #</b></td><td>' + CAST(@customerPO as VARCHAR(MAX)) +'</td><tr>'						
					+ '<td><b>Ship Date</b></td><td>' + CAST(@shipDate as VARCHAR) +'</td><tr>'
					+ '<td><b>Total Order Quantity</b></td><td>' + CAST(@ttlQty as VARCHAR) +'</td><tr>'
 					+ '<td><b>Ship To Destination</b></td><td>' + CAST(@shipTo as VARCHAR) +'</td><tr>'
					+ '</table>'

			END

			IF @isMarketing = 0
            BEGIN
		        SET @TableHead2 = '</table><br><br><table cellpadding=0 cellspacing=0 border=0>' 
				        + '<td bgcolor=#E6E6FA><b>Item Code</b></td>'
				        + '<td bgcolor=#E6E6FA><b>Inventory Sku</b></td>'
				        + '<td bgcolor=#E6E6FA><b>Description</b></td>'
				        + '<td bgcolor=#E6E6FA><b>Order Quantity</b></td>'

		        SET @Body2 = ( SELECT    
								        td = itemCode, '',
								        td = inventorySku, '',
								        td = itemDesc, '',
								        td = odrQty, ''
						        FROM    #itemList
						        ORDER BY odrQty DESC
					        FOR   XML RAW('tr'),
							        ELEMENTS
					        )
                
            END
            ELSE
            BEGIN

		        SET @TableHead2 = '</table><br><br><table cellpadding=0 cellspacing=0 border=0>' 
				        + '<td bgcolor=#E6E6FA><b>Item Code</b></td>'
				        + '<td bgcolor=#E6E6FA><b>Model No</b></td>'
				        + '<td bgcolor=#E6E6FA><b>Customer SKU</b></td>'
				        + '<td bgcolor=#E6E6FA><b>Merchant SKU</b></td>'
				        + '<td bgcolor=#E6E6FA><b>Order Quantity</b></td>'

		        SET @Body2 = ( SELECT    
								        td = itemCode, '',
								        td = modelNo, '',
								        td = customerSku, '',
								        td = merchantSku, '',
								        td = odrQty, ''
						        FROM    #itemList
						        ORDER BY odrQty DESC
					        FOR   XML RAW('tr'),
							        ELEMENTS
					        )

            END
 
			SELECT  @Body = @TableHead + ISNULL(@Body, '') + @TableHead2 + ISNULL(@Body2, '') + @TableTail
		
			DECLARE @mailId BIGINT, @emailList VARCHAR(MAX);

			DECLARE @emailCategoryId INT = (SELECT emailCategoryId FROM md_EmailCategory WHERE menuLevel0Id = 9 AND actionName IN ('Cancel SO'))

			SELECT @emailList = STUFF((SELECT ';' + emailAddress
										FROM md_EmailList
										WHERE emailCategoryId = @emailCategoryId
											AND companyId = @companyId
											AND status = 1
										FOR XML PATH('')) ,1,1,'')

			EXEC @mailId = msdb.dbo.sp_send_dbmail 
				@profile_name = 'Notifications',
				@recipients = @emailList,
				@subject = @Subject,
				@body = @Body ,
				@body_format = 'HTML' ;

			UPDATE so SET
				apiStatus = '_ACK_',
				poaDate = getdate()
			FROM soHeader so
			WHERE companyId = @companyId
				AND soHeaderId = @soHeaderId

            -- html for testing purpose only
			--select @subject + '<br><br>' + @body

			FETCH NEXT FROM CUR_so INTO @companyId, @soHeaderId

		END
		CLOSE CUR_so
		DEALLOCATE CUR_so

	END TRY

	BEGIN CATCH

		SELECT '_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as errorMessage

	END CATCH
END

GO


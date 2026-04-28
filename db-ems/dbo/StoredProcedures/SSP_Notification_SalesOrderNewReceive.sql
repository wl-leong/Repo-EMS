-- =============================================
-- Author:		ZY Wong
-- Create date: 2023-09-22
-- Description:	Send email notification if sales order is new
-- Used By:		Email Notification -> New SO/PI

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-06-24   4.0         WL Leong	Fix ambigious companyId
-- 2025-05-07   3.0         WL Leong	Combine all SO# into 1 email
-- 2025-03-25   2.0         ZY Wong     Change shipToDestination to POD
-- 2024-04-08   1.2         ZY Wong     Change column to itemCode
-- 2024-02-05	1.1			ZY Wong		Add @emailCategoryId, change to get order from apiStatus = '_NEW_'
-- 2023-09-22	1.0			ZY Wong		Initial version
-- =============================================
-- EXEC [dbo].[SSP_Notification_SalesOrderNewReceive] 
CREATE PROCEDURE [dbo].[SSP_Notification_SalesOrderNewReceive]
AS
BEGIN
SET NOCOUNT ON
	BEGIN TRY

--1105	Draft
--1106	Confirmed
--1107	Cancel
--1108	Close
--2125	In Production
--2144	ReOpen

		DROP TABLE IF EXISTS #orderList;

		SELECT DISTINCT companyId, soHeaderId, soName, customerPO, earlyShipDate, soDate, CASE WHEN ISNULL(lastUpdatedDate,'') <> '' THEN 1 ELSE 0 END as isRevised, lastUpdatedDate, thirdParty
		INTO #orderList
		FROM soHeader so
		WHERE apiStatus = '_NEW_'

		DECLARE @companyId INT 
        DECLARE @body NVARCHAR(MAX) = '', @tableHTML NVARCHAR(MAX)  = '';

		DECLARE CUR_so CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
		SELECT DISTINCT companyId 
		FROM #orderList

		OPEN CUR_so
		FETCH NEXT FROM CUR_so INTO @companyId 

		WHILE @@FETCH_STATUS = 0
		BEGIN	
			DROP TABLE IF EXISTS #companySoList;

			SELECT companyId, soHeaderId, soName, customerPO, thirdParty, earlyShipDate, soDate, 
					isRevised, lastUpdatedDate 
			INTO #companySoList
			FROM #orderList
			WHERE companyId = @companyId 

  
			DECLARE @soHeaderId BIGINT, @soName VARCHAR(50), @isRevised BIT, @earlyShipDate DATE;
			SET @body += '<!DOCTYPE html><html><head><meta charset="UTF-8"></head><body>'
 

		    DECLARE CUR_singleOrder CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
		    SELECT DISTINCT soHeaderId , soName, isRevised, earlyShipDate
		    FROM #companySoList

		    OPEN CUR_singleOrder
		    FETCH NEXT FROM CUR_singleOrder INTO @soHeaderId, @soName, @isRevised, @earlyShipDate

		    WHILE @@FETCH_STATUS = 0
		    BEGIN
				DECLARE @soDate DATE, @revisedDate DATE;

                DROP TABLE IF EXISTS #list;

                SELECT h.soName, h.soDate, h.customerPO, h.earlyShipDate, h.thirdParty, li.invId, li.customerSku, merchantSku, CAST('' as VARCHAR(50)) as inventorySku, soItemDesc, li.odrQty
                INTO #list
                FROM soLineItem li
					INNER JOIN #companySolist h
						ON li.soHeaderId = h.soHeaderId
                WHERE li.soHeaderId = @soHeaderId
					AND soLineItemStatus <> 1107


                UPDATE #list SET
					inventorySku = inv.inventorySku
                FROM md_inventory inv
                WHERE #list.invId = inv.invID

				DECLARE @status VARCHAR(20)

				IF @isRevised = 1
					SET @status = 'REVISED'
				ELSE
					SET @status = 'NEW'

				SET @tableHTML = 
						  '<H1>' + @status + ' SO# : ' + @soName + ' @ Ship Date (' + ISNULL(CONVERT(VARCHAR, @earlyShipDate, 106), '') + ')</H1>' +
						  '<table style="border-collapse:collapse; width:80%;">' +
						  '<tr>' +
							'<th style="border:1px solid #000; padding:8px;">SO#</th>' +
							'<th style="border:1px solid #000; padding:8px;">Customer PO</th>' +
							'<th style="border:1px solid #000; padding:8px;">third Party</th>' +
							'<th style="border:1px solid #000; padding:8px;">customer Sku</th>' +
							'<th style="border:1px solid #000; padding:8px;">merchant Sku</th>' +
							'<th style="border:1px solid #000; padding:8px;">SKU</th>' +
							'<th style="border:1px solid #000; padding:8px;">Item Desc</th>' +
							'<th style="border:1px solid #000; padding:8px;">Order Qty</th>' +
						  '</tr>'

				SET @tableHTML =  @tableHTML +  (
						SELECT 
						  '<tr>' +
						  '<td style="border:1px solid #000; padding:8px;">' + ISNULL(soName, '') + '</td>' +
						  '<td style="border:1px solid #000; padding:8px;">' + ISNULL(customerPO, '') + '</td>' +
						  '<td style="border:1px solid #000; padding:8px;">' + ISNULL(thirdParty, '') + '</td>' +
						  '<td style="border:1px solid #000; padding:8px;">' + ISNULL(customerSku, 'UNKNOWN') + '</td>' +
						  '<td style="border:1px solid #000; padding:8px;">' + ISNULL(merchantSku, 'UNKNOWN') + '</td>' +
						  '<td style="border:1px solid #000; padding:8px;">' + ISNULL(inventorySku, 'UNKNOWN') + '</td>' +
						  '<td style="border:1px solid #000; padding:8px;">' + ISNULL(soItemDesc, 'UNKNOWN') + '</td>' +
						  '<td style="border:1px solid #000; padding:8px;">' + CAST(ISNULL(odrQty, 0) AS VARCHAR) + '</td>' +
						  '</tr>'
						FROM #list
						FOR XML PATH(''), TYPE
					  ).value('.', 'NVARCHAR(MAX)')

				SET @tableHTML = @tableHTML + N'</table><br><br>';
                SET @body = @body + @tableHTML;

                SET @tableHTML= '';

	            FETCH NEXT FROM CUR_singleOrder INTO @soHeaderId, @soName, @isRevised, @earlyShipDate
		    END
		
            CLOSE CUR_singleOrder
		    DEALLOCATE CUR_singleOrder


            DECLARE @Subject VARCHAR(500) = '[New/Revised] Sales Order # for ' + CONVERT(VARCHAR, getdate(), 106)

			SET @body = @body + '</HTML>'

			DECLARE @mailId BIGINT, @emailList VARCHAR(MAX);

			DECLARE @emailCategoryId INT = (SELECT emailCategoryId FROM md_EmailCategory WHERE actionName IN ('New SO'))

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
				@body = @body ,
				@body_format = 'HTML' ;

            SET @tableHTML = '';
            SET @body = ''

			UPDATE so SET
				apiStatus = '_ACK_',
				poaDate = getdate()
			FROM soHeader so
				INNER JOIN #companySolist s
					ON so.soHeaderId = s.soHeaderId
			WHERE so.companyId = @companyId
 
			FETCH NEXT FROM CUR_so INTO @companyId 
		END
		CLOSE CUR_so
		DEALLOCATE CUR_so


	END TRY

	BEGIN CATCH

		SELECT '_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as returnMessage

	END CATCH
END

GO


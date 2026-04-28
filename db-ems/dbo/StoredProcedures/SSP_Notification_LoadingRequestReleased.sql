-- =============================================
-- Author:		WL Leong
-- Create date: 2025-05-07
-- Description:	Send email notification if LR is released
-- Used By:		Email Notification -> Release LR

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-05-07	1.0			WL Leong		Initial version
-- =============================================
--select * from lrHeader update lrHeader set apiStatus = '_REL_'  where lrHeaderId >= 216
-- EXEC [dbo].[SSP_Notification_LoadingRequestReleased] 
CREATE PROCEDURE [dbo].[SSP_Notification_LoadingRequestReleased]
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

		DROP TABLE IF EXISTS #lrList;

		SELECT DISTINCT companyId, customerId, lrHeaderId, lrName, lrShipDate
		INTO #lrList
		FROM lrHeader  
		WHERE apiStatus = '_REL_'

 
		DECLARE @companyId INT 
        DECLARE @body NVARCHAR(MAX) = '', @tableHTML NVARCHAR(MAX)  = '';

		DECLARE CUR_lr CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
		SELECT DISTINCT companyId 
		FROM #lrList

		OPEN CUR_lr
		FETCH NEXT FROM CUR_lr INTO @companyId 

		WHILE @@FETCH_STATUS = 0
		BEGIN	
			DROP TABLE IF EXISTS #companyLrList;

			SELECT customerId, lrHeaderId, lrName, lrShipDate
			INTO #companyLrList
			FROM #lrList
			WHERE companyId = @companyId 

  
			DECLARE @lrHeaderId BIGINT, @lrName VARCHAR(50), @lrShipDate DATE;
			SET @body += '<!DOCTYPE html><html><head><meta charset="UTF-8"></head><body>'
 

		    DECLARE CUR_single  CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
		    SELECT DISTINCT lrHeaderId , lrName, lrShipDate
		    FROM #companyLrList

		    OPEN CUR_single
		    FETCH NEXT FROM CUR_single INTO @lrHeaderId, @lrName, @lrShipDate

		    WHILE @@FETCH_STATUS = 0
		    BEGIN

                DROP TABLE IF EXISTS #container;

                SELECT h.lrHeaderId, h.lrName, li.earlyShipDate, containerSeq, lrContainerId
                INTO #container
                FROM lrContainer li
					INNER JOIN #companyLrList h
						ON li.lrHeaderId = h.lrHeaderId
                WHERE li.lrHeaderId = @lrHeaderId
					AND li.containerStatus = 2135

				DROP TABLE IF EXISTS #list;

				SELECT h.lrHeaderId, h.lrName, h.containerSeq, h.earlyShipDate, li.soHeaderId, li.invId, li.qty as lrQty, 
					CAST('' as VARCHAR(50)) as soName, CAST('' as VARCHAR(50)) as customerPO, CAST('' as VARCHAR(20)) as thirdParty,
					CAST('' as VARCHAR(50)) as inventorySku, CAST('' as VARCHAR(200)) as itemDesc
                INTO #list
                FROM lrLineItem li
					INNER JOIN #container h
						ON li.lrContainerId = h.lrContainerId
                WHERE  itemStatus = 2135

                UPDATE #list SET
					inventorySku = inv.inventorySku,
					itemDesc = inv.productName
                FROM md_inventory inv
                WHERE #list.invId = inv.invID

				UPDATE #list SET
					soName = s.soName,
					customerPO = s.customerPO,
					thirdParty = s.thirdParty
				FROM soHeader s
				WHERE #list.soHeaderId = s.soHeaderId


				SET @tableHTML = 
						  '<H1>NEW LR# : ' + @lrName + ' @ early Ship Date (' + ISNULL(CONVERT(VARCHAR, @lrShipDate, 106), '') + ')</H1>' +
						  '<table style="border-collapse:collapse; width:80%;">' +
						  '<tr>' +
							'<th style="border:1px solid #000; padding:8px;">LR#</th>' +
							'<th style="border:1px solid #000; padding:8px;">Container #</th>' +
							'<th style="border:1px solid #000; padding:8px;">SO #</th>' +
							'<th style="border:1px solid #000; padding:8px;">Customer PO</th>' +
							'<th style="border:1px solid #000; padding:8px;">third Party</th>' +
							'<th style="border:1px solid #000; padding:8px;">SKU</th>' +
							'<th style="border:1px solid #000; padding:8px;">Item Desc</th>' +
							'<th style="border:1px solid #000; padding:8px;">LR Qty</th>' +
						  '</tr>'

				SET @tableHTML =  @tableHTML +  (
						SELECT 
						  '<tr>' +
						  '<td style="border:1px solid #000; padding:8px;">' + ISNULL(lrName, '') + '</td>' +
						  '<td style="border:1px solid #000; padding:8px;">' + CAST(ISNULL(containerSeq, 0) as VARCHAR) + '</td>' +
						  '<td style="border:1px solid #000; padding:8px;">' + ISNULL(soName, '') + '</td>' +
						  '<td style="border:1px solid #000; padding:8px;">' + ISNULL(customerPO, '') + '</td>' +
						  '<td style="border:1px solid #000; padding:8px;">' + ISNULL(thirdParty, '') + '</td>' +
						  '<td style="border:1px solid #000; padding:8px;">' + ISNULL(inventorySku, 'UNKNOWN') + '</td>' +
						  '<td style="border:1px solid #000; padding:8px;">' + ISNULL(itemDesc, 'UNKNOWN') + '</td>' +
						  '<td style="border:1px solid #000; padding:8px;">' + CAST(ISNULL(lrQty, 0) AS VARCHAR) + '</td>' +
						  '</tr>'
						FROM #list
						FOR XML PATH(''), TYPE
					  ).value('.', 'NVARCHAR(MAX)')

				SET @tableHTML = @tableHTML + N'</table><br><br>';
                SET @body = @body + @tableHTML;

                SET @tableHTML= '';

	            FETCH NEXT FROM CUR_single INTO @lrHeaderId, @lrName, @lrShipDate
		    END
		
            CLOSE CUR_single
		    DEALLOCATE CUR_single

			DECLARE @company VARCHAR(100) = (SELECT companyShortCode FROM md_company WHERE companyId = @companyId);
            DECLARE @Subject VARCHAR(500) = '[New Released] Loading Request # for ' + CONVERT(VARCHAR, getdate(), 106)

			SET @body = @body + '</HTML>'

			DECLARE @mailId BIGINT, @emailList VARCHAR(MAX);

			DECLARE @emailCategoryId INT = (SELECT emailCategoryId FROM md_EmailCategory WHERE actionName IN ('Released LR'))

			SELECT @emailList = STUFF((SELECT ';' + emailAddress
										FROM (
										SELECT DISTINCT emailAddress
										FROM md_EmailList
										WHERE emailCategoryId = @emailCategoryId
											AND companyId = @companyId
											AND status = 1) g
										FOR XML PATH('')) ,1,1,'')

 
			EXEC @mailId = msdb.dbo.sp_send_dbmail 
				@profile_name = 'Notifications',
				@recipients = @emailList,
				@subject = @Subject,
				@body = @body ,
				@body_format = 'HTML' ;

            SET @tableHTML = '';
            SET @body = ''

			UPDATE lr SET
				apiStatus = '_ACK_',
				lraDate = getdate()
			FROM lrHeader lr
				INNER JOIN #companylrlist s
					ON lr.lrHeaderId = s.lrHeaderId
			WHERE lr.companyId = @companyId
 
			FETCH NEXT FROM CUR_lr INTO @companyId 
		END
		CLOSE CUR_lr
		DEALLOCATE CUR_lr


	END TRY

	BEGIN CATCH

		SELECT '_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as returnMessage

	END CATCH
END

GO


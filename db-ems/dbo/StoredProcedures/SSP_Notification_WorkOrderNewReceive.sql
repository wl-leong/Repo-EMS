-- =============================================
-- Author:		ZY Wong
-- Create date: 2023-09-22
-- Description:	Send email notification when work order is created
-- Used By:		Email Notification -> New WO

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-03-25	1.0			WL Leong		Initial version
-- =============================================
/**
EXEC [dbo].[SSP_Notification_WorkOrderNewReceive]
select * from workOrderHeader
update workOrderHeader set apiStatus = '_NEW_' where workOrderDate >= '2025-06-16' 
**/
CREATE PROCEDURE [dbo].[SSP_Notification_WorkOrderNewReceive]
AS
BEGIN
SET NOCOUNT ON
	BEGIN TRY

  
		DROP TABLE IF EXISTS #woList;

		SELECT DISTINCT companyId, workOrderheaderId, workOrderName, warehouseId, shipDate
		INTO #woList
		FROM workOrderheader h
		WHERE apiStatus = '_NEW_'

		DECLARE @companyId INT 
		DECLARE @body NVARCHAR(MAX) = '', @tableHTML NVARCHAR(MAX)  = '';

		DECLARE CUR_wo CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
		SELECT DISTINCT companyId 
		FROM #woList

		OPEN CUR_wo
		FETCH NEXT FROM CUR_wo INTO @companyId 

		WHILE @@FETCH_STATUS = 0
		BEGIN
            DROP TABLE IF EXISTS #companyWOList;

            SELECT companyId, workOrderheaderId, workOrderName, warehouseId, shipDate
            INTO #companyWOList
            FROM #woList
            WHERE companyId = @companyId

            ALTER TABLE #woList ADD warehouseName VARCHAR(50)

            UPDATE #woList SET
                warehouseName = wh.label
            FROM md_warehouse wh
            WHERE #woList.warehouseId = wh.warehouseId
 
            DECLARE @workOrderHeaderId BIGINT, @workOrderName VARCHAR(50)
			SET @body += '<!DOCTYPE html><html><head><meta charset="UTF-8"></head><body>'

 		    DECLARE CUR_singlewo CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
		    SELECT DISTINCT workOrderHeaderId , workOrderName
		    FROM #companyWOList

		    OPEN CUR_singlewo
		    FETCH NEXT FROM CUR_singlewo INTO @workOrderHeaderId, @workOrderName

		    WHILE @@FETCH_STATUS = 0
		    BEGIN
                DECLARE @warehouse VARCHAR(20), @shipDate DATE ;

                DROP TABLE IF EXISTS #wo;

                SELECT li.workOrderName, warehouseName, shipDate, soName, soLineItemId, invId, qty, CAST('' as VARCHAR(20)) as itemCode, CAST('' as VARCHAR(50)) as SKU,
					CAST('' as VARCHAR(100)) as customerPO, CAST('' as VARCHAR(10)) as thirdParty, CAST('' as VARCHAR(200)) as itemDesc
                INTO #wo
                FROM workOrderLineItem li
                    INNER JOIN #woList h
                        ON li.workOrderHeaderId = h.workOrderheaderId
                WHERE li.workOrderHeaderId = @workOrderheaderId

				UPDATE #wo SET
					customerPO = s.customerPO,
					thirdParty = s.thirdParty
				FROM soHeader s
				WHERE #wo.soName = s.soName

                UPDATE #wo SET
                    itemCode = inv.itemCode,
                    SKU = inv.inventorySku,
					itemDesc = inv.productName
                FROM md_inventory inv
                WHERE #wo.invId = inv.invID

                SET @warehouse = (SELECT TOP 1 warehouseName FROM #wo);
                SET @shipDate  = (SELECT TOP 1 shipDate FROM #wo);

				SET @tableHTML = 
							'<H1>WO# : ' + @workOrderName + ' (' + @warehouse + ') @ Ship Date (' + ISNULL(CONVERT(VARCHAR, @shipDate, 106), '') + ')</H1>' +
							'<table style="border-collapse:collapse; width:80%;">' +
							'<tr>' +
							'<th style="border:1px solid #000; padding:8px;">SO#</th>' +
							'<th style="border:1px solid #000; padding:8px;">Customer PO</th>' +
							'<th style="border:1px solid #000; padding:8px;">third Party</th>' +
							'<th style="border:1px solid #000; padding:8px;">Item Code</th>' +
							'<th style="border:1px solid #000; padding:8px;">Item Desc</th>' +
							'<th style="border:1px solid #000; padding:8px;">SKU</th>' +
							'<th style="border:1px solid #000; padding:8px;">Qty</th>' +
						  '</tr>'

				SET @tableHTML =  @tableHTML +  (
						SELECT 
						  '<tr>' +
						  '<td style="border:1px solid #000; padding:8px;">' + ISNULL(soName, '') + '</td>' +
						  '<td style="border:1px solid #000; padding:8px;">' + ISNULL(customerPO, '') + '</td>' +
						  '<td style="border:1px solid #000; padding:8px;">' + ISNULL(thirdParty, '') + '</td>' +
						  '<td style="border:1px solid #000; padding:8px;">' + ISNULL(itemCode, 'UNKNOWN') + '</td>' +
						  '<td style="border:1px solid #000; padding:8px;">' + ISNULL(itemDesc, 'UNKNOWN') + '</td>' +
						  '<td style="border:1px solid #000; padding:8px;">' + ISNULL(SKU, 'UNKNOWN') + '</td>' +
						  '<td style="border:1px solid #000; padding:8px;">' + CAST(ISNULL(qty, 0) AS VARCHAR) + '</td>' +
						  '</tr>'
						FROM #wo
						FOR XML PATH(''), TYPE
					  ).value('.', 'NVARCHAR(MAX)')

				SET @tableHTML = @tableHTML + N'</table><br><br>';
                SET @body = @body + @tableHTML;

                SET @tableHTML= '';

	            FETCH NEXT FROM CUR_singlewo INTO @workOrderHeaderId, @workOrderName
		    END
		
            CLOSE CUR_singlewo
		    DEALLOCATE CUR_singlewo
 
            DECLARE @Subject VARCHAR(500), @mailId BIGINT, @emailList VARCHAR(MAX);

            SET @Subject = '[NEW] - Work Order # Receive ' + CONVERT(VARCHAR, getdate(), 106)

			SET @body = @body + '</HTML>'

 
			DECLARE @emailCategoryId INT = (SELECT emailCategoryId FROM md_EmailCategory WHERE actionName IN ('New WO'))

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

			UPDATE wo SET
				apiStatus = '_ACK_'
			FROM workOrderHeader wo
				INNER JOIN #woList ls
					ON wo.workOrderHeaderId = ls.workOrderHeaderId
			WHERE wo.companyId = @companyId
 
            SET @tableHTML = '';
            SET @body = ''

			FETCH NEXT FROM CUR_wo INTO @companyId
		END
		CLOSE CUR_wo
		DEALLOCATE CUR_wo
	END TRY

	BEGIN CATCH

		SELECT '_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as returnMessage

	END CATCH
END

GO


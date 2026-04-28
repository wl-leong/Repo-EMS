-- =============================================
-- Author:		WL Leong
-- Create date: 2024-01-15
-- Used By:	    EMS -> SO Module -> SO Listing -> Reopen SO

-- Description : Once the SO is approved & raised PO, can reopen it

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-10-10   6.0         ZY Wong     Update soHeader lastUpdatedDate 
-- 2024-02-15	5.0			WL Leong	reopen PI, reopen also PO with lastUpdatedDate
-- 2024-02-02	4.0			WL Leong	Allow close PI/SO to be reopen
-- 2024-01-31	3.0			ZY Wong		Update apiStatus = '_REOP_'
-- 2024-01-22	2.0			ZY Wong		Add XACT_ABORT
-- 2023-06-08	1.0			WL Leong	Initial
-- ==========================================================================================
  --[dbo].[SSP_SalesOrder_ReopenOrder]  N'{"soList":[{"soHeaderId":"20411"}]}', 1
  --select * from soHeader
CREATE PROCEDURE [dbo].[SSP_SalesOrder_ReopenOrder]
@orderJson VARCHAR(MAX),
@updateBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY

--1105	Open SO
--1106	Confirm SO
--1107	Cancel SO
--1108	Close SO
	--DECLARE @orderJson VARCHAR(MAX)
	--DECLARE @updateBy INT = 1
	--SET @orderJson = N'{"soList":[{"soHeaderId":"10006"}, {"soHeaderId":"10007"}]}'
		-- Read json content
		 
		DROP TABLE IF EXISTS #order;

		SELECT soHeaderId
		INTO #order
		FROM  OPENJSON(@orderJson, '$.soList') 
   			WITH (
				soHeaderId BIGINT	N'$.soHeaderId'
			)

		DROP TABLE IF EXISTS #orderList;

		SELECT s.soName, s.soHeaderId, s.soStatus
		INTO #orderList
		FROM soHeader s
			INNER JOIN #order odr
				ON s.soHeaderId = odr.soHeaderId
		
		DECLARE @returnMessage as VARCHAR(500), @poMessage as VARCHAR(500)

		IF (SELECT COUNT(1) FROM #orderList WHERE soStatus = 1107) > 0
		BEGIN
			SELECT @returnMessage = COALESCE(@returnMessage + ', ' + soName, soName) 
			From #orderList 
			WHERE soStatus = 1107

			SELECT '_ALERT_' as status, 'SO# ' + @returnMessage + ' is/are already canceled, cannot reopen' AS returnMessage 

			RETURN -1
		END
		
		--IF (SELECT COUNT(1) FROM #orderList WHERE soStatus = 1108) > 0
		--BEGIN
		--	SELECT @returnMessage = COALESCE(@returnMessage + ', ' + soName, soName) 
		--	From #orderList 
		--	WHERE soStatus = 1108

		--	SELECT '_ALERT_' as status, 'SO# ' + @returnMessage + ' is/are already closed, cannot reopen' AS returnMessage 

		--	RETURN -1
		--END

		BEGIN TRANSACTION

		IF (SELECT COUNT(1) FROM #orderList WHERE soStatus IN (1106, 2125)) > 0
		BEGIN
			DECLARE  @soName as TABLE(soName varchar(50))
-- update own so to reopen
			UPDATE s SET
				soStatus = 2144,
				apiStatus = '_REOP_',
                lastUpdatedDate = getdate(),
				updateBy = @updateBy,
				updateDate = getdate()
			OUTPUT INSERTED.soName INTO @soName
			FROM #orderList odr
				INNER JOIN soHeader s
					ON odr.soHeaderId = s.soHeaderId
					AND odr.soStatus IN (1106, 2125)
	 
			UPDATE sol SET
				poQty = 0,
				soLineItemStatus = 2144,
				updateBy = @updateBy,
				updateDate = getdate()
			FROM #orderList odr
				INNER JOIN soLineItem sol
					ON odr.soHeaderId = sol.soHeaderId
					AND odr.soStatus IN (1106, 2125)
					AND sol.soLineItemStatus <> 1107

 
			SELECT @returnMessage = COALESCE(@returnMessage + ', ' + soName, soName) 
			FROM @soName

-- update own po to reopen
			IF (SELECT COUNT(1) FROM #orderList WHERE soStatus IN (2125)) > 0
			BEGIN
				DECLARE  @poName as TABLE(poId BIGINT, poName varchar(50))

				DROP TABLE IF EXISTS #impactPO;

				SELECT p.poId, p.poName, p.poStatus
				INTO #impactPO
				FROM @soName s
					INNER JOIN poHeader p
						ON s.soName = p.poReferenceId

						 
				UPDATE p SET
					poStatus = 2143,
					lastUpdatedDate = getdate(),
					updateBy = @updateBy,
					updateDate = getdate()
				OUTPUT INSERTED.poId, INSERTED.poName INTO @poName
				FROM @soName s
					INNER JOIN poHeader p
						ON s.soName = p.poReferenceId
 
				UPDATE pol SET
					ItemStatus = 2143,
					updateBy = @updateBy,
					updateDate = getdate()
				FROM @poName p
					INNER JOIN poLineItem pol
						ON p.poId = pol.poId


-- update customer so to onHold
				SELECT @poMessage = COALESCE(@poMessage + ', ' + poName, poName) 
				FROM @poName

			END
		END

		COMMIT TRANSACTION

		SELECT '_SUCCESS_' as status, 'SO# '+ @returnMessage + ' is/are reopen; ' +
			CASE WHEN @poMessage IS NOT NULL THEN 'PO# ' + @poMessage + ' is onhold, please inform supplier' ELSE '' END AS returnMessage 
 
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


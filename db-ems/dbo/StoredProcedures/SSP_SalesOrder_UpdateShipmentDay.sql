-- =============================================
-- Author:		WL Leong
-- Create date: 2023-09-21
-- Used By:	    EMS -> PO Module -> PO Listing -> Update ShipDate
--
-- Description : Change PO shipdate and update in SO
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-11-18   4.0         ZY Wong     If soStatus is Draft ignore lastUpdatedDate, standardize error handling
-- 2024-02-23	3.0			ZY Wong		Return error msg if @newShipDate is invalid
-- 2024-01-17	2.0			WL Leong	Update the last updated Date 
-- 2023-09-21	1.0			WL Leong	Initial
-- ==========================================================================================

 --EXEC dbo.SSP_SalesOrder_UpdateShipmentDay '2024-03-24', 20440, 1

CREATE PROCEDURE  [dbo].[SSP_SalesOrder_UpdateShipmentDay]
@newshipDate date,
@soId BIGINT,
@enterBy INT
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON;
BEGIN TRY
	BEGIN TRANSACTION

	DECLARE @exitingRow INT, @containerQty INT, @availQty INT, @BOL varchar(20), @orderStatus INT, @csPO varchar(20), @thirdPartyPO varchar(20), @soStatus INT
	DECLARE @returnMessage varchar(500), @soReferenceId varchar(20);

	IF @soId IS NULL
	BEGIN
		SET @returnMessage = 'Please choose a SO to continue';
		THROW 60000, @returnMessage, 1;
	END

	IF @newshipDate < CONVERT(DATE, GETDATE())
	BEGIN
		SET @returnMessage = 'Please choose a valid date';
		THROW 60000, @returnMessage, 1;

	END
 
 	UPDATE soHeader SET
		earlyShipDate = @newShipDate,
		lateShipDate = DATEADD(DAY, 7, @newShipDate),
		updateDate = getdate(),
		updateBy = @enterBy,
		lastUpdatedDate = CASE WHEN soStatus = 1105 THEN NULL ELSE getdate() END
	WHERE  soHeaderId = @soId
		AND @newshipDate >= CONVERT(DATE, GETDATE())
 
	DECLARE @soName VARCHAR(50) = (SELECT soName FROM soHeader WHERE soHeaderId = @soId);

  	UPDATE poHeader SET
		poEarlyShipDate = @newShipDate,
		polateShipDate = DATEADD(DAY, 7, @newShipDate),
		updateDate = getdate(),
		updateBy = @enterBy
	WHERE  poReferenceId = @soName
		AND @newshipDate >= CONVERT(DATE, GETDATE())
 
 
	SET @returnMessage = @soName + ' has update shipdate to ' + CAST(@newshipDate as varchar(12))
	
	SELECT '_SUCCESS_' as execStatus, @returnMessage as execMessage

	COMMIT TRANSACTION;
 
END TRY

BEGIN CATCH
	IF (@@TRANCOUNT > 0)
	BEGIN
		ROLLBACK TRANSACTION 
	END 

	IF (XACT_STATE()) = 1  
	BEGIN  
		COMMIT TRANSACTION ;     
	END;  

    IF @returnMessage IS NULL
        SET @returnMessage = CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE()

	SELECT '_FAILURE_' as execStatus, @returnMessage as execMessage
END CATCH

END

GO


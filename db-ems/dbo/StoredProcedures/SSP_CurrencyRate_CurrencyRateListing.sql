-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-03-25
-- Used By:	    EMS -> System Module -> Currency Rate -> Currency Rate Listing

-- Description : View currency rate listing

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-04-04	1.0			ZY Wong		Initial
-- ==========================================================================================
-- EXEC [SSP_CurrencyRate_CurrencyRateListing] 11
CREATE PROCEDURE [dbo].[SSP_CurrencyRate_CurrencyRateListing]
@companyId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
		
		--DECLARE @companyId INT = 11;

		SELECT homeCurrency, foreignCurrency, foreignRate
		FROM md_CurrencyRate
		WHERE companyId = @companyId
			AND status = 1 

END

GO


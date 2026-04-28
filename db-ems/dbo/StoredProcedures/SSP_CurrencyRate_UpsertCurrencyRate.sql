-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-03-25
-- Used By:	    EMS -> System Module -> Currency Rate -> Add currency rate

-- Description : Add currency rate

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-03-25	1.0			ZY Wong		Initial
-- ==========================================================================================
-- EXEC [SSP_CurrencyRate_UpsertCurrencyRate] N'{"currencyRateList":[{"companyId":"11","startDate":"2024-04-04","endDate":"2024-04-10","homeCurrency":"USD","foreignCurrency":"MYR","foreignRate":"0.218800"}]}',1
CREATE PROCEDURE [dbo].[SSP_CurrencyRate_UpsertCurrencyRate]
@Json VARCHAR(MAX),
@updateBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	
	BEGIN TRY
		BEGIN TRANSACTION
 
		DECLARE @ErrMessage VARCHAR(MAX);

		--DECLARE @Json VARCHAR(MAX) = 
		--	N'{"currencyRateList":[{
		--		"companyId":"11",
		--		"startDate":"2024-04-09",
		--		"endDate":"2024-04-30",
		--		"homeCurrency":"USD",
		--		"foreignCurrency":"MYR",
		--		"foreignRate":"0.218800"
		--		}]}',
		--	@updateBy INT = 1;

		DROP TABLE IF EXISTS #currencyRateList;

		SELECT * 
		INTO #currencyRateList
		FROM  OPENJSON(@Json, '$.currencyRateList') 
   			WITH (
				companyId INT					N'$.companyId',
				startDate DATE					N'$.startDate',
				endDate DATE					N'$.endDate',
				homeCurrency VARCHAR(3)			N'$.homeCurrency',
				foreignCurrency VARCHAR(3)		N'$.foreignCurrency',
				foreignRate NUMERIC(13,6)		N'$.foreignRate'
			)

        DROP TABLE IF EXISTS #checkCurrencyExisting;

		SELECT MAX(cr.rateId) as rateId, l.companyId, l.startDate, l.endDate, l.homeCurrency, l.foreignCurrency, l.foreignRate
		INTO #checkCurrencyExisting
		FROM #currencyRateList l
			LEFT JOIN md_CurrencyRate cr
				ON l.homeCurrency = cr.homeCurrency
				AND l.foreignCurrency = cr.foreignCurrency
				AND l.companyId = cr.companyId
				AND cr.EndDate >= l.startDate 
		GROUP BY l.companyId, l.startDate, l.endDate, l.homeCurrency, l.foreignCurrency, l.foreignRate

        -- update if have existing active rate / create new currency rate
        -- historical table will keep history
		IF (SELECT COUNT(1) FROM #checkCurrencyExisting WHERE rateId IS NOT NULL) > 0 
		BEGIN
			UPDATE md_CurrencyRate SET
                startDate = l.startDate,
				endDate = l.endDate,
                foreignRate = l.foreignRate,
				updateBy = @updateBy,
				updateDate = GETDATE()
			FROM md_CurrencyRate cr
				INNER JOIN #checkCurrencyExisting l
					ON cr.rateId = l.rateId
			WHERE l.rateId IS NOT NULL
		END
        ELSE 
        BEGIN
            INSERT INTO md_CurrencyRate (companyId, startDate, endDate, homeCurrency, foreignCurrency, foreignRate, status, enterBy, enterDate, updateBy, updateDate)
		    SELECT companyId, startDate, endDate, homeCurrency, foreignCurrency, foreignRate, 1 as status, @updateBy, GETDATE(), @updateBy, GETDATE()
		    FROM #checkCurrencyExisting
        END

		-- update currencyRate for Draft PO
		UPDATE poHeader SET
			foreignCurrencyRate = cr.foreignRate
		FROM poHeader po
			INNER JOIN #currencyRateList cr
				ON po.homeCurrencyCode = cr.homeCurrency
				AND po.foreignCurrencyCode = cr.foreignCurrency
				AND po.companyId = cr.companyId
		WHERE poStatus = 1079  -- Draft PO

		SET @ErrMessage = (SELECT 'Currency Rate for ' + homeCurrency + ' - ' + foreignCurrency + ' (' + CONVERT(VARCHAR, foreignRate) + ') is successful added.'
							FROM #currencyRateList);

		COMMIT TRANSACTION

		SELECT '_SUCCESS_' as status, @ErrMessage AS returnMessage		

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


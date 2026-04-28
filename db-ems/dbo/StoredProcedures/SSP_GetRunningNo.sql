
/**
select * from md_company
select * from md_sequenceNumber where condition = 'SO'

 
DECLARE @StringFormat varchar(50)
--EXEC [dbo].[SSP_GetPONo] 'PO', 1, 'VG(LLY)095220127', @StringFormat  output

EXEC [dbo].[SSP_GetRunningNo] 'SO', 3, @StringFormat  output

SELECT @StringFormat
**/
-- =============================================
-- Author:		WL Leong
-- Create date: 2023-06-08
-- Used By:	    Use to generate all running #

-- Description : ItemFormat is the format and replace the xxx with running#

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-01-22	2.0			ZY Wong		Add XACT_ABORT
-- 2023-06-08	1.0			WL Leong	Initial
-- ==========================================================================================

CREATE PROCEDURE [dbo].[SSP_GetRunningNo]
@keyID VARCHAR(50),
@csId INT,
@StringFormat varchar(50) OUTPUT
AS 
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ItemFormat varchar(20), @NextNum bigint, @returnstring varchar(50), @FormatIndex int, @MaxNum bigint
	DECLARE @runningNum varchar(10), @Prefix varchar(10) 

	BEGIN TRAN
		SELECT @NextNum = NextNum, @FormatIndex=FormatIndex, @MaxNum=MaxNum, @ItemFormat=ItemFormat
		FROM MD_SequenceNumber WITH (TABLOCKX)
		WHERE condition =  @keyID AND csId = @csId

		UPDATE MD_SequenceNumber SET 
			NextNum=NextNum+1 
		WHERE condition = @keyID AND csId = @csId

	COMMIT TRAN

	IF @NextNum > @MaxNum
	BEGIN
		SET @runningNum = CAST(@NextNum as varchar)

		SET @StringFormat = REPLACE(@ItemFormat, 'yy', RIGHT(YEAR(getdate()), 2))
		SET @StringFormat = REPLACE(@StringFormat, 'xxxxx', RIGHT('00000' + CONVERT(NVARCHAR, @runningNum), 5))
 
	END
	ELSE 
	BEGIN
		SET @runningNum = SUBSTRING(CAST(@MaxNum+1+@NextNum AS VARCHAR),2,LEN(@MaxNum+1+@NextNum))

		SET @StringFormat = REPLACE(@ItemFormat, 'yy', RIGHT(YEAR(getdate()), 2))
        --SET @StringFormat = REPLACE(@ItemFormat, 'xxxxx', @runningNum)
        SET @StringFormat = REPLACE(@StringFormat, 'xxxxx', RIGHT('00000' + CONVERT(NVARCHAR, @runningNum), 5))
	END
 

END

GO


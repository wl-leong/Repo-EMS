


/**
DECLARE @StringFormat varchar(50)
--EXEC [dbo].[SSP_GetPONo] 'PO', 1, 'VG(LLY)095220127', @StringFormat  output
EXEC [dbo].[SSP_GetPONo] 'PO', 3, '', @StringFormat  output

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

CREATE PROCEDURE [dbo].[SSP_GetRunningNo_WithDate]
@keyID varchar(50),
@csId int,
@POName varchar(50),
@StringFormat varchar(50) output
AS 
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ItemFormat varchar(10), @NextNum bigint, @returnstring varchar(50), @FormatIndex int, @MaxNum bigint
	DECLARE @runningNum varchar(10), @Prefix varchar(10) 

	BEGIN TRAN
		SELECT @NextNum = NextNum, @FormatIndex=FormatIndex, @MaxNum=MaxNum, @ItemFormat=ItemFormat
		FROM MD_SequenceNumber WITH (TABLOCKX)
		WHERE condition = @keyID AND csId = @csId

		UPDATE MD_SequenceNumber SET 
			NextNum=NextNum+1 
		WHERE condition=@keyID AND csId = @csId

		 
	COMMIT TRAN

 
	SELECT @Prefix = LEFT(@POName, CHARINDEX(')', @POName) + 3) -- only VG will need to use the prefix

	IF @Prefix  = ''
	BEGIN
		DECLARE @requestDate varchar(6)
		SET @requestDate = CONVERT(varchar, getdate(), 12)

		IF @NextNum > @MaxNum
			BEGIN
				SET @runningNum = CAST(@NextNum as varchar)

				SET @StringFormat = @ItemFormat  + @runningNum +  @requestDate
			END
		ELSE 
			BEGIN
				SET @runningNum = SUBSTRING(CAST(@MaxNum+1+@NextNum AS VARCHAR),2,LEN(@MaxNum+1+@NextNum))

				SET @StringFormat = @ItemFormat  + @runningNum +  @requestDate
			END
		END
	ELSE 
	BEGIN
		IF @NextNum > @MaxNum
			BEGIN
				SET @runningNum = CAST(@NextNum as varchar)

				SET @StringFormat = @Prefix + '-' + @runningNum + '-' + CONVERT(varchar(6), getdate(), 12)
			END
		ELSE 
			BEGIN
				SET @runningNum = SUBSTRING(CAST(@MaxNum+1+@NextNum AS VARCHAR),2,LEN(@MaxNum+1+@NextNum))

				SET @StringFormat = @Prefix + '-' + @runningNum + '-' + CONVERT(varchar(6), getdate(), 12)
			END
	END

END

GO


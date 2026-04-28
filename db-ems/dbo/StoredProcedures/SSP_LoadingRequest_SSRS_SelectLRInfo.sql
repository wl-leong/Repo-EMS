-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-04-25
-- Used By:	    EMS -> LR Module -> LR Listing -> Export approved LR (SSRS)
--
-- Description : 
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-08-22   3.0         ZY Wong     Get company address using sp
-- 2024-11-01   2.0         ZY Wong     Remove hardcode for @companyId, use @companyId passed in
-- 2024-04-25	1.0			ZY Wong 	Initial
-- ==========================================================================================
-- EXEC [SSP_LoadingRequest_SSRS_SelectLRInfo] 11, 759
CREATE PROCEDURE [dbo].[SSP_LoadingRequest_SSRS_SelectLRInfo]
@companyId INT,
@lrHeaderId BIGINT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	
        DROP TABLE IF EXISTS #lrInfo;

        SELECT @companyId as companyId, lrName, lrDate
        INTO #lrInfo
        FROM lrHeader 
        WHERE lrHeaderId = @lrHeaderId 

        -- prepare company address
        DECLARE @companyAddr TABLE(companyId INT, companyName VARCHAR(100), companyAddrName VARCHAR(100), companyAddr1 VARCHAR(MAX), companyAddr2 VARCHAR(200), 
            contactNumber VARCHAR(50), faxNumber VARCHAR(50), email VARCHAR(100), companyPhone VARCHAR(200)); 
        DECLARE @companyPhone VARCHAR(200);

        INSERT INTO @companyAddr (companyId, companyName, companyAddrName, companyAddr1, companyAddr2, contactNumber, faxNumber, email)
        EXEC [SSP_GetReportAddressInfo] 'Company', @companyId, 1       
        
        SET @companyPhone = ( SELECT CASE WHEN LEN(contactNumber) > 0 THEN 'TEL : ' + contactNumber + '  ' ELSE '' END + 
                                CASE WHEN LEN(faxNumber) > 0 THEN 'FAX : ' + faxNumber ELSE '' END
                                FROM @companyAddr);

        UPDATE @companyAddr SET
            companyPhone = @companyPhone

        SELECT companyName, companyAddr1, @companyPhone as companyPhone, lrName, lrDate
        FROM #lrInfo l
            INNER JOIN @companyAddr c
                ON l.companyId = c.companyId 
 
END

GO


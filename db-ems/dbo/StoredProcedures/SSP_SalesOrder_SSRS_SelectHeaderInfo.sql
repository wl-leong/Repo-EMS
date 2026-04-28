-- =============================================
-- Author:		WL Leong
-- Create date: 2024-05-05
-- Used By:	    EMS -> SO Module -> SO Listing -> Export SO/PI ssrs
--
-- Description : 
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-09-24   7.0         ZY Wong     Add approveBy column to show approval signature
-- 2025-08-21   6.0         ZY Wong     Restructure sp, get company & customer address using sp, add column isDraft, add user signature & company chop
-- 2025-06-10   5.0         ZY Wong     Customer address add customerAddressName, remove unecessary comma between customer address
-- 2025-05-29   4.0         ZY Wong     Change cargoReadyDate to get config from md_defaultconfig
-- 2024-11-01   3.0         ZY Wong     Change @customerPO to VARCHAR(200)
-- 2024-07-01   2.0         ZY Wong     Add @isCsSg & @isBankSg
-- 2024-05-05	1.0			WL Leong	Initial
-- ==========================================================================================
-- EXEC SSP_SalesOrder_SSRS_SelectHeaderInfo 21701, 'SO'

CREATE PROCEDURE [dbo].[SSP_SalesOrder_SSRS_SelectHeaderInfo]
@soHeaderId BIGINT,
@module VARCHAR(3)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

        --DECLARE @soHeaderId BIGINT = 21701;

        DROP TABLE IF EXISTS #soheader;

        SELECT soHeaderId, companyId, customerId, soName, soDate, customerPo, shipToId, shipWay as shipwayId, portOfLanding as shipFrom, earlyShipDate as deliveryDate, lastUpdatedDate, 
            CASE WHEN soStatus IN (1105,2144) THEN 1 ELSE 0 END as isDraft, -- draft/reopen
            CASE WHEN lastUpdatedDate IS NULL THEN 0 ELSE 1 END as isUpdate,
            CAST('' as VARCHAR(50)) as shipTo, CAST('' as VARCHAR(100)) as shipWay, approveBy
        INTO #soheader
        FROM soHeader
        WHERE soHeaderId = @soHeaderId

        UPDATE #soheader SET
            shipTo = UPPER(st.shipToLabel)
        FROM md_shipToDestination st
        WHERE #soheader.shipToId = st.shipToId

        UPDATE #soheader SET
            shipWay = UPPER(sw.categoryName)
        FROM md_masterCategory sw
        WHERE #soheader.shipwayId = sw.categoryId

        DECLARE @companyId INT, @approveBy INT, @customerId INT, @parentCustomerId INT, @csId INT, @paymentTermId INT, @paymentTerm VARCHAR(100),
            @deliveryDate DATE, @shipDateConfig INT, @cargoReadyDate DATE;

        SELECT @companyId = companyId, @approveBy = approveBy, @deliveryDate = deliveryDate, @customerId = customerId 
        FROM #soheader

        SET @parentCustomerId = (SELECT parent_customerId FROM md_customer WHERE customerId = @customerId AND parent_customerId > 0);

        IF @parentCustomerId IS NOT NULL
        BEGIN
            SET @csId = @parentCustomerId;
        END
        ELSE
        BEGIN
            SET @csId = @customerId;
        END

        SET @paymentTermId = (SELECT paymentTerm FROM md_customer WHERE customerId = @csId);
        SET @paymentTerm = (SELECT categoryName FROM md_masterCategory WHERE categoryId = @paymentTermId);

        SET @shipDateConfig = (SELECT TOP 1 CAST(configValue as INT) FROM md_defaultConfig WHERE companyId = @companyId AND configName = 'CargoReadyDate');

        -- use default config if not configured
        IF @shipDateConfig IS NULL
        BEGIN
            SET @shipDateConfig = (SELECT TOP 1 CAST(configValue as INT) FROM md_defaultConfig WHERE companyId = 0 AND configName = 'CargoReadyDate');
        END

        SET @cargoReadyDate = DATEADD(DAY, @shipDateConfig, @deliveryDate);
        
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
 
        -- parepare customer address
        DECLARE @customerAddr TABLE(customerId INT, customerName VARCHAR(100), customerAddrName VARCHAR(100), customerAddr1 VARCHAR(MAX), customerAddr2 VARCHAR(200), 
            contactNumber VARCHAR(50), faxNumber VARCHAR(50), email VARCHAR(100), soHeaderId BIGINT, paymentTerm VARCHAR(100));

        INSERT INTO @customerAddr (customerId, customerName, customerAddrName, customerAddr1, customerAddr2, contactNumber, faxNumber, email)
        EXEC [SSP_GetReportAddressInfo] 'Customer', @csId, 2

        UPDATE @customerAddr SET
            soHeaderId = @soHeaderId,
            paymentTerm  = @paymentTerm

        DECLARE @customerPO VARCHAR(200) = (SELECT TOP 1 customerPO FROM #soHeader);
        DECLARE @headerCustomerPO VARCHAR(50);  

        SET @headerCustomerPO = (
                SELECT CASE WHEN COUNT(customerPO) = 1 THEN MAX(customerPO) ELSE MIN(customerPO) + ' - ' + MAX(customerPO) END
                FROM (
                    SELECT LTRIM(RTRIM([value])) as customerPO
                    FROM STRING_SPLIT(@customerPO, ',')
                    ) g
            );

        DECLARE @filePath VARCHAR(200) = 'file:\\fangpaisvr\uploads\';

        -- get user signature & company chop
        DROP TABLE IF EXISTS #sign;

        SELECT imageCategory, referenceId, @filePath + 'esignature\' + imageName as imageName, 'image/' + imageMimeType as imageMimeType
        INTO #sign
        FROM systemImage
        WHERE imageCategory = 'eSignature'
            AND referenceId = @approveBy
        UNION ALL 
        SELECT imageCategory, referenceId, @filePath + 'companychop\' + imageName as imageName, 'image/' + imageMimeType as imageMimeType
        FROM systemImage
        WHERE imageCategory = 'companyChop'
            AND referenceId = @companyId

        SELECT companyName, companyAddr1, companyPhone,          
            soName, soDate, @headerCustomerPO as customerPO, shipWay, shipFrom, shipTo, @cargoReadyDate as cargoReadyDate, deliveryDate, lastUpdatedDate,
            customerName, customerAddrName, customerAddr1, customerAddr2, cs.contactNumber, paymentTerm,
            isDraft, isUpdate, 
            esign.imageName as eSignature, esign.imageMimeType as userMimeType, chop.imageName as companyChop, chop.imageMimeType as companyMimeType
            --NULL as eSignature, NULL as userMimeType, NULL as companyChop, NULL as companyMimeType
        FROM #soHeader so
            INNER JOIN @companyAddr cmpy
                ON so.companyId = cmpy.companyId
            INNER JOIN @customerAddr cs
                ON so.soHeaderId = cs.soHeaderId   
            LEFT JOIN #sign esign
                ON so.approveBy = esign.referenceId
                AND esign.imageCategory = 'eSignature'
            LEFT JOIN #sign chop
                ON so.companyId = chop.referenceId
                AND chop.imageCategory = 'companyChop'
 
END

GO


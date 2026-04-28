-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-05-07
-- Used By:	    EMS -> PO Module -> PO Listing -> Export PO pdf ssrs
--
-- Description : Export Purchase Order report
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-05-29   3.0         ZY Wong     Change cargoReadyDate to get config from md_defaultconfig
-- 2024-05-14	2.0			WL Leong 	LEFT JOIN the table to show blank if not found
-- 2024-05-07	1.0			ZY Wong 	Initial
-- ==========================================================================================
-- [SSP_PurchaseOrder_SSRS_SelectHeaderInfo] 306
CREATE PROCEDURE [dbo].[SSP_PurchaseOrder_SSRS_SelectHeaderInfo]
@poId BIGINT
AS 
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

    --DECLARE @poId BIGINT = 15

    DROP TABLE IF EXISTS #poHeader;

    SELECT p.companyId, p.supplierId, poName, poDate, poReferenceId as soName, reference1 as customerPo, 
        sv.categoryName as shipWay, portOfLanding as shipFrom, 
        ISNULL(st.shipToLabel, '') as shipTo, poEarlyShipDate as delivery, lastUpdatedDate, poApprovalBy
    INTO #poHeader
    FROM poHeader p
        LEFT JOIN md_shipToDestination st
            ON p.shipToId = st.shipToId
        LEFT JOIN md_masterCategory sv
            ON p.shipVia = sv.categoryId
    WHERE poId = @poId

    DECLARE @customerPO VARCHAR(100);

    SET @customerPO = (
            SELECT CASE WHEN minCsPo = maxCsPo THEN minCsPo ELSE minCsPo + ' - ' + maxCsPo END
            FROM (
                SELECT MAX(customerPO) as maxCsPo, MIN(customerPO) as minCsPo 
                FROM (SELECT csPo.[value] as customerPO
                        FROM #poHeader
                        CROSS APPLY STRING_SPLIT (REPLACE(customerPO,' ',''), ',') csPo
                        ) g
                )g
        )

    DECLARE @companyId INT = (SELECT companyId FROM #poHeader);
    DECLARE @supplierId INT = (SELECT supplierId FROM #poHeader);

    DECLARE @cargoReadyDate DATE, @lateShipDate DATE, @shipDateConfig INT;

    SET @lateShipDate = (SELECT delivery FROM #poHeader);
    SET @shipDateConfig = (SELECT configValue FROM md_defaultConfig WHERE companyId = @companyId AND configName = 'CargoReadyDate');

    -- use default config if not configured
    IF @shipDateConfig IS NULL
    BEGIN
        SET @shipDateConfig = (SELECT configValue FROM md_defaultConfig WHERE companyId = 0 AND configName = 'CargoReadyDate');
    END

    SET @cargoReadyDate = DATEADD(DAY, @shipDateConfig, @lateShipDate);

    DROP TABLE IF EXISTS #companyInfo;

    SELECT cpy.companyId, UPPER(companyName) as companyName, UPPER(address) as addressLine1, UPPER(addressLine2) as addressLine2, UPPER(city) as city, UPPER(state) as state, postcode, UPPER(c.categoryName) as country, telephoneNumber, faxNumber,
        CASE WHEN cpy.country = 3 THEN 1 ELSE 0 END as isSg 
    INTO #companyInfo
    FROM md_Company cpy
        INNER JOIN md_MasterCategory c
            ON cpy.country = c.categoryId
    WHERE cpy.companyId = @companyId

    DECLARE @isSg INT = (SELECT isSg FROM #companyInfo);
    DECLARE @address VARCHAR(500);

    IF @isSg = 1
    BEGIN
        SET @address = (SELECT addressLine1 + ', ' + 
                            CASE WHEN LEN(addressLine2) = 0
                                THEN country + ' ' + postcode + '.'
                            ELSE (TRIM(addressLine2) + ', ') + country + ' ' + postcode + '.'
                            END
                        FROM #companyInfo);
    END
    ELSE
    BEGIN
        SET @address = (SELECT addressLine1 + ', ' + 
                            CASE WHEN LEN(addressLine2) = 0 AND LEN(city) = 0 AND LEN(state) = 0 
                                THEN postcode + ', ' + country + '.'
                            WHEN LEN(addressLine2) > 0 AND LEN(city) = 0 AND LEN(state) = 0 
                                THEN (TRIM(addressLine2) + ', ') + postcode + ', ' + country + '.'
                            WHEN LEN(addressLine2) > 0 AND LEN(city) > 0 AND LEN(state) = 0 
                                THEN (TRIM(addressLine2) + ', ') + postcode + ' '+ (TRIM(city) + ', ') + country + '.'
                            WHEN LEN(addressLine2) > 0 AND LEN(city) = 0 AND LEN(state) > 0 
                                THEN (TRIM(addressLine2) + ', ') + postcode + ', '+ (TRIM(state) + ', ') + country + '.'
                            WHEN LEN(addressLine2) = 0 AND LEN(city) > 0 AND LEN(state) > 0 
                                THEN postcode + ' '+ (TRIM(city) + ', ') + (TRIM(state) + ', ') + country + '.'                            
                            ELSE (TRIM(addressLine2) + ', ') + postcode + ' '+ (TRIM(city) + ', ') + (TRIM(state) + ', ') + country + '.'
                            END
                        FROM #companyInfo);
    END

    DROP TABLE IF EXISTS #supplierInfo;

    SELECT supplierId, UPPER(supplierCompanyName) as supplierCompanyName, UPPER(supplierAddress) as supplierAddress, UPPER(supplierAddressLine2) as supplierAddressLine2, UPPER(supplierCity) as supplierCity, UPPER(supplierStates) as supplierStates, supplierPostcode, UPPER(c.categoryName) as country, ISNULL(pt.categoryName,'') as paymentTerm
    INTO #supplierInfo
    FROM md_Supplier s
        INNER JOIN md_MasterCategory c
            ON s.supplierCountry = c.categoryId
        LEFT JOIN md_MasterCategory pt
            ON s.paymentTerm = pt.categoryId
    WHERE supplierId = @supplierId

    DECLARE @supplierAddress1 VARCHAR(500), @supplierAddress2 VARCHAR(500), @supplierAddress3 VARCHAR(500);

    SET @supplierAddress1 = (SELECT supplierAddress FROM #supplierInfo);
    SET @supplierAddress2 = (SELECT supplierAddressLine2 FROM #supplierInfo);
    SET @supplierAddress3 = (SELECT 
                                CASE WHEN LEN(supplierCity) = 0 AND LEN(supplierStates) = 0 
                                    THEN supplierPostcode + ', ' + country + '.'                                
                                WHEN LEN(supplierCity) > 0 AND LEN(supplierStates) = 0 
                                    THEN supplierPostcode + ' '+ (TRIM(supplierCity) + ', ') + country + '.'
                                WHEN LEN(supplierCity) = 0 AND LEN(supplierStates) > 0 
                                    THEN supplierPostcode + ', '+ (TRIM(supplierStates) + ', ') + country + '.'
                                ELSE supplierPostcode + ' '+ (TRIM(supplierCity) + ', ') + (TRIM(supplierStates) + ', ') + country + '.'
                                END 
                            FROM #supplierInfo);     

    SELECT c.companyName, @address as companyAddress, telephoneNumber, faxNumber,
        s.supplierCompanyName, @supplierAddress1 as supplierAddress1, @supplierAddress2 as supplierAddress2, @supplierAddress3 as supplierAddress3, paymentTerm,
        poName, poDate, soName, @customerPO as customerPo, shipWay, shipFrom, shipTo, @cargoReadyDate as cargoReadyDate, delivery, lastUpdatedDate, poApprovalBy
    FROM #poHeader p 
        LEFT JOIN #companyInfo c
            ON p.companyId = c.companyId
        LEFT JOIN #supplierInfo s
            ON p.supplierId = s.supplierId
 
 
END

GO


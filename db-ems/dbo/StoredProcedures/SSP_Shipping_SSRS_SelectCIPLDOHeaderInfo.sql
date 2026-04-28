-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-06-04
-- Used By:	    EMS -> Shipping Module -> Shipping Listing -> Export CI by Invoice ssrs
--
-- Description : Export Commercial Invoice report
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-06-04	1.0			ZY Wong 	Initial
-- ==========================================================================================
/*
--DECLARE @lrHeaderId BIGINT = 24, @bol VARCHAR(20) = 'FNP-BOL-25-00005', @invoiceId VARCHAR(20) = 'FNP-INV-25-00007', @reportType VARCHAR(5) = 'DO'
--DECLARE @lrHeaderId BIGINT = 24, @bol VARCHAR(20) = 'FNP-BOL-25-00005', @invoiceId VARCHAR(20) = 'FNP-INV-25-00007', @reportType VARCHAR(5) = 'CI'
DECLARE @lrHeaderId BIGINT = 24, @bol VARCHAR(20) = 'FNP-BOL-25-00006', @invoiceId VARCHAR(20) = '', @reportType VARCHAR(5) = 'CIPL'

EXEC [SSP_Shipping_SSRS_SelectCIPLDOHeaderInfo] @lrHeaderId, @bol, @invoiceId, @reportType
*/
CREATE PROCEDURE [dbo].[SSP_Shipping_SSRS_SelectCIPLDOHeaderInfo]
@lrHeaderId BIGINT,
@bol VARCHAR(20),
@invoiceId VARCHAR(20),
@reportType VARCHAR(5)
AS 
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

        DECLARE @shipHeader TABLE(shipmentId BIGINT);

        IF @reportType = 'DO'
        BEGIN
            INSERT INTO @shipHeader (shipmentId)
            SELECT shipmentId
            FROM shipmentHeader 
            WHERE bol = @bol
        END
        ELSE IF @reportType = 'CIPL'
        BEGIN
            INSERT INTO @shipHeader (shipmentId)
            SELECT shipmentId
            FROM shipmentHeader 
            WHERE lrHeaderId = @lrHeaderId
        END
        ELSE IF @reportType = 'CI'
        BEGIN
            INSERT INTO @shipHeader (shipmentId)
            SELECT shipmentId
            FROM shipmentHeader 
            WHERE invoiceId = @invoiceId
        END

        DROP TABLE IF EXISTS #shipHeader;

        SELECT companyId, customerId, shipId, invoiceId, lrName as PL, bol as DO, soHeaderId,
            CONVERT(DATE, shipmentDate) as shipmentDate, CONVERT(DATE, invoiceDate) as invoiceDate, CONVERT(DATE, ETD) as ETD, CONVERT(DATE, ETA) as ETA,
            UPPER(pol) as pol, UPPER(pod) as pod, vesselId, haulierId, UPPER(countryOfOrigin) as countryOfOrigin,
            containerTypeId, paymentTermId, CONVERT(NUMERIC(13,5), shipmentWeight) as shipmentWeight
        INTO #shipHeader
        FROM shipmentHeader h
            INNER JOIN @shipHeader s
                ON h.shipmentId = s.shipmentId

        ALTER TABLE #shipHeader ADD paymentTerm VARCHAR(150);
        ALTER TABLE #shipHeader ADD vessel VARCHAR(150);
        ALTER TABLE #shipHeader ADD haulier VARCHAR(150);
        ALTER TABLE #shipHeader ADD containerType VARCHAR(10);

        UPDATE #shipHeader SET
            paymentTerm = p.categoryName
        FROM md_MasterCategory p
        WHERE #shipHeader.paymentTermId = p.categoryId

        UPDATE #shipHeader SET
            vessel = vs.categoryName
        FROM md_MasterCategory vs
        WHERE #shipHeader.vesselId = vs.categoryId

        UPDATE #shipHeader SET
            haulier = hl.haulier
        FROM md_Haulier hl
        WHERE #shipHeader.haulierId = hl.haulierId

        UPDATE #shipHeader SET
            containerType = ct.categoryName
        FROM md_MasterCategory ct
        WHERE #shipHeader.containerTypeId = ct.categoryId

        IF @reportType = 'CIPL'
        BEGIN
            DROP TABLE IF EXISTS #minCIPL;
            
            SELECT MIN(DO) as DO, MIN(shipmentDate) as shipmentDate
            INTO #minInv
            FROM #shipHeader
            WHERE DO IS NOT NULL

            UPDATE #shipHeader SET 
                DO = m.DO,
                shipmentDate = m.shipmentDate
            FROM #minInv m

        END

        DROP TABLE IF EXISTS #containerTypeList;

        SELECT containerTypeId, containerType, COUNT(containerType) as countContainer
        INTO #containerTypeList
        FROM #shipHeader
        GROUP BY containerTypeId, containerType

        DECLARE @companyId INT = (SELECT TOP 1 companyId FROM #shipHeader);
        DECLARE @customerId INT = (SELECT TOP 1  customerId FROM #shipHeader);
        DECLARE @containerTypeId INT = (SELECT containerTypeId FROM #containerTypeList); --should be only 1 container type inside 1 LR/CI/DO/PL, else show error ?

        DECLARE @defaultCurrency VARCHAR(3) = (SELECT configValue FROM md_DefaultConfig WHERE companyId = @companyId AND configName = 'DefaultCurrency');
        DECLARE @containerType VARCHAR(100) = (SELECT STRING_AGG(CONVERT(VARCHAR, countContainer) + ' x ' + containerType, ' & ') FROM #containerTypeList);
        DECLARE @totalShipmentWeight NUMERIC(13,5)= (SELECT SUM(shipmentWeight) FROM #shipHeader);
    
        DECLARE @containerWeight NUMERIC(13,5) = (SELECT CONVERT(NUMERIC(13,5), REPLACE(attributeValue, ' kgs', '')) FROM md_MasterCategoryAttribute WHERE masterCategoryId = @containerTypeId AND attributeName = 'Weight');
        DECLARE @containerCbm NUMERIC(13,5) = (SELECT CONVERT(NUMERIC(13,5), REPLACE(attributeValue, ' m3', '')) FROM md_MasterCategoryAttribute WHERE masterCategoryId = @containerTypeId AND attributeName = 'CBM');
        DECLARE @dimension VARCHAR(50) = (SELECT attributeValue FROM md_MasterCategoryAttribute WHERE masterCategoryId = @containerTypeId AND attributeName = 'Dimension');

        -- get company info
        DROP TABLE IF EXISTS #companyInfo;

        SELECT cpy.companyId, UPPER(companyName) as companyName, UPPER(registerNo) as registerNo, accountNumber, UPPER(address) as addressLine1, UPPER(addressLine2) as addressLine2, 
            UPPER(city) as city, UPPER(state) as state, postcode, UPPER(c.categoryName) as country, telephoneNumber, faxNumber,
            CASE WHEN cpy.country = 3 THEN 1 ELSE 0 END as isSg 
        INTO #companyInfo
        FROM md_Company cpy
            INNER JOIN md_MasterCategory c
                ON cpy.country = c.categoryId
            LEFT JOIN md_CompanyBank bk
                ON cpy.companyId = bk.companyId
                AND bk.statusFlag = 1
        WHERE cpy.companyId = @companyId

        DECLARE @isCompanySg INT = (SELECT isSg FROM #companyInfo);
        DECLARE @address VARCHAR(500);

        IF @isCompanySg = 1
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

        -- get customer info
        DROP TABLE IF EXISTS #customerInfo;

        SELECT customerId, UPPER(customerName) as customerName, UPPER(customerAddress) as customerAddress, UPPER(customerAddressLine2) as customerAddressLine2, 
            UPPER(customerCity) as customerCity, UPPER(customerStates) as customerStates, customerPostcode, UPPER(coty.categoryName) as country, customerContactNumber, customerFaxNumber, 
            CASE WHEN c.customerCountry = 3 THEN 1 ELSE 0 END as isSg
        INTO #customerInfo
        FROM md_Customer c
            INNER JOIN md_MasterCategory coty
                ON c.customerCountry = coty.categoryId
        WHERE customerId = @customerId

        DECLARE @customerAddress1 VARCHAR(500), @customerAddress2 VARCHAR(500);
        DECLARE @isCustomerSg INT = (SELECT isSg FROM #customerInfo);

        SET @customerAddress1 = (SELECT customerAddress FROM #customerInfo);

        IF @isCustomerSg = 1
        BEGIN
            SET @customerAddress2 = (SELECT CASE WHEN LEN(customerAddressLine2) = 0
                                            THEN country + ' ' + customerPostcode + '.'
                                        ELSE (TRIM(customerAddressLine2) + ', ') + country + ' ' + customerPostcode + '.' END FROM #customerInfo);    
        END
        ELSE
        BEGIN
            SET @customerAddress2 = (SELECT CASE WHEN LEN(customerAddressLine2) = 0 AND LEN(customerCity) = 0 AND LEN(customerStates) = 0 
                                            THEN customerPostcode + ' ' + country 
                                        WHEN LEN(customerAddressLine2) > 0 AND LEN(customerCity) = 0 AND LEN(customerStates) = 0 
                                            THEN (TRIM(customerAddressLine2) + ' ') + customerPostcode + ' ' + country 
                                        WHEN LEN(customerAddressLine2) > 0 AND LEN(customerCity) > 0 AND LEN(customerStates) = 0 
                                            THEN (TRIM(customerAddressLine2) + ' ') + customerPostcode + ' '+ (TRIM(customerCity) + ', ') + country 
                                        WHEN LEN(customerAddressLine2) > 0 AND LEN(customerCity) = 0 AND LEN(customerStates) > 0 
                                            THEN (TRIM(customerAddressLine2) + ' ') + customerPostcode + ' '+ (TRIM(customerStates) + ', ') + country 
                                        WHEN LEN(customerAddressLine2) = 0 AND LEN(customerCity) > 0 AND LEN(customerStates) > 0 
                                            THEN customerPostcode + ' '+ (TRIM(customerCity) + ' ') + (TRIM(customerStates) + ' ') + country                           
                                        ELSE (TRIM(customerAddressLine2) + ' ') + customerPostcode + ' '+ (TRIM(customerCity) + ' ') + (TRIM(customerStates) + ' ') + country 
                                        END
                                        FROM #customerInfo);
        END

        SELECT DISTINCT c.companyName, c.registerNo, accountNumber, @address as companyAddress,
            s.customerName, @customerAddress1 as customerAddress1, @customerAddress2 as customerAddress2, customerContactNumber, customerFaxNumber, 
            shp.invoiceId as invoiceId, 
            shp.DO as DO, 
            shp.PL, shp.shipmentDate, 
            shp.invoiceDate as invoiceDate, 
            shp.ETD, shp.ETA, shp.pol, shp.pod, shp.vessel, shp.haulier,
            shp.paymentTerm, shp.countryOfOrigin, @defaultCurrency as defaultCurrency, 
            @containerType as containerType, @totalShipmentWeight as totalShipmentWeight,
            @containerCbm as containerCbm, @containerWeight as containerWeight, @dimension as dimension           
        FROM #shipHeader shp 
            INNER JOIN #companyInfo c
                ON shp.companyId = c.companyId
            INNER JOIN #customerInfo s
                ON shp.customerId = s.customerId

END

GO


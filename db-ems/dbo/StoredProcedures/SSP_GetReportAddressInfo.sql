-- =============================================
-- Author:		ZY Wong
-- Create date: 2025-08-15
-- Used By:	    
-- Description : Select company/customer/supplier address info for report

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-08-15	1.0			ZY Wong 	Initial
-- ==========================================================================================
/*
select * from md_company
select * from md_customer
select * from md_supplier

EXEC [SSP_GetReportAddressInfo] 'company',3,1
EXEC [SSP_GetReportAddressInfo] 'company',3,2
EXEC [SSP_GetReportAddressInfo] 'company',4,1
EXEC [SSP_GetReportAddressInfo] 'company',4,2

EXEC [SSP_GetReportAddressInfo] 'customer',13,1
EXEC [SSP_GetReportAddressInfo] 'customer',13,2
EXEC [SSP_GetReportAddressInfo] 'customer',19,1
EXEC [SSP_GetReportAddressInfo] 'customer',19,2
EXEC [SSP_GetReportAddressInfo] 'customer',26,1
EXEC [SSP_GetReportAddressInfo] 'customer',26,2

EXEC [SSP_GetReportAddressInfo] 'supplier',12,1
EXEC [SSP_GetReportAddressInfo] 'supplier',12,2
EXEC [SSP_GetReportAddressInfo] 'supplier',6,1
EXEC [SSP_GetReportAddressInfo] 'supplier',6,2

*/
CREATE PROCEDURE [dbo].[SSP_GetReportAddressInfo]
@category VARCHAR(10),
@id INT,
@template INT = 1
AS 
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

/*
    category:   Company, Customer, Supplier

    --------------------------------------------------------------------
    template 1: single line (report header)   
    
    - MY, JP:   [addr1], [addr2], [postalCode] [city], [state], [country].    -> default
    - SG:       [addr1], [addr2], [country] [postalCode].
    - US:       [addr1], [addr2], [city], [state] [postalCode], [country].

    --------------------------------------------------------------------
    template 2: two line 
    
    - MY, JP:   [addr1]
                [addr2], [postalCode] [city], [state], [country].

    - SG:       [addr1]
                [addr2], [country] [postalCode].

    - US:       [addr1], 
                [addr2], [city], [state] [postalCode], [country].
*/

        --DECLARE @category VARCHAR(10) = 'Company', @id INT = 4, @template INT = 1;

        DECLARE @address TABLE (
            companyName VARCHAR(100),
            addrName VARCHAR(200),
            addr1 VARCHAR(200),
            addr2 VARCHAR(200),
            city VARCHAR(50),
            [state] VARCHAR(50),
            postalCode VARCHAR(20),
            countryId INT,
            country VARCHAR(50),
            contactNumber VARCHAR(50),
            faxNumber VARCHAR(50),
            email VARCHAR(100)
        );

        IF @category = 'Company'
        BEGIN
            INSERT INTO @address (companyName, addr1, addr2, city, [state], postalCode, countryId, contactNumber, faxNumber, email)
            SELECT UPPER(companyName), UPPER([address]), UPPER(addressLine2), UPPER(city), UPPER([state]), postcode, country, telephoneNumber, faxNumber, LOWER(emailAddress)
            FROM md_Company
            WHERE companyId = @id
        END
        ELSE IF @category = 'Customer'
        BEGIN
            INSERT INTO @address (companyName, addrName, addr1, addr2, city, [state], postalCode, countryId, contactNumber, faxNumber, email)
            SELECT UPPER(customerName), UPPER(customerAddressName), UPPER(customerAddress), UPPER(customerAddressLine2), UPPER(customerCity), UPPER(customerStates), customerPostcode, customerCountry, customerContactNumber, customerFaxNumber, LOWER(customerEmail)
            FROM md_Customer 
            WHERE customerId = @id
        END
        ELSE IF @category = 'Supplier'
        BEGIN
            INSERT INTO @address (companyName, addrName, addr1, addr2, city, [state], postalCode, countryId, contactNumber, faxNumber, email)
            SELECT UPPER(supplierCompanyName), UPPER(supplierAddressName), UPPER(supplierAddress), UPPER(supplierAddressLine2), UPPER(supplierCity), UPPER(supplierStates), supplierPostcode, supplierCountry, supplierContactNumber, supplierFaxNumber, LOWER(supplierEmail)
            FROM md_Supplier
            WHERE supplierId = @id
        END

        DECLARE @countryId INT = (SELECT countryId FROM @address);

        UPDATE @address SET
            country = UPPER(ctry.categoryName)
        FROM md_MasterCategory ctry
        WHERE ctry.categoryId = @countryId

        DECLARE @addrFormat INT = (SELECT CASE 
                                    WHEN @countryId = 3 THEN 2   -- SG
                                    WHEN @countryId = 22 THEN 3  -- US
                                    ELSE 1 END                   -- default
                                    );

        DECLARE @line1 VARCHAR(MAX), @line2 VARCHAR(MAX);

        -- default
        IF @addrFormat = 1
        BEGIN
            IF @template = 1
            BEGIN
                SET @line1 = (SELECT addr1 + 
                                CASE WHEN LEN(addr2) > 0        THEN ', ' + TRIM(addr2)         ELSE '' END + 
                                CASE WHEN LEN(postalCode) > 0   THEN ', ' + TRIM(postalCode)    ELSE '' END + 
                                CASE WHEN LEN(city) > 0         THEN ' '  + TRIM(city)          ELSE '' END +
                                CASE WHEN LEN([state]) > 0        THEN ', ' + TRIM([state]) + ', '  ELSE ', ' END + country + '.'                                       
                                FROM @address
                                );
            END
            ELSE
            BEGIN
                SET @line1 = (SELECT addr1 FROM @address);
                SET @line2 = (SELECT 
                                CASE WHEN LEN(addr2) > 0        THEN TRIM(addr2) + ', '         ELSE '' END + 
                                CASE WHEN LEN(postalCode) > 0   THEN TRIM(postalCode)           ELSE '' END + 
                                CASE WHEN LEN(city) > 0         THEN ' '  + TRIM(city)          ELSE '' END +
                                CASE WHEN LEN([state]) > 0        THEN ', ' + TRIM([state]) + ', '  ELSE '' + ', ' END + country + '.'                                       
                                FROM @address
                                );
            END                      
        END

        -- SG
        IF @addrFormat = 2
        BEGIN
            IF @template = 1
            BEGIN
                SET @line1 = (SELECT addr1 + 
                                CASE WHEN LEN(addr2) > 0        THEN ', ' + TRIM(addr2)         ELSE '' END + ', ' + 
                                country +
                                CASE WHEN LEN(postalCode) > 0   THEN ' ' + TRIM(postalCode)     ELSE '' END + '.'                                     
                                FROM @address
                                );
            END
            ELSE
            BEGIN
                SET @line1 = (SELECT addr1 FROM @address);
                SET @line2 = (SELECT 
                                CASE WHEN LEN(addr2) > 0        THEN TRIM(addr2)                ELSE '' END + ', ' + 
                                country +
                                CASE WHEN LEN(postalCode) > 0   THEN ' ' + TRIM(postalCode)     ELSE '' END + '.'                                       
                                FROM @address
                                );
            END                      
        END

        -- US
        IF @addrFormat = 3
        BEGIN
            IF @template = 1
            BEGIN
                SET @line1 = (SELECT addr1 + 
                                CASE WHEN LEN(addr2) > 0        THEN ', ' + TRIM(addr2)            ELSE '' END + 
                                CASE WHEN LEN(city) > 0         THEN ', ' + TRIM(city)             ELSE '' END +
                                CASE WHEN LEN([state]) > 0      THEN ', ' + TRIM([state])          ELSE '' END + 
                                CASE WHEN LEN(postalCode) > 0   THEN ' '  + TRIM(postalCode) + ', '   ELSE ', ' END + country + '.'                                       
                                FROM @address
                                );
            END
            ELSE
            BEGIN
                SET @line1 = (SELECT addr1 FROM @address);
                SET @line2 = (SELECT 
                                CASE WHEN LEN(addr2) > 0        THEN TRIM(addr2) + ', '         ELSE '' END + 
                                CASE WHEN LEN(city) > 0         THEN TRIM(city)                 ELSE '' END +
                                CASE WHEN LEN([state]) > 0      THEN ', ' + TRIM([state])       ELSE '' END + 
                                CASE WHEN LEN(postalCode) > 0   THEN ' '  + TRIM(postalCode) + ', '   ELSE ', ' END + country + '.'                                        
                                FROM @address
                                );
            END                      
        END

        -- return result
        SELECT @id as id, companyName, addrName, @line1 as line1, @line2 as line2, contactNumber, faxNumber, email
        FROM @address

END

GO


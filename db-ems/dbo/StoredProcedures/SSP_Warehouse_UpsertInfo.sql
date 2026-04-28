-- =============================================
-- Author:		ZY Wong
-- Create date: 2023-10-27
-- Description:	Keep warehouse info and related table to be updated
-- Used By:		System Setting > Warehouse > Action Add/Update/Delete/Reactivate

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-09-29   3.1         WL Leong    Add event log
-- 2025-06-20   3.0         ZY Wong     Change sp name to upsert, change parameter to @json and handle insert & update action
-- 2024-11-26	2.0			WL Leong	Update column locNo 
-- 2023-09-22	1.0			ZY Wong		Initial version
-- =============================================
-- EXEC [dbo].[SSP_Warehouse_UpsertInfo] 
CREATE PROCEDURE [dbo].[SSP_Warehouse_UpsertInfo]
@Json VARCHAR(MAX)
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;

	BEGIN TRY
	
--DECLARE @Json VARCHAR(MAX) = N'{"warehouseList":{"companyId":"11","warehouseId":"2004","locNo":"MPH","label":"MPH Warehouse","addressLine1":"Miki address line 1","addressLine2":"line 2","city":"","state":"","postcode":"","country":"2","phone":"","fax":"","emailAddress":"","action":"UPDATE"}}';

		DECLARE @transId VARCHAR(50) = NEWID();

		INSERT INTO pro_eventLog(procedureName, transId,  userId, startDate, endDate, logStatus, jsonParam, returnMessage)		
		SELECT 'SSP_Warehouse_UpsertInfo', @transId, '',  getdate(), NULL, '_START_', @Json, NULL

		DECLARE @returnMessage VARCHAR(1000);

        DROP TABLE IF EXISTS #whInfo;

        SELECT companyId, ISNULL(warehouseId,0) as warehouseId, ISNULL(locNo,'') as locNo, ISNULL(label,'') as whlabel, ISNULL(addressLine1,'') as addressLine1, ISNULL(addressLine2,'') as addressLine2,
            ISNULL(city,'') as city, ISNULL(state,'') as state, ISNULL(postcode,'') as postcode, ISNULL(country,'') as country, ISNULL(phone,'') as phone, ISNULL(fax,'') as fax, ISNULL(emailAddress,'') as emailAddress, actionType
        INTO #whInfo
        FROM OPENJSON(@Json, '$.warehouseList') 
   			WITH (
                companyId INT               N'$.companyId',
                warehouseId INT             N'$.warehouseId',
                locNo VARCHAR(20)           N'$.locNo',
                label VARCHAR(20)           N'$.label',
                addressLine1 VARCHAR(255)   N'$.addressLine1',
                addressLine2 VARCHAR(255)   N'$.addressLine2',
                city VARCHAR(50)            N'$.city',
                state VARCHAR(50)           N'$.state',
                postcode VARCHAR(10)        N'$.postcode',
                country INT                 N'$.country',
                phone VARCHAR(20)           N'$.phone',
                fax VARCHAR(20)             N'$.fax',
                emailAddress VARCHAR(100)   N'$.emailAddress',
                actionType VARCHAR(20)      N'$.action'
                )

        DECLARE @actionType VARCHAR(20), @companyId INT, @warehouseId INT, @locNo VARCHAR(20), @label VARCHAR(20);

        SELECT @actionType = actionType, @companyId = companyId, @warehouseId = warehouseId, @locNo = locNo, @label = whlabel
        FROM #whInfo

        IF ISNULL(@actionType,'') = '' 
        BEGIN
            SET @returnMessage = '[System Error] Action is required.';
            THROW 60000, @returnMessage, 1;
        END

        IF @actionType IN ('ADD')
        BEGIN
             IF @locNo = ''
             BEGIN
                SET @returnMessage = 'Loc No is required.';
                THROW 60000, @returnMessage, 1;
             END

             -- check locNo existed in same company
             IF (SELECT COUNT(1) FROM md_Warehouse WHERE companyId = @companyId AND locNo = @locNo AND (@warehouseId = 0 OR warehouseId <> @warehouseId) ) > 0
             BEGIN
                SET @returnMessage = ('Loc No ' + @locNo + ' already exists in the system.');
                THROW 60000, @returnMessage, 1;
             END

        END

        IF @actionType IN ('ADD','UPDATE')
        BEGIN

             IF @label = ''
             BEGIN
                SET @returnMessage = 'Label is required.';
                THROW 60000, @returnMessage, 1;
             END

             -- check label existed in same company
             IF (SELECT COUNT(1) FROM md_Warehouse WHERE companyId = @companyId AND label = @label AND (@warehouseId = 0 OR warehouseId <> @warehouseId) ) > 0
             BEGIN
                SET @returnMessage = ('Label ' + @label + ' already exists in the system.');
                THROW 60000, @returnMessage, 1;
             END

        END

        IF @actionType IN ('UPDATE','DELETE','REACTIVATE')
        BEGIN
            IF @warehouseId = 0
            BEGIN
                SET @returnMessage = '[System Error] WarehouseId is required.';
                THROW 60000, @returnMessage, 1;
            END
        END

        IF @actionType = 'DELETE'
        BEGIN
            DECLARE @whQty INT;
        
            SET @whQty = (SELECT COUNT(1) 
                            FROM inventoryBalanceWH 
                            WHERE warehouseId = @warehouseId 
                            AND balanceQty > 0);

            IF @whQty > 0
            BEGIN
                SET @returnMessage = 'Warehouse still have stock, please transfer/clean up the stock to proceed.';
                THROW 60000, @returnMessage, 1;
            END
        END


        BEGIN TRANSACTION
            IF @actionType = 'ADD'
            BEGIN
                INSERT INTO md_Warehouse (companyId, locNo, label, address, addressLine2, city, state, postcode, countryId, phone, fax, emailAddress, status, createdDateTime)
                SELECT companyId, locNo, whlabel, addressLine1, addressLine2, city, state, postcode, country, phone, fax, emailAddress, 1 as status, GETDATE()
                FROM #whInfo

                SET @returnMessage = 'added.'
            END

            IF @actionType = 'UPDATE'
            BEGIN
                UPDATE w SET
                    label = wh.whlabel,
                    address = wh.addressLine1,
                    addressLine2 = wh.addressLine2,
                    city = wh.city,
                    state = wh.state,
                    postcode = wh.postcode,
                    countryId = wh.country,
                    phone = wh.phone,
                    fax = wh.fax,
                    emailAddress = wh.emailAddress
                FROM md_Warehouse w
                    INNER JOIN #whInfo wh
                        ON w.warehouseId = wh.warehouseId

                -- update shipToDestination for internal customer warehouse
                UPDATE std SET
			        shipToLabel = wh.whlabel,
			        shipToAddressLine1 = wh.addressLine1,
			        shipToAddressLine2 = wh.addressLine2,
			        shipToCity = wh.city,
			        shipToState = wh.state,
			        shipToPostCode = wh.postcode,
			        country = wh.country,
			        shipToContactNumber = wh.phone,
			        shipToFaxNumber = wh.fax,
			        shipToEmail = wh.emailAddress
		        FROM md_ShipToDestination std
                    INNER JOIN #whInfo wh
		                ON std.warehouseId = wh.warehouseId

                SET @returnMessage = 'updated.'
            END

            IF @actionType = 'DELETE'
            BEGIN
                UPDATE md_Warehouse SET
                    status = 0
                WHERE warehouseId = @warehouseId

                SET @returnMessage = 'deleted.'
            END

            IF @actionType = 'REACTIVATE'
            BEGIN
                UPDATE md_Warehouse SET
                    status = 1
                WHERE warehouseId = @warehouseId

                SET @returnMessage = 're-activated.'
            END

        COMMIT TRANSACTION

        SET @returnMessage = 'Warehouse info successfully ' + @returnMessage;

		SELECT '_SUCCESS_' as status, @returnMessage as returnMessage

		RETURN 0

	END TRY

	BEGIN CATCH	
	
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 

        IF @returnMessage IS NULL
            SET @returnMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE();

		SELECT '_FAILURE_' as status, @returnMessage as returnMessage

        RETURN -1

	END CATCH
END

GO


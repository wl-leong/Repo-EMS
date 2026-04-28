-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-06-21
-- Description:	Add/Update customer shipto info
-- Used By:		Customer Module -> Customer ShipTo

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-07-02   1.1         ZY Wong     Add validation for system error
-- 2024-06-21	1.0			ZY Wong		Initial version
-- =============================================

CREATE PROCEDURE [dbo].[SSP_CustomerShipTo_UpsertInfo]
@Json VARCHAR(MAX),
@userId INT 
AS
BEGIN
SET NOCOUNT ON
SET XACT_ABORT ON
    BEGIN TRY
	    BEGIN TRANSACTION

   --     DECLARE @Json VARCHAR(MAX) = 
			--N'{"shipToList":[{
			--	"companyId":"4",
			--	"shipToId":1033,
			--	"customerId":"29",
   --             "warehouseId":1027,
			--	"addrType":"ST",
   --             "vdc":"MPH WAREHOUSE",
			--	"shipToName":"MPH WAREHOUSE",
			--	"shipToLabel":"",
			--	"pod":"",
			--	"address1":"",
   --             "address2":"",
   --             "city":"",
   --             "state":"",
   --             "postcode":"",
   --             "country":"",
   --             "email":"",
   --             "contactNumber":"",
   --             "faxNumber":"",
			--	"action":"Update"
			--	}]}',
			--@userId INT = 1;

		DECLARE @ErrMessage VARCHAR(MAX);

		DROP TABLE IF EXISTS #stList;

		SELECT ISNULL(shipToId,0) as shipToId, companyId, customerId, ISNULL(warehouseId,0) as warehouseId, addrType, locNo, shipToName, shipToLabel, pod, address1, address2, city, 
            [state], postcode, country, email, contactNumber, faxNumber, actionType
		INTO #stList
		FROM  OPENJSON(@Json, '$.shipToList') 
   			WITH (
                shipToId BIGINT			        N'$.shipToId',
				companyId INT					N'$.companyId',
				customerId INT					N'$.customerId',
				warehouseId INT                 N'$.warehouseId',
				addrType VARCHAR(20)			N'$.addrType',
				locNo VARCHAR(20)			    N'$.vdc',
                shipToName VARCHAR(100)			N'$.shipToName',
                shipToLabel VARCHAR(50)			N'$.shipToLabel',
                pod VARCHAR(50)			        N'$.pod',
                address1 VARCHAR(200)			N'$.address1',
                address2 VARCHAR(200)			N'$.address2',
                city VARCHAR(50)			    N'$.city',
                [state] VARCHAR(50)			    N'$.state',
                postcode VARCHAR(10)			N'$.postcode',
                country INT                     N'$.country',
                email VARCHAR(100)			    N'$.email',
                contactNumber VARCHAR(20)		N'$.contactNumber',
                faxNumber VARCHAR(20)			N'$.faxNumber',
				actionType VARCHAR(50)			N'$.action'
			)

		DECLARE @actionType VARCHAR(50), @warehouseId INT, @shipToId BIGINT, @customerId INT, @companyId INT;

		SELECT @actionType = actionType, @warehouseId = warehouseId, @shipToId = shipToId, @customerId = customerId, @companyId = companyId
		FROM #stList

        IF ISNULL(@actionType,'') = '' 
        BEGIN
            SET @ErrMessage = '[System Error] Action is required.';
            THROW 60000, @ErrMessage, 1;
        END

        IF ISNULL(@customerId,0) = 0 
        BEGIN
            SET @ErrMessage = '[System Error] Customer Id is required.';
            THROW 60000, @ErrMessage, 1;
        END

        IF ISNULL(@companyId,0) = 0 
        BEGIN
            SET @ErrMessage = '[System Error] Company Id is required.';
            THROW 60000, @ErrMessage, 1;
        END

        IF ISNULL(@userId,0) = 0 
        BEGIN
            SET @ErrMessage = '[System Error] User Id is required.';
            THROW 60000, @ErrMessage, 1;
        END

        IF @actionType IN ('Add','Update') 
        BEGIN
            --validate similar compulsory field
            IF (SELECT COUNT(1) FROM #stList WHERE ISNULL(addrType,'') = '' OR ISNULL(locNo,'') = '' OR ISNULL(shipToName,'') = '') > 0
            BEGIN
                SET @ErrMessage = 'AddrType/ VDC/ ShipTo Name are compulsory.';
                THROW 60000, @ErrMessage, 1;
            END

            --validate external compulsory field
            IF (SELECT COUNT(1) FROM #stList WHERE warehouseId = 0 AND (ISNULL(address1,'') = '' OR ISNULL(address2,'') = '' OR ISNULL(city,'') = ''
                    OR ISNULL([state],'') = '' OR ISNULL(postcode,'') = '' OR ISNULL(country,0) = 0)) > 0
            BEGIN
                SET @ErrMessage = 'Address 1/ Address 2/ City/ State/ PostCode/ Country are compulsory.';
                THROW 60000, @ErrMessage, 1;
            END

        END

        IF @actionType = 'Add'
        BEGIN

            DECLARE @newShipTo TABLE (shipToId BIGINT);
            DECLARE @newShipToId BIGINT;

            -- check vdc exists
            DROP TABLE IF EXISTS #checkVdcExists;

            SELECT l.locNo
            INTO #checkVdcExists
            FROM #stList l
                INNER JOIN md_shipToDestination st
                    ON l.locNo = st.locNo
                    AND l.customerId = st.customerId
                    AND l.companyId = st.companyId

            IF (SELECT COUNT(1) FROM #checkVdcExists) > 0
            BEGIN
                SET @ErrMessage = (SELECT 'VDC ' + locNo  + ' already exists in the system.' FROM #checkVdcExists);
                THROW 60000, @ErrMessage, 1;
            END

            -- add internal customer shipto
            IF @warehouseId <> 0
            BEGIN

                -- check warehouseid exists;
                IF (SELECT COUNT(1) FROM md_shipToDestination WHERE warehouseId = @warehouseId AND customerId = @customerId) > 0
                BEGIN
                    SET @ErrMessage = 'Selected internal warehouse already exists in the system.';
                    THROW 60000, @ErrMessage, 1;
                END

                DROP TABLE IF EXISTS #internalAddr;

                SELECT l.companyId, l.customerId, l.warehouseId, l.addrType, l.locNo, l.shipToName, wh.[label] as shipToLabel, l.pod, wh.[address] as address1, 
                    wh.addressLine2 as address2, wh.city, wh.[state], wh.postcode, wh.countryId as country, wh.emailAddress as email, wh.phone as contactNumber, wh.fax as faxNumber
                INTO #internalAddr
                FROM #stList l
                    INNER JOIN md_Warehouse wh
                        ON l.warehouseId = wh.warehouseId
                        AND wh.[status] = 1
                WHERE l.warehouseId = @warehouseId

                IF (SELECT COUNT(1) FROM #internalAddr) = 0
                BEGIN
                    SET @ErrMessage = 'Selected internal warehouse not found in the system.';
                    THROW 60000, @ErrMessage, 1;
                END              

                INSERT INTO md_shipToDestination (companyId, customerId, warehouseId, addrType, locNo, shipToName, shipToLabel, shipToAddressLine1, shipToAddressLine2, shipToCity, 
                    shipToState, shipToPostCode, country, shipToEmail, shipToContactNumber, shipToFaxNumber, pod, createDateTime)
                OUTPUT INSERTED.shipToId
                INTO @newShipTo
                SELECT companyId, customerId, warehouseId, addrType, locNo, shipToName, shipToLabel, address1, address2, city, 
                    [state], postcode, country, email, contactNumber, faxNumber, pod, GETDATE()
                FROM #internalAddr

            END
            ELSE
            -- add customer shipto
            BEGIN
                INSERT INTO md_shipToDestination (companyId, customerId, warehouseId, addrType, locNo, shipToName, shipToLabel, shipToAddressLine1, shipToAddressLine2, shipToCity, 
                    shipToState, shipToPostCode, country, shipToEmail, shipToContactNumber, shipToFaxNumber, pod, createDateTime)
                OUTPUT INSERTED.shipToId
                INTO @newShipTo
                SELECT companyId, customerId, warehouseId, addrType, locNo, shipToName, shipToLabel, address1, address2, city, 
                    [state], postcode, country, email, contactNumber, faxNumber, pod, GETDATE()
                FROM #stList

            END

            SET @newShipToId = (SELECT shipToId FROM @newShipTo);

            IF @newShipToId IS NULL
            BEGIN
                SET @ErrMessage = 'ShipTo Id encounter creation problem.';
                THROW 60000, @ErrMessage, 1;
            END

            SET @ErrMessage = 'created.';

        END

        IF @actionType = 'Update'
        BEGIN
            -- check shipToId
            IF (SELECT COUNT(1) FROM md_shipToDestination WHERE shipToId = @shipToId) = 0
            BEGIN
                SET @ErrMessage = 'ShipTo record not found in the system.';
                THROW 60000, @ErrMessage, 1;
            END

            -- check vdc exists
            DROP TABLE IF EXISTS #checkVdcExists2;

            SELECT l.locNo
            INTO #checkVdcExists2
            FROM #stList l
                INNER JOIN md_shipToDestination st
                    ON l.locNo = st.locNo
                    AND l.customerId = st.customerId
                    AND l.companyId = st.companyId
            WHERE l.shipToId <> st.shipToId  --except own record

            IF (SELECT COUNT(1) FROM #checkVdcExists2) > 0
            BEGIN
                SET @ErrMessage = (SELECT 'VDC ' + locNo  + ' already exists in the system.' FROM #checkVdcExists2);
                THROW 60000, @ErrMessage, 1;
            END

            -- update internal customer shipto
            IF @warehouseId <> 0
            BEGIN
                DROP TABLE IF EXISTS #internalAddr2;

                SELECT l.shipToId, l.addrType, l.locNo, l.shipToName, wh.[label] as shipToLabel, l.pod, wh.[address] as address1, 
                    wh.addressLine2 as address2, wh.city, wh.[state], wh.postcode, wh.countryId as country, wh.emailAddress as email, wh.phone as contactNumber, wh.fax as faxNumber
                INTO #internalAddr2
                FROM #stList l
                    INNER JOIN md_Warehouse wh
                        ON l.warehouseId = wh.warehouseId
                        AND wh.[status] = 1
                WHERE l.warehouseId = @warehouseId

                IF (SELECT COUNT(1) FROM #internalAddr2) = 0
                BEGIN
                    SET @ErrMessage = 'Selected internal warehouse not found in the system.';
                    THROW 60000, @ErrMessage, 1;
                END

                UPDATE st SET
                    addrType = l.addrType,
                    locNo = l.locNo,
                    shipToName = l.shipToName,
                    shipToLabel = l.shipToLabel,
                    shipToAddressLine1 = l.address1, 
                    shipToAddressLine2 = l.address2, 
                    shipToCity = l.city, 
                    shipToState = l.[state], 
                    shipToPostCode = l.postcode, 
                    country = l.country, 
                    shipToEmail = l.email, 
                    shipToContactNumber = l.contactNumber, 
                    shipToFaxNumber = l.faxNumber,
                    pod = l.pod,
                    updateDate = GETDATE(),
                    updateBy = @userId
                FROM #internalAddr2 l
                    INNER JOIN md_shipToDestination st
                        ON l.shipToId = st.shipToId

            END
            ELSE
            --update customer shipto
            BEGIN

                UPDATE st SET
                    addrType = l.addrType,
                    locNo = l.locNo,
                    shipToName = l.shipToName,
                    shipToLabel = l.shipToLabel,
                    shipToAddressLine1 = l.address1, 
                    shipToAddressLine2 = l.address2, 
                    shipToCity = l.city, 
                    shipToState = l.[state], 
                    shipToPostCode = l.postcode, 
                    country = l.country, 
                    shipToEmail = l.email, 
                    shipToContactNumber = l.contactNumber, 
                    shipToFaxNumber = l.faxNumber,
                    pod = l.pod,
                    updateDate = GETDATE(),
                    updateBy = @userId
                FROM #stList l
                    INNER JOIN md_shipToDestination st
                        ON l.shipToId = st.shipToId

            END

            SET @ErrMessage = 'updated.';

        END

        SET @ErrMessage = 'Customer ShipTo info successfully ' + @ErrMessage;
        
		COMMIT TRANSACTION

        SELECT '_SUCCESS_' as status, @ErrMessage AS returnMessage

        RETURN 0
	END TRY

	BEGIN CATCH	
	
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 

        IF @ErrMessage IS NULL
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE();
 
		SELECT
			'_FAILURE_' as status, @ErrMessage as returnMessage

        RETURN -1
	END CATCH
END

GO


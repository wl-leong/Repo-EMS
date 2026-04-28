-- =============================================
-- Author:		WL Leong
-- Create date: 2024-04-25
-- Used By:	    EMS -> Shipping Module -> Shipping Document

-- Description : Only need to show those not yet _INV_

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-06-17   3.0         ZY Wong     Add search for lrName, invoiceId, soName
-- 2025-06-16   2.0         ZY Wong     Add sorting column
-- 2024-04-25	1.0			WL Leong	Initial
-- ==========================================================================================
/**
EXEC SSP_Shipping_ShipmentDocumentListing
N'{"list":[{"companyId":4,"customerId":29,"shipStartDate":"2025-05-17","shipEndDate":"2025-06-16","rowStart":1,"pageRow":10, "sortBy":6}]}'

select * from shipmentHeader
select * from md_customer where customerId = 33
**/
 
CREATE PROCEDURE [dbo].[SSP_Shipping_ShipmentDocumentListing]
@json NVARCHAR(MAX)
AS
BEGIN 
    /** sortBy
        1 = order by customerName  
        2 = order by lrName 
        3 = order by PL 
        4 = order by shipmentDate 
        5 = order by shipStatus
        6 = order by soName
        7 = order by customerPO
        8 = order by pod
        9 = order by containerType
        10 = order by containerNo
        11 = order by ETD
        12 = order by invoiceId
    **/

	SET NOCOUNT ON;
	SET XACT_ABORT ON;

        DECLARE @companyId INT, @customerId INT, @shipStartDate DATE, @shipEndDate DATE, @rowStart INT, @pageRow INT, @sortBy INT, @sortDirection VARCHAR(10), @search VARCHAR(100);
        DECLARE @sortOrder VARCHAR(3);

		-- Read json content
		DROP TABLE IF EXISTS #list;

		SELECT companyId, customerId, shipStartDate, shipEndDate, rowStart, pageRow, sortBy, sortDirection, search
		INTO #list
		FROM  OPENJSON(@json, '$.list') 
   			WITH (
				companyId INT				N'$.companyId',
                customerId INT				N'$.customerId',
                shipStartDate DATE			N'$.shipStartDate',
                shipEndDate DATE			N'$.shipEndDate',
                rowStart INT				N'$.rowStart',
                pageRow INT					N'$.pageRow',
				sortBy INT					N'$.sortBy',
				sortDirection VARCHAR(20)	N'$.sortDirection',
				search VARCHAR(100)			N'$.search'
			)

        SELECT @companyId = companyId, @customerId = customerId, @shipStartDate = shipStartDate, @shipEndDate = shipEndDate, @rowStart = rowStart, @pageRow = pageRow
			, @sortBy = sortBy, @sortDirection = sortDirection, @search = search
        FROM #list
        
        IF @customerId = 0
        BEGIN
            SET @customerId = NULL
        END

        IF ISNULL(@sortBy,0) = 0
        BEGIN
            SET @sortBy = 1
        END

        IF ISNULL(@sortDirection,'') = ''
        BEGIN
            SET @sortDirection = 'DESC'
        END

        IF @sortDirection = 'DESC'
        BEGIN
            SET @sortOrder = CAST(@sortBy as VARCHAR) + 'D'
        END
        ELSE
        BEGIN
            SET @sortOrder = CAST(@sortBy as VARCHAR) + 'A'
        END

        IF @search = ''
        BEGIN
            SET @search = NULL
        END
        
        DROP TABLE IF EXISTS #search;
        CREATE TABLE #search (shipmentId BIGINT);

        DROP TABLE IF EXISTS #shipmentHeader;
        CREATE TABLE #shipmentHeader (shipmentId BIGINT, lrHeaderId BIGINT, customerId INT, lrName VARCHAR(50), PL VARCHAR(50), shipId VARCHAR(30), shipmentDate DATETIME, 
            shipmentStatus INT, soName VARCHAR(50), customerPO VARCHAR(50), pol VARCHAR(100), pod VARCHAR(100), invoiceId VARCHAR(50),
            containerTypeId INT, containerNo VARCHAR(100), ETD DATE, shipmentWeight DECIMAL(18,4), bolTotalShipmentWeight DECIMAL(18,4), apiStatus VARCHAR(10));

        IF @search IS NOT NULL
		BEGIN
            INSERT INTO #search(shipmentId)
			SELECT DISTINCT shipmentId
			FROM shipmentHeader
			WHERE companyId = @companyId
				AND lrName LIKE '%' + @search + '%'
                AND apiStatus <> '_INV_'

            INSERT INTO #search(shipmentId)
			SELECT DISTINCT shipmentId
			FROM shipmentHeader
			WHERE companyId = @companyId
				AND invoiceId LIKE '%' + @search + '%'
                AND apiStatus <> '_INV_'

            INSERT INTO #search(shipmentId)
			SELECT DISTINCT shipmentId
			FROM shipmentHeader
			WHERE companyId = @companyId
				AND soName LIKE '%' + @search + '%'
                AND apiStatus <> '_INV_'

            INSERT INTO #shipmentHeader (shipmentId, lrHeaderId,  customerId, lrName, PL, shipId, shipmentDate, shipmentStatus, soName, customerPO, pol, pod, invoiceId,
                containerTypeId, containerNo, ETD, shipmentWeight, bolTotalShipmentWeight, apiStatus)
            SELECT DISTINCT l.shipmentId, lrHeaderId,  customerId, lrName, BOL as PL, shipId, shipmentDate, shipmentStatus, soName, customerPO, pol, pod, invoiceId,
                containerTypeId, containerNo, ETD, shipmentWeight, bolTotalShipmentWeight, apiStatus
            FROM shipmentHeader l
                INNER JOIN #search s
                    ON l.shipmentId = s.shipmentId

        END
        ELSE
        BEGIN

            INSERT INTO #shipmentHeader (shipmentId, lrHeaderId,  customerId, lrName, PL, shipId, shipmentDate, shipmentStatus, soName, customerPO, pol, pod, invoiceId,
                containerTypeId, containerNo, ETD, shipmentWeight, bolTotalShipmentWeight, apiStatus)
            SELECT shipmentId, lrHeaderId,  customerId, lrName, BOL as PL, shipId, shipmentDate, shipmentStatus, soName, customerPO, pol, pod, invoiceId,
                containerTypeId, containerNo, ETD, shipmentWeight, bolTotalShipmentWeight, apiStatus
            FROM shipmentHeader  
            WHERE companyId = @companyId
			    AND CONVERT(date, shipmentDate) BETWEEN @shipStartDate AND @shipEndDate
                AND (customerId = @customerId  OR @customerId IS NULL)
                AND apiStatus <> '_INV_'

        END

        DROP TABLE IF EXISTS #shipment;
 
        SELECT shipmentId, lrHeaderId, cs.customerShortCode as customerName, lrName, PL, shipId, shipmentDate, shipmentStatus, soName, customerPO, pol, pod, invoiceId, 
            containerTypeId, containerNo, ETD, shipmentWeight, bolTotalShipmentWeight, apiStatus, 0 as totalRecord
        INTO #shipment
        FROM #shipmentHeader sh
            INNER JOIN md_customer cs
                ON sh.customerId = cs.customerId
 
        UPDATE #shipment SET
            totalRecord = totalrow
        FROM (SELECT COUNT(DISTINCT shipmentId) as totalrow FROM #shipment) g

        ALTER TABLE #shipment ADD shipStatus VARCHAR(50);
        ALTER TABLE #shipment ADD containerType VARCHAR(50);

        UPDATE #shipment SET 
            shipStatus = st.categoryName
        FROM md_masterCategory st
        WHERE #shipment.shipmentStatus = st.categoryId

        UPDATE #shipment SET
            containerType = ctype.categoryName
        FROM md_masterCategory ctype
        WHERE #shipment.containerTypeId = ctype.categoryId

        DROP TABLE IF EXISTS #sortingListing;

        SELECT shipmentId, lrHeaderId, invoiceId, customerName, lrName, PL, shipId, CAST(shipmentDate as DATE) as shipmentDate, soName, customerPO, shipStatus, pol, pod, containerType,
            containerNo, ETD, shipmentWeight, bolTotalShipmentWeight, apiStatus, totalRecord,
            ROW_NUMBER() OVER(ORDER BY 
                CASE @sortOrder WHEN '1D' THEN customerName END DESC,
                CASE @sortOrder WHEN '1A' THEN customerName END ASC,
                CASE @sortOrder WHEN '2D' THEN lrName END DESC,
                CASE @sortOrder WHEN '2A' THEN lrName END ASC,
                CASE @sortOrder WHEN '3D' THEN PL END DESC,
                CASE @sortOrder WHEN '3A' THEN PL END ASC,            
                CASE @sortOrder WHEN '4D' THEN CAST(shipmentDate as DATE) END DESC,
                CASE @sortOrder WHEN '4A' THEN CAST(shipmentDate as DATE) END ASC ,
                CASE @sortOrder WHEN '5D' THEN shipStatus END DESC,
                CASE @sortOrder WHEN '5A' THEN shipStatus END ASC,
                CASE @sortOrder WHEN '6D' THEN soName END DESC,
                CASE @sortOrder WHEN '6A' THEN soName END ASC,
                CASE @sortOrder WHEN '7D' THEN customerPO END DESC,
                CASE @sortOrder WHEN '7A' THEN customerPO END ASC,
                CASE @sortOrder WHEN '8D' THEN pod END DESC,
                CASE @sortOrder WHEN '8A' THEN pod END ASC,
                CASE @sortOrder WHEN '9D' THEN containerType END DESC,
                CASE @sortOrder WHEN '9A' THEN containerType END ASC,
                CASE @sortOrder WHEN '10D' THEN containerNo END DESC,
                CASE @sortOrder WHEN '10A' THEN containerNo END ASC,
                CASE @sortOrder WHEN '11D' THEN ETD END DESC,
                CASE @sortOrder WHEN '11A' THEN ETD END ASC,
                CASE @sortOrder WHEN '12D' THEN invoiceId END DESC,
                CASE @sortOrder WHEN '12A' THEN invoiceId END ASC
                 ) as rowNo 
        INTO #sortingListing
        FROM #shipment 

        SELECT shipmentId, lrHeaderId, invoiceId, customerName, lrName, PL, shipId, shipmentDate, soName, customerPO, shipStatus, pol, pod, containerType,
            containerNo, ETD, shipmentWeight, bolTotalShipmentWeight, apiStatus, rowNo, totalRecord
        FROM #sortingListing
        WHERE rowNo >= @rowStart 
            AND rowNo <=  (@rowStart-1) + @pageRow
        ORDER BY rowNo

END

GO


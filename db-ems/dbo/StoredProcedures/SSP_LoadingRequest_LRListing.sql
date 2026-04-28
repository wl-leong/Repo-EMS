-- =============================================
-- Author:		WL Leong
-- Create date: 2023-12-10 
-- Used By:	    EMS -> LR Module -> LR Listing 

-- Description : Load Request for factory, so they can prepare packing list for container loading

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2026-04-07   9.0         ZY Wong     Ignore cancelled container
-- 2025-08-18   8.0         ZY Wong     Add companyId filter when search forwarderBookingNo
-- 2025-06-16   7.0         ZY Wong     Add more sorting column
-- 2025-06-05   6.0         WL Leong	add search for booking no, thirdparty po
-- 2025-05-06   5.2         WL Leong	soName, customerPo varchar(500)
-- 2025-05-05   5.1         WL Leong	Search using LR/SO/BookingNo
-- 2025-05-05   5.0         WL Leong	If soHeader got thirdParty information will display with customer
-- 2025-05-02   4.0         ZY Wong     Add new parameter @pageRow & @sortDirection, add table sorting and new column bookingNo
-- 2025-01-02	3.0			WL Leong	Use lrContainer table
-- 2024-10-25	2.0			WL Leong	Handle parameter = 0 for lrStatus
-- 2024-04-18	1.0			WL Leong	Initial
-- ==========================================================================================
-- EXEC [SSP_LoadingRequest_LRListing] 11, 0, '2026-04-07', '2026-07-06', 0 , 1, 50, 1, null, 'MPH-LR-26-00480'
 
CREATE PROCEDURE [dbo].[SSP_LoadingRequest_LRListing]
@companyId INT,
@supplierId INT,
@shipStartDate NVARCHAR(50),
@shipEndDate NVARCHAR(50),
@lrStatus INT,
@rowStart INT,
@pageRow INT,
@sortBy INT = 1,
@sortDirection VARCHAR(4) = 'DESC',
@search VARCHAR(50) = NULL
AS
BEGIN
    /** sortBy
        1 = order by lrName  
        2 = order by bookingNo 
        3 = order by customerName 
        4 = order by soName 
        5 = order by customerPo
        6 = order by earlyShipDate
        7 = order by containerType
        8 = order by containerSeq
        9 = order by uniqueSku
        10 = order by totalQty
    **/

	SET NOCOUNT ON;
	SET XACT_ABORT ON;


        --DECLARE @companyId INT = 11,
        --    @supplierId INT = 0,
        --    @shipStartDate NVARCHAR(50) = '2025-05-06',
        --    @shipEndDate NVARCHAR(50) = '2025-08-04',
        --    @lrStatus INT = 0,
        --    @rowStart INT = 1,
        --    @pageRow INT = 50,
        --    @sortBy INT = 1,
        --    @sortDirection VARCHAR(4) = 'DESC',
        --    @search VARCHAR(50) = NULL


        DECLARE @startDate DATE, @endDate DATE; 
        DECLARE @sortOrder VARCHAR(3);

        SET @startDate = CAST(REPLACE(@shipStartDate, '''', '') as DATE);
        SET @endDate = CAST(REPLACE(@shipEndDate, '''', '') as DATE);

        DECLARE @supplierName VARCHAR(50) = (SELECT supplierCompanyName FROM md_supplier WHERE supplierId = @supplierId);
	 

        IF @lrStatus = 0
        BEGIN
            SET @lrStatus = NULL
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
            SET @search = NULL
		
		DROP TABLE IF EXISTS #header;
		DROP TABLE IF EXISTS #search;
		CREATE TABLE #header(lrHeaderId BIGINT, supplierName VARCHAR(70), lrName VARCHAR(70), lrNote VARCHAR(500), lrStatus VARCHAR(50), lrStatusId INT)

		CREATE TABLE #search(lrHeaderId BIGINT)

        
		IF @search IS NOT NULL
		BEGIN
			INSERT INTO #search(lrHeaderId)
			SELECT DISTINCT lrHeaderId
			FROM lrHeader
			WHERE companyId = @companyId
				AND lrName LIKE '%' + @search + '%'

			INSERT INTO #search(lrHeaderId)
			SELECT DISTINCT lrHeaderId
			FROM lrLineItem li
				INNER JOIN soHeader s
					ON li.soHeaderId = s.soHeaderId
					AND s.companyId = @companyId
			WHERE s.soName LIKE '%' + @search + '%'

			INSERT INTO #search(lrHeaderId)
			SELECT DISTINCT lc.lrHeaderId
			FROM lrContainer lc
                INNER JOIN lrHeader lrh 
                    ON lc.lrHeaderId = lrh.lrHeaderId
                    AND lrh.companyId = @companyId
			WHERE lc.forwarderBookingNo LIKE '%' + @search + '%'
 
 			INSERT INTO #search(lrHeaderId)
			SELECT DISTINCT lrHeaderId
			FROM lrLineItem li
				INNER JOIN soHeader s
					ON li.soHeaderId = s.soHeaderId
					AND s.companyId = @companyId
			WHERE s.thirdPartyPO LIKE '%' + @search + '%'
 
			INSERT INTO #search(lrHeaderId)
			SELECT DISTINCT lrHeaderId
			FROM lrLineItem li
				INNER JOIN poHeader p
					ON li.poId = p.poId
					AND p.companyId = @companyId
			WHERE p.poName LIKE '%' + @search   + '%'

			INSERT INTO #header(lrHeaderId, supplierName, lrName, lrNote, lrStatus, lrStatusId)
			SELECT DISTINCT l.lrHeaderId, @supplierName as supplierName, l.lrName, l.lrNote,  mc.categoryName as status, l.lrStatus
			FROM lrHeader l 
				INNER JOIN #search s
					ON l.lrHeaderId = s.lrHeaderId
				INNER JOIN md_masterCategory mc
					ON l.lrStatus = mc.categoryId
			WHERE(lrStatus = @lrStatus OR @lrStatus IS NULL)

			SET @startDate = DATEADD(MONTH, -12, @startDate)
			SET @endDate = DATEADD(MONTH, 12, @endDate)
		END
		ELSE
		BEGIN
 
			INSERT INTO #header(lrHeaderId, supplierName, lrName, lrNote, lrStatus, lrStatusId)
			SELECT DISTINCT l.lrHeaderId, ISNULL(@supplierName, '') as supplierName, l.lrName, l.lrNote,  mc.categoryName as status, l.lrStatus
			FROM lrHeader l 				
                INNER JOIN md_masterCategory mc
					ON l.lrStatus = mc.categoryId
			WHERE l.companyId = @companyId
				AND (lrStatus = @lrStatus OR @lrStatus IS NULL)
		END
  
		DROP TABLE IF EXISTS #containerInfo;

		SELECT lr.lrHeaderId, supplierName, lr.lrName, ISNULL(lr.forwarderBookingNo,'') as bookingNo, lrNote, h.lrStatusId, lrStatus, lr.lrContainerId, lr.earlyShipDate, lr.lateShipDate, lr.containerTypeId, lr.containerSeq
		INTO #containerInfo
		FROM lrContainer lr
			INNER JOIN #header h
				ON lr.lrHeaderId = h.lrHeaderId
		WHERE lr.earlyShipDate >= @startDate 
            AND lr.lateShipDate <= @endDate
            AND lr.containerStatus <> 2130 

        DROP TABLE IF EXISTS #lineItem;

        SELECT l.lrHeaderId, l.lrName, l.bookingNo, lr.soHeaderId, 
            l.earlyShipDate, l.lateShipDate, l.containerTypeId, l.containerSeq, supplierSku, qty, l.lrStatusId, l.lrStatus, lr.itemStatus , lr.invId
        INTO #lineItem
        FROM #containerInfo l
            INNER JOIN lrLineItem lr 
                ON l.lrContainerId = lr.lrContainerId


        ALTER TABLE #lineItem ADD soName VARCHAR(100);
        ALTER TABLE #lineItem ADD customerPO VARCHAR(100);
        ALTER TABLE #lineItem ADD customerId INT;
        ALTER TABLE #lineItem ADD customerName VARCHAR(30);
		ALTER TABLE #lineItem ADD thirdParty VARCHAR(20);

        UPDATE #lineItem SET
            soName = s.soName,
            customerId = s.customerId,
            customerPO = s.customerPO,
			thirdparty = s.thirdParty
        FROM soHeader s
        WHERE #lineItem.soHeaderId = s.soHeaderId

        UPDATE #lineItem SET
            customerName = cs.customerShortCode + (CASE WHEN LEN(ISNULL(thirdParty, '')) = 0 THEN '' ELSE ' /' + thirdparty END)
        FROM md_customer cs
        WHERE #lineItem.customerId = cs.customerId  


		DROP TABLE IF EXISTS #warehouseBalance;

		SELECT invId, SUM(balanceQty) as invBalance
		INTO #warehouseBalance
		FROM inventoryBalanceWH 
		WHERE companyId = @companyId
		GROUP BY invId

		ALTER TABLE #lineItem ADD invBalance INT;

		UPDATE #lineItem SET
			invBalance = inv.invBalance
		FROM #warehouseBalance inv
		WHERE #lineItem.invId = inv.invId
 
        DROP TABLE IF EXISTS #listing;

        SELECT l.lrHeaderId, l.lrName, li.bookingNo, li.customerName, li.earlyShipDate,  li.lateShipDate, ctype.categoryName as containerType, li.containerSeq,
            COUNT(DISTINCT supplierSku) as UniqueSku, SUM(qty) as ttlLrQty, SUM(ISNULL(li.invBalance, 0)) as invBalance, li.lrStatus, li.itemStatus , l.lrStatusId
        INTO #listing
        FROM #header l
            INNER JOIN #lineItem li
                ON l.lrHeaderId = li.lrHeaderId
            INNER JOIN md_masterCategory ctype
                ON li.containerTypeId = ctype.categoryId
        GROUP BY l.lrHeaderId, l.lrName, li.bookingNo, li.customerName, li.earlyShipDate,  li.lateShipDate, ctype.categoryName ,  li.containerSeq, li.lrStatus, li.itemStatus, l.lrStatusId

		
        DROP TABLE IF EXISTS #soName;

        SELECT lrHeaderId, STRING_AGG(s.soName, ',') as soName
        INTO #soName
        FROM (
            SELECT DISTINCT lrHeaderId, soName 
            FROM #lineItem
            ) s
        GROUP BY lrHeaderId

        DROP TABLE IF EXISTS #customerPO;

        SELECT lrHeaderId, STRING_AGG(s.customerPO, ',') as customerPO
        INTO #customerPO
        FROM (
            SELECT DISTINCT lrHeaderId, customerPO 
            FROM #lineItem
            ) s
        GROUP BY lrHeaderId
 
		ALTER TABLE #listing ADD soName VARCHAR(500);
		ALTER TABLE #listing ADD customerPO VARCHAR(500);
 		ALTER TABLE #listing ADD totalRecord INT;
		
 
		UPDATE #listing SET
			customerPO = c.customerPO
		FROM #customerPO c
		WHERE #listing.lrHeaderId = c.lrHeaderId

		UPDATE #listing SET
			soName = c.soName
		FROM #soName c
		WHERE #listing.lrHeaderId = c.lrHeaderId

        UPDATE #listing SET
            totalRecord = totalrow
        FROM (SELECT COUNT(*) as totalrow FROM #listing) g

        DROP TABLE IF EXISTS #sortingListing;

        SELECT lrHeaderId, lrName, bookingNo, customerName, soName, customerPO, earlyShipDate, lateShipDate, containerType, containerSeq,
            uniqueSku, ttlLrQty as totallrQty,  invBalance, lrStatusId as lrStatus, lrstatus as status, totalRecord, 
            ROW_NUMBER() OVER(ORDER BY 
                CASE @sortOrder WHEN '1D' THEN lrName END DESC,
                CASE @sortOrder WHEN '1A' THEN lrName END ASC,
                CASE @sortOrder WHEN '2D' THEN bookingNo END DESC,
                CASE @sortOrder WHEN '2A' THEN bookingNo END ASC,
                CASE @sortOrder WHEN '3D' THEN customerName END DESC,
                CASE @sortOrder WHEN '3A' THEN customerName END ASC,            
                CASE @sortOrder WHEN '4D' THEN soName END DESC,
                CASE @sortOrder WHEN '4A' THEN soName END ASC ,
                CASE @sortOrder WHEN '5D' THEN customerPO END DESC,
                CASE @sortOrder WHEN '5A' THEN customerPO END ASC,
                CASE @sortOrder WHEN '6D' THEN earlyShipDate END DESC,
                CASE @sortOrder WHEN '6A' THEN earlyShipDate END ASC,
                CASE @sortOrder WHEN '7D' THEN containerType END DESC,
                CASE @sortOrder WHEN '7A' THEN containerType END ASC,
                CASE @sortOrder WHEN '8D' THEN containerSeq END DESC,
                CASE @sortOrder WHEN '8A' THEN containerSeq END ASC,
                CASE @sortOrder WHEN '9D' THEN uniqueSku END DESC,
                CASE @sortOrder WHEN '9A' THEN uniqueSku END ASC,
                CASE @sortOrder WHEN '10D' THEN ttlLrQty END DESC,
                CASE @sortOrder WHEN '10A' THEN ttlLrQty END ASC
                 ) as rowNo 
        INTO #sortingListing
        FROM #listing 
 
        SELECT lrHeaderId, lrName, bookingNo, customerName, soName, customerPO, earlyShipDate,  lateShipDate, 
			containerType, containerSeq, UniqueSku, totallrQty, invBalance, lrStatus, status, totalRecord, rowNo
        FROM #sortingListing
        WHERE rowNo >= @rowStart 
            AND rowNo <=  (@rowStart-1) + @pageRow
        ORDER BY rowNo

END

GO


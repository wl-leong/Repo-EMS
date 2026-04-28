-- =============================================
-- Author:		WL Leong
-- Create date: 2023-06-08
-- Used By:	    EMS -> SO Module -> Open SO

-- Description : All Sales Order still remain uncancel/close

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-09-01   7.0         WL Leong    Return isBell
-- 2025-04-01   6.0         WL Leong    Return totalRecord
-- 2025-03-04   5.0         ZY Wong     Filter companyId when using @searchInput
-- 2025-01-13   4.0         WL Leong	Ignore parameter for search criteria
-- 2024-10-30   3.0         ZY Wong     If search input not null ignore shipdate
-- 2024-06-19	2.0			WL Leong	Add in search input
-- 2024-05-15	1.0			WL Leong	Initial
-- ==========================================================================================
--EXEC SSP_SalesOrder_SelectSOListing 4, 29, '2024-01-10', '2025-12-01', '2025-01-01', '2025-12-30', null, 1106, 11, 10, 1, 'DESC', null, 18
--delete from actionNotification where sourceRecordId = 22966
--delete from notificationRecipient where  NotificationId = 2363
--select * from actionNotification where sourceRecordId = 22966
--select distinct sourceRecordId from actionNotification where sourceModule = 'SalesOrder' order by sourceRecordId
CREATE PROCEDURE [dbo].[SSP_SalesOrder_SelectSOListing]
@companyId INT,
@customerId INT = 0,
@startDate DATE,
@endDate DATE,
@startShipDate DATE,
@endShipDate DATE,
@pod VARCHAR(50),
@soStatus INT = 0,
@rowStart INT,
@pageRow INT,
@sortBy INT = 1,
@sortDirection VARCHAR(4) = 'DESC',
@searchInput VARCHAR(50),
@userId INT
AS
BEGIN
    /** sortBy
        1 = order by soName  
        2 = order by customerPO
        3 = order by soDate 
        4 = order by customer 
        5 = order by shipTo 
        6 = order by shipDate  
        7 = order by status
    **/
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY

        --DECLARE @companyId INT = 11, @customerId INT = 33, @startDate DATE = '2024-03-12', @endDate DATE = '2024-06-10', 
        --    @startShipDate DATE = '2024-06-10', @endShipDate DATE = '2024-09-08', @pod VARCHAR(50) = '', @soStatus INT = 0, 
        --    @rowStart INT = 1, @pageRow INT = 10, @sortBy INT = 0
        DECLARE @sortOrder VARCHAR(2), @CDCModule VARCHAR(50) = 'SalesOrder';
 
		IF @customerId = 0 
            SET @customerId = NULL

        IF @soStatus = 0
            SET @soStatus = NULL

        IF @pod = '0'  
            SET @pod = NULL

        IF @searchInput = ''
            SET @searchInput = NULL

        IF @sortDirection = 'DESC'
        BEGIN
            SET @sortOrder = CAST(@sortBy as VARCHAR) + 'D'
        END
        ELSE
        BEGIN
            SET @sortOrder = CAST(@sortBy as VARCHAR) + 'A'
        END

        DROP TABLE IF EXISTS #pod;

        SELECT DISTINCT st.shipToId, st.pod
        INTO #pod
        FROM md_shipToDestination st
        WHERE st.companyId =  @companyId
            AND (st.pod = @pod or @pod IS NULL)

        DROP TABLE IF EXISTS #soSearch;

        CREATE TABLE #soSearch(soHeaderId BIGINT)
        
        IF @searchInput IS NOT NULL
        BEGIN
			SET @searchInput = (SELECT LTRIM(RTRIM(@searchInput)));

            INSERT INTO #soSearch(soHeaderId)
            SELECT soHeaderId
            FROM soHeader
            WHERE soName LIKE '%' + @searchInput + '%'
                AND companyId = @companyId

            INSERT INTO #soSearch(soHeaderId)
            SELECT soHeaderId
            FROM soHeader
            WHERE customerPO LIKE '%' + @searchInput + '%'
                AND companyId = @companyId
 
        END
        ELSE
        BEGIN
            INSERT INTO #soSearch(soHeaderId)
            SELECT li.soHeaderId
            FROM soHeader li
                INNER JOIN #pod pd 
                    ON li.shipToId = pd.shipToId
            WHERE li.companyId = @companyId
                AND (li.soStatus = @soStatus OR @soStatus IS NULL) 
                AND (customerId = @customerId OR @customerId IS NULL)
                AND soDate BETWEEN @startDate AND @endDate
                AND earlyShipDate BETWEEN @startShipDate AND @endShipDate

        END 

        
        DROP TABLE IF EXISTS #soInfo;

        SELECT li.soHeaderId, customerId, soName, customerPO, soDate, earlyShipDate, li.shipToId, li.soStatus as soStatusId, mc.categoryName as soStatus, 0 as totalRecord
        INTO #soInfo
        FROM soHeader li
            INNER JOIN #soSearch so 
                ON li.soHeaderId = so.soHeaderId
            INNER JOIN md_MasterCategory mc
                ON soStatus = mc.categoryId
            INNER JOIN #pod pd 
                ON li.shipToId = pd.shipToId
        WHERE li.companyId = @companyId


        UPDATE #soInfo SET
            totalRecord = totalrow
        FROM (SELECT COUNT(DISTINCT soHeaderId) as totalrow FROM #soInfo) g

        DROP TABLE IF EXISTS #sortingListing;

        SELECT soHeaderId, cs.customerName, soName, customerPO, soDate, earlyShipDate as shipDate, st.shipToLabel, soStatusId, soStatus, 
            ROW_NUMBER() OVER(ORDER BY 
                CASE @sortOrder WHEN '1D' THEN soName END DESC,
                CASE @sortOrder WHEN'1A' THEN soName END ASC,
                CASE @sortOrder WHEN '2D' THEN customerPO END DESC,
                CASE @sortOrder WHEN'2A' THEN customerPO END ASC,
                CASE @sortOrder WHEN '3D' THEN soDate END DESC,
                CASE @sortOrder WHEN'3A' THEN soDate END ASC,
                CASE @sortOrder WHEN '4D' THEN cs.customerName END DESC,
                CASE @sortOrder WHEN'4A' THEN cs.customerName END ASC,            
                CASE @sortOrder WHEN '5D' THEN st.shipToLabel END DESC,
                CASE @sortOrder WHEN'5A' THEN st.shipToLabel END ASC,    
                CASE @sortOrder WHEN '6D' THEN earlyShipDate END DESC,
                CASE @sortOrder WHEN'6A' THEN earlyShipDate END ASC,   
                CASE @sortOrder WHEN '7D' THEN soStatus END DESC,
                CASE @sortOrder WHEN'7A' THEN soStatus END ASC        
                 ) as rowNo, totalRecord
        INTO #sortingListing
        FROM  #soInfo s
            INNER JOIN md_customer cs
                ON s.customerId = cs.customerId
            INNER JOIN md_shipToDestination st 
                ON s.shipToid = st.shipToId
 
       DROP TABLE IF EXISTS #isBell;

        SELECT DISTINCT sourceRecordId
		INTO #isBell
        FROM actionNotification ac
            INNER JOIN notificationRecipient n
                ON ac.actionNotificationID = n.notificationID
        WHERE corporateId = @companyId 
            AND sourceModule = @CDCModule
			AND n.userId = @userId
			AND isRead = 0

        SELECT soHeaderId, customerName, soName, customerPO, soDate, shipDate, shipToLabel, soStatusId, soStatus, rowNo, totalRecord , CASE WHEN lb.sourceRecordId IS NULL THEN 0 ELSE 1 END as isBellAlert
        FROM #sortingListing ls
			LEFT JOIN #isBell lb
				ON ls.soHeaderId = lb.sourceRecordId
        WHERE rowNo >= @rowStart AND rowNo <=  (@rowStart-1) + @pageRow
 
	END TRY

	BEGIN CATCH
 
 
		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as errorMessage

		RETURN -1
	END CATCH
END

GO


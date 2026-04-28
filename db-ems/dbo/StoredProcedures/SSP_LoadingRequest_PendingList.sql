-- =============================================
-- Author:		WL Leong
-- Create date: 2023-12-10
-- Used By:	    EMS -> LR Module -> Pending LR Listing 

-- Description : Load Request for factory, so they can prepare packing list for container loading

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-06-16   3.0         ZY Wong     Hardcode @pageRow = 9999
-- 2025-03-11   2.0         ZY Wong     Allow pass in [ALL] for @customerId, ignore @supplierId
-- 2024-04-18	1.0			WL Leong	Initial
-- ==========================================================================================
/**
EXEC SSP_LoadingRequest_PendingList
11, 0, 0, '2025-06-16', '2025-09-14', 0 , 1, 100
**/
--select * from temp  drop table temp
--select * from poHeader where customerId = 34
 
CREATE PROCEDURE [dbo].[SSP_LoadingRequest_PendingList]
@companyId INT,
@supplierId INT,
@customerId INT = 0,
@shipStartDate NVARCHAR(255),
@shipEndDate NVARCHAR(255),
@destination INT = 0,
@rowStart INT,
@pageRow INT
AS
BEGIN
    BEGIN TRY
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

        --declare @companyId INT = 11, @supplierId INT = 65, @customerId INT = 26, @shipStartDate NVARCHAR(255) = '2024-05-25', @shipEndDate NVARCHAR(255) = '2024-06-03',
        --    @destination INT = 0, @rowStart INT = 1, @pageRow INT = 10
        SET @pageRow = 9999;

        IF @customerId = 0
            SET @customerId = NULL
 
        IF @destination = 0
            SET @destination = NULL

 
        IF ISNULL(@customerId, 0) = 0
            SET @customerId = NULL

        DECLARE @startDate DATE, @endDate DATE 

        DROP TABLE IF EXISTS #pod;

        CREATE TABLE #pod  (shipToid INT)

        IF @destination IS NOT NULL
        BEGIN
            INSERT INTO #pod(shipToId)
            SELECT st.shipToId
            FROM md_shipToDestination st
            WHERE st.pod = @destination
                AND st.companyId = @companyId
        END
        ELSE
        BEGIN
            INSERT INTO #pod(shipToId)
            SELECT shipToId
            FROM md_shipToDestination
            WHERE companyId = @companyId
        END
 

        SET @startDate = CAST(REPLACE(@shipStartDate, '''', '') as DATE)
        SET @endDate = CAST(REPLACE(@shipEndDate, '''', '') as DATE)

       --SELECT @startDate a, @endDate b INTO temp
	    DROP TABLE IF EXISTS #order;
 
        SELECT p.poId, p.companyId, p.supplierId, p.poName, s.customerId, s.customerPO, poEarlyShipDate as earlyShipDate, poLateShipDate as lateShipDate, p.shipToId
        INTO #order
        FROM poHeader p
            INNER JOIN soHeader s
                ON p.poReferenceId = s.soName
            INNER JOIN #pod pd
                ON p.shipToId = pd.shipToId
        WHERE (s.customerId =  @customerId OR @customerId IS NULL)
            --AND p.supplierId = @supplierId
            AND poStatus IN (1077)  --released
            AND (poEarlyShipDate >= @startDate AND lateShipDate <= @endDate)
 
 
        DROP TABLE IF EXISTS #lrListing;
       
	    SELECT poDetailsId, p.poId, invId, supplierSkuId, supplierSku, merchantSku, poItemDesc, qty - lrQty as openLrQty, 
            odr.companyId, odr.supplierId, odr.poName, odr.customerPO, odr.earlyShipDate, odr.lateShipDate, odr.shipToId
        INTO #lrListing
        FROM poLineItem p
            INNER JOIN #order odr
                ON p.poId = odr.poId
        WHERE qty - lrQty > 0
            AND p.itemStatus IN (1077) -- released and approved PO
 
        DECLARE @totalRecord INT = (SELECT COUNT(1) FROM #lrListing);

        SELECT poDetailsId, poName, lateShipDate, portName as destination, supplierSku, openLrQty, RowNo, invId, @totalRecord as totalRecord
        FROM (
            SELECT poDetailsId, poName, lateShipDate as lateShipDate, p.portName, ls.supplierSku, openLrQty, ls.invId, ls.shipToId, 
                ROW_NUMBER() OVER(ORDER BY poDetailsId) as RowNo
            FROM #lrListing ls
                INNER JOIN md_shipToDestination d 
                    ON ls.shipToId = d.shipToId    
                INNER JOIN md_port p
                    ON d.pod = p.portId
        ) g 
        WHERE rowNo BETWEEN @rowStart AND @rowStart + @pageRow
        ORDER BY RowNo


	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 
 
		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as returnMessage

		RETURN -1
	END CATCH
END

GO


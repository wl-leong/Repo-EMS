-- =============================================
-- Author:		WL Leong
-- Create date: 2025-05-26
-- Used By:	    EMS -> Loading Request -> Loading Listing -> View

-- Description : 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-05-26	1.0			WL Leong 	Initial
-- ==========================================================================================
/**
EXEC SSP_LoadingRequest_SelectLoadingRequest 13, 1
**/

CREATE PROCEDURE [dbo].[SSP_LoadingRequest_SelectLoadingRequest]
@lrHeaderId BIGINT,
@containerSeq INT
AS
BEGIN
    SET NOCOUNT ON;
    
    --DECLARE @shipmentId BIGINT = 5

    DROP TABLE IF EXISTS #lrHeader;
	DROP TABLE IF EXISTS #container;

	SELECT lrHeaderId, companyId, supplierId, customerId, lrName, lrDate, lrRequestDate, lrNote,  
		CAST('' as varchar(50)) as requestor
	INTO #lrHeader
    FROM lrHeader  
    WHERE lrHeaderId =  @lrHeaderId
 


	UPDATE #lrHeader SEt
		requestor = s.customerShortCode
	FROM md_Customer s
	WHERE #lrHeader.customerId = s.customerId
		AND s.customerId <> 0

	UPDATE #lrHeader SEt
		requestor = s.supplierCompanyName
	FROM md_supplier s
	WHERE #lrHeader.supplierId = s.supplierId
		AND s.supplierId <> 0
 
	SELECT lrHeaderId, containerTypeId, containerSeq, earlyShipDate, lateShipDate, p.portId, p.portName, notes, cont.containerStatus, CAST('' as VARCHAR(20)) as lrStatus
	INTO #container
	FROM lrContainer cont
		LEFT JOIN md_port p
			ON cont.portId = p.portId
	WHERE lrHeaderId =  @lrHeaderId
		AND containerSeq = @containerSeq
		

	UPDATE #container SEt
		lrStatus = ct.categoryName
	FROM md_masterCategory ct
	WHERE #container.containerStatus = ct.categoryId            
 
    SELECT  lr.lrHeaderId, cont.containerSeq, companyId, requestor, lrName, lrDate, lrRequestDate,  lrStatus, containerTypeId, ct.categoryName as containerType,
		earlyShipDate, lateShipDate,  portId, portName, notes
    FROM #lrHeader lr
		INNER JOIN #container cont
			ON lr.lrHeaderId = cont.lrHeaderId
        INNER JOIN md_masterCategory ct
            ON  containerTypeId = ct.categoryId

 
    
END

GO


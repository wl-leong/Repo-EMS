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
EXEC SSP_Shipping_SelectShipmentFreight 5
**/

CREATE PROCEDURE [dbo].[SSP_LoadingRequest_SelectContainerInfo]
@lrHeaderId BIGINT,
@containerSeq INT
AS
BEGIN
    SET NOCOUNT ON;
    
    --DECLARE @shipmentId BIGINT = 5

    DROP TABLE IF EXISTS #container;

    SELECT  lrHeaderId, lrContainerId, containerSeq, containerNo, containerSealNo, containerMaxGross, containerTare, containerTypeId, 
       containerPullInDate, containerPullOutDate, cargoReadyDate
    INTO #container
    FROM lrContainer  
    WHERE lrHeaderId =  @lrHeaderId
		AND containerSeq = @containerSeq
		

    SELECT  lrHeaderId, lrContainerId, containerSeq, containerNo, containerSealNo, containerMaxGross, containerTare, containerTypeId, ct.categoryName as containerType,
       containerPullInDate, containerPullOutDate, cargoReadyDate
    FROM #container cont
        INNER JOIN md_masterCategory ct
            ON  containerTypeId = ct.categoryId
 
    
END

GO


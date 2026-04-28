-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-04-25
-- Used By:	    EMS -> LR Module -> LR Listing -> Export Loading Request (SSRS), Export Loading Planning (SSRS)
--
-- Description : 
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-11-18   11.0        ZY Wong     Fix large value to NVARCHAR(MAX)
-- 2025-08-22   10.0        ZY Wong     Add customerSku
-- 2025-08-14   9.0         ZY Wong     Remove cartonMaterial, cartonQty
-- 2025-05-30   8.0         ZY Wong     Harcode for customerId 12,13,14,22 to return carton material
-- 2025-05-29   7.0         ZY Wong     Remove shipToId, Add portId
-- 2025-05-06   6.0         ZY Wong     Add containerSealNo
-- 2025-03-25   5.0         WL Leong    use lrContainer and simply return
-- 2025-03-12   4.0         ZY Wong     Fix shipToId to POD, get real shipToId from soHeader
-- 2025-01-08   3.1         ZY Wong     Add thirdPartyPo info, rename variable
-- 2025-01-03   3.0         WL Leong    use lrContainer and simply return
-- 2024-11-01   2.0         ZY Wong     Add variable @isMarketing and return to result
-- 2024-04-25	1.0			ZY Wong 	Initial
-- ==========================================================================================
-- EXEC [SSP_LoadingRequest_SSRS_SelectLRItems] 11, 2972
CREATE PROCEDURE [dbo].[SSP_LoadingRequest_SSRS_SelectLRItems]
@companyId INT,
@lrHeaderId BIGINT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	
    --DECLARE @lrHeaderId BIGINT = 10337, @companyId INT = 11

    DECLARE @isMarketing INT = (SELECT isMarketing FROM md_Company WHERE companyId = @companyId);
    DECLARE @needCartonMaterial INT = 0, @customerId INT;

    IF @isMarketing = 0
    BEGIN
        SET @customerId = (SELECT customerId FROM lrHeader WHERE lrHeaderId = @lrHeaderId);
    END
    ELSE
    BEGIN
        SET @customerId = (SELECT customerId FROM soHeader WHERE soHeaderId IN (SELECT TOP 1 soHeaderId FROM lrLineItem WHERE lrHeaderId = @lrHeaderId));
    END

    -- if customer AIS, Komeri, Takeda, Yamazen show carton material
    IF @customerId IN (12,13,14,22)
    BEGIN
        SET @needCartonMaterial = 1;
    END

    DROP TABLE IF EXISTS #lrContainer;

    SELECT l.lrContainerId, l.lrName, containerSeq, containerNo, containerSealNo, portId, l.earlyShipDate, l.lateShipDate, containerTypeId,   
        ct.categoryName as containerType, CONVERT(NUMERIC(13,5), 0) as containerCbm, CONVERT(NUMERIC(13,5), 0) as containerWeight, CASE WHEN ISNULL(l.notes,'') = '' THEN NULL ELSE l.notes END as notes
    INTO #lrContainer
    FROM lrContainer l
            INNER JOIN md_MasterCategory ct
                ON l.containerTypeId = ct.categoryId
    WHERE containerStatus <> 2130
        AND lrHeaderId = @lrHeaderId 

	UPDATE #lrContainer SET
		containerCbm =  CONVERT(NUMERIC(13,5), REPLACE(cbm.attributeValue, ' m3', ''))
	FROM md_MasterCategoryAttribute cbm
    WHERE #lrContainer.containerTypeId = cbm.masterCategoryId
		AND cbm.attributeName = 'CBM'

	UPDATE #lrContainer SET
		containerWeight =  CONVERT(NUMERIC(13,5), REPLACE(wg.attributeValue, ' kgs', ''))
	FROM md_MasterCategoryAttribute wg
    WHERE #lrContainer.containerTypeId = wg.masterCategoryId
		AND wg.attributeName = 'Weight'


    DECLARE @summaryContainerNo NVARCHAR(MAX), @summaryContainerSeq NVARCHAR(MAX);

    SET @summaryContainerNo = (SELECT STRING_AGG(containerNo + ' | ' + containerSealNo,', ') 
                            FROM (SELECT DISTINCT ISNULL(containerNo,'') as containerNo, ISNULL(containerSealNo,'') as containerSealNo
                                    FROM #lrContainer
                                    WHERE ISNULL(containerNo,'') <> '' OR ISNULL(containerSealNo,'') <> '') g
                            );

    SET @summaryContainerSeq = (SELECT STRING_AGG(CONVERT(VARCHAR, containerSeq) ,', ') 
                            FROM (SELECT DISTINCT containerSeq
                                    FROM #lrContainer) g
                            );

	DROP TABLE IF EXISTS #lrList;

	SELECT lr.lrContainerId, lr.containerSeq, li.lrDetailsId, li.soHeaderId, li.soLineItemId, li.poId, li.poDetailsId, lr.portId, li.supplierSku, li.invId, li.qty,
        CASE WHEN @needCartonMaterial = 1 THEN li.qtyPerCarton ELSE '' END as qtyPerCarton
	INTO #lrList
	FROM #lrContainer lr
		INNER JOIN lrLineItem li
			ON lr.lrContainerId = li.lrContainerID
	WHERE itemStatus <> 2130

	ALTER TABLE #lrList ADD poName VARCHAR(50);
	ALTER TABLE #lrList ADD soName VARCHAR(50);
	ALTER TABLE #lrList ADD customerPO VARCHAR(50);
    ALTER TABLE #lrList ADD thirdPartyPo VARCHAR(500);
	ALTER TABLE #lrList ADD POL VARCHAR(50);
    ALTER TABLE #lrList ADD POD VARCHAR(50);

    ALTER TABLE #lrList ADD shipToId INT;
	ALTER TABLE #lrList ADD shipToLabel VARCHAR(50);

	ALTER TABLE #lrList ADD headerPoName NVARCHAR(MAX);
	ALTER TABLE #lrList ADD headercustomerPO NVARCHAR(MAX);
    ALTER TABLE #lrList ADD headerThirdPartyPo NVARCHAR(MAX);
	ALTER TABLE #lrList ADD headerSoName NVARCHAR(MAX);

	UPDATE #lrList SET
		POL =  s.portOfLanding,
		soName = s.soName,
		customerPO = s.customerPO,
        thirdPartyPo = s.thirdPartyPo,
        shipToId = s.shipToId
	FROM soHeader s
	WHERE #lrList.soHeaderId = s.soHeaderId

    UPDATE #lrList SET
        POD = pt.portName
    FROM md_Port pt
    WHERE #lrList.portId = pt.portId

	UPDATE #lrList SET
		shipToLabel =  st.shipToLabel
	FROM md_shipToDestination st
	WHERE #lrList.shipToId = st.shipToId

	UPDATE #lrList SET
		poName =  p.poName
	FROM poHeader p
	WHERE #lrList.poId = p.poId

	UPDATE #lrList SET
		headerPoName =  aggheaderPoName
	FROM (SELECT lrContainerId, STRING_AGG(CONVERT(NVARCHAR(MAX), poName),', ')as  aggheaderPoName
          FROM (SELECT DISTINCT lrContainerId, poName
                FROM #lrList) g
		  GROUP BY lrContainerId
			) agg
	WHERE #lrList.lrContainerId = agg.lrContainerId

	UPDATE #lrList SET
		headercustomerPO =  aggheadercustomerPO
	FROM (SELECT lrContainerId, STRING_AGG(CONVERT(NVARCHAR(MAX), customerPO),', ')as  aggheadercustomerPO
          FROM (SELECT DISTINCT lrContainerId, customerPO
                FROM #lrList) g
		  GROUP BY lrContainerId
			) agg
	WHERE #lrList.lrContainerId = agg.lrContainerId

    UPDATE #lrList SET
		headerThirdPartyPo =  aggheaderThirdPartyPo
	FROM (SELECT lrContainerId, STRING_AGG(CONVERT(NVARCHAR(MAX), thirdPartyPo),', ') as  aggheaderThirdPartyPo
          FROM (SELECT DISTINCT lrContainerId, thirdPartyPo
                FROM #lrList) g
		  GROUP BY lrContainerId
			) agg
	WHERE #lrList.lrContainerId = agg.lrContainerId

	UPDATE #lrList SET
		headerSoName =  aggheaderSoName
	FROM (SELECT lrContainerId, STRING_AGG(CONVERT(NVARCHAR(MAX), soName),', ') as aggheaderSoName
          FROM (SELECT DISTINCT lrContainerId, soName
                FROM #lrList) g
		  GROUP BY lrContainerId
			) agg
	WHERE #lrList.lrContainerId = agg.lrContainerId

    DECLARE @summarySoName NVARCHAR(MAX), @summaryPoName NVARCHAR(MAX), @summarycustomerPO NVARCHAR(MAX), @summaryThirdPartyPo NVARCHAR(MAX);

    SET @summarySoName = (SELECT STRING_AGG(CONVERT(NVARCHAR(MAX), soName) ,', ') 
                        FROM (SELECT DISTINCT soName
                                FROM #lrList) g
                        );

    SET @summaryPoName = (SELECT STRING_AGG(CONVERT(NVARCHAR(MAX), poName) ,', ') 
                        FROM (SELECT DISTINCT poName
                                FROM #lrList) g
                        );

    SET @summarycustomerPO = (SELECT STRING_AGG(CONVERT(NVARCHAR(MAX), customerPO) ,', ') 
                        FROM (SELECT DISTINCT customerPO
                                FROM #lrList) g
                        );

    SET @summaryThirdPartyPo = (SELECT STRING_AGG(CONVERT(NVARCHAR(MAX), thirdPartyPo) ,', ') 
                        FROM (SELECT DISTINCT thirdPartyPo
                                FROM #lrList) g
                        );

	ALTER TABLE #lrList ADD customerSku VARCHAR(50);
    ALTER TABLE #lrList ADD merchantSku VARCHAR(50);
	ALTER TABLE #lrList ADD soItemDesc VARCHAR(200);
	ALTER TABLE #lrList ADD cbm NUMERIC(14,5);
	ALTER TABLE #lrList ADD grossWeight NUMERIC(14,2);
	ALTER TABLE #lrList ADD netWeight NUMERIC(14,2)

	UPDATE #lrList SET
        customerSku = s.customerSku,
		merchantSku = s.merchantSku,
		soItemDesc = UPPER(s.soItemDesc)
	FROM soLineItem s
	WHERE #lrList.soLineItemId = s.soLineItemId

	UPDATE #lrList SET
		grossWeight = inv.grossWeight,
		netWeight = inv.netWeight,
		cbm = inv.cbm
	FROM md_inventory inv
	WHERE #lrList.invId = inv.invId

    DECLARE @totalContainer VARCHAR(100);

    SELECT @totalContainer = STRING_AGG(CAST(countContainer as varchar) + 'X' + containerType, ' & ')
    FROM (SELECT containerType, COUNT(containerType) as countContainer
            FROM #lrContainer
            GROUP BY containerType)g

    SELECT DISTINCT lrName, l.containerSeq, 
            CASE WHEN ISNULL(l.containerNo,'') = '' AND ISNULL(l.containerSealNo,'') = '' THEN '' ELSE ISNULL(l.containerNo,'') + ' | ' + ISNULL(l.containerSealNo,'') END as containerNo, 
            li.headercustomerPO, li.headerThirdPartyPo, li.headerSoName, li.headerPoName, @totalContainer as totalContainer, l.notes,
            earlyShipDate, lateShipDate, li.POL, li.POD, 'MALAYSIA' as country,            
            li.shipToLabel, li.poName, li.customerPO, li.thirdPartyPo, li.supplierSku, li.soItemDesc, li.customerSku, li.merchantSku, li.qty, li.cbm, li.grossWeight, li.netWeight,
            l.containerType, l.containerCbm, l.containerWeight, li.soName,
            li.qtyPerCarton, @needCartonMaterial as needCartonMaterial,
            @summarySoName as summarySoName, @summaryPoName as summaryPoName, @summarycustomerPO as summarycustomerPO, @summaryThirdPartyPo as summaryThirdPartyPo,
            @summaryContainerNo as summaryContainerNo, @summaryContainerSeq as summaryContainerSeq,
            @isMarketing as isMarketing 
    FROM #lrContainer l
		INNER JOIN #lrList li
			ON l.lrContainerId = li.lrContainerId
 
END

GO


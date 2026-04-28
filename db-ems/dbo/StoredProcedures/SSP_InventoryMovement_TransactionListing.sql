-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-03-07
-- Used By:	    EMS -> Production Module -> Inventory Movement -> Import 

-- Description : Inventory Movement for factory, so they can adjust stock

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-03-07	1.0			ZY Wong		Initial
-- ==========================================================================================
-- EXEC [SSP_InventoryMovement_TransactionListing] 4, 0, 0, '', '2025-04-05', '2025-05-05', 1, 100, 1, 'DESC', ''
CREATE PROCEDURE [dbo].[SSP_InventoryMovement_TransactionListing]
@companyId INT,
@warehouseId INT = 0,
@invId INT = 0,
@action VARCHAR(50) = '',
@startDate NVARCHAR(50),
@endDate NVARCHAR(50),
@rowStart INT,
@pageRow INT,
@sortBy INT = 1,
@sortDirection VARCHAR(4) = 'DESC',
@@searchInput VARCHAR(50) = ''
AS
BEGIN
SET NOCOUNT ON
SET XACT_ABORT ON
	BEGIN TRY
		 
		DECLARE @ErrMessage VARCHAR(MAX);
	/** sortBy
        1 = order by enterDate  
        2 = order by action
        3 = order by warehouse 
        4 = order by inventorysku 
    **/
		 DECLARE @sortOrder VARCHAR(2);

        IF @sortDirection = 'DESC'
        BEGIN
            SET @sortOrder = CAST(@sortBy as VARCHAR) + 'D'
        END
        ELSE
        BEGIN
            SET @sortOrder = CAST(@sortBy as VARCHAR) + 'A'
        END

		SET @sortOrder = '1D'

		IF @warehouseId = 0
			SET @warehouseId = NULL

		IF @invId = 0
			SET @invId = NULL

		IF @action = '' or @action = 0
			SET @action = NULL

		IF ISDATE(@startDate) = 0
		BEGIN
			SET @ErrMessage = 'Invalid Start Date parameter';
			THROW 60000, @ErrMessage, 1;
		END

		IF ISDATE(@endDate) = 0
		BEGIN
			SET @ErrMessage = 'Invalid End Date parameter';
			THROW 60000, @ErrMessage, 1;
		END

		DROP TABLE IF EXISTS #movement;
 
		SELECT inventoryMovementId, enterDate, warehouseId, companyId, action, actionKey, invId, qty, reason, enterBy 
		INTO #movement
		FROM inventoryMovement
		WHERE companyId = @companyId
			AND CONVERT(DATE, enterDate) BETWEEN @startDate AND @endDate
			AND (@action IS NULL OR [action] = @action)
			AND (@warehouseId IS NULL OR warehouseId = @warehouseId)
			AND (@invId IS NULL OR invId = @invId)


		ALTER TABLE #movement ADD userName VARCHAR(50);
		ALTER TABLE #movement ADD inventorySKU VARCHAR(50);
		ALTER TABLE #movement ADD warehouseLabel VARCHAR(20);
 
		UPDATE #movement SET
			userName = usr.userName
		FROM md_user usr
		WHERE #movement.enterBy = usr.userId

		UPDATE #movement SET
			warehouseLabel = wh.label
		FROM md_warehouse wh
		WHERE #movement.warehouseId = wh.warehouseId

		UPDATE #movement SET
			inventorySKU = inv.inventorySKU
		FROM md_inventory inv
		WHERE #movement.invId = inv.invId

		SELECT enterDate, userName, [action], actionKey, reason, warehouseLabel, inventorySku, qty, rowNo
		FROM (
			SELECT enterDate, userName, [action], actionKey, reason, warehouseLabel, inventorySku, qty, 
				ROW_NUMBER() OVER(ORDER BY 
				CASE @sortOrder WHEN '1D' THEN enterDate END DESC,
                CASE @sortOrder WHEN'1A' THEN enterDate END ASC,
                CASE @sortOrder WHEN '2D' THEN [action] END DESC,
                CASE @sortOrder WHEN'2A' THEN [action] END ASC,
                CASE @sortOrder WHEN '3D' THEN warehouseLabel END DESC,
                CASE @sortOrder WHEN'3A' THEN warehouseLabel END ASC,
                CASE @sortOrder WHEN '4D' THEN inventorySku END DESC,
                CASE @sortOrder WHEN '4A' THEN inventorySku END ASC
				) as rowNo
			FROM #movement) ls
		WHERE rowNo BETWEEN @rowStart AND @rowStart + @pageRow
 
        RETURN 0
	END TRY

	BEGIN CATCH
 
        IF @ErrMessage IS NULL 
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE()
 
		RETURN -1
	END CATCH
END

GO


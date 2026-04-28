-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-10-08
-- Description:	Add product thumbnail 
-- Used By:		Inventory Module > Product Listing > Add Product > [Image]

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-04-06	1.0			WL Leong	Initial
-- =============================================
/*
[dbo].[SSP_Inventory_UpdateThumbnail] 1, 'image.png'
*/
CREATE PROCEDURE [dbo].[SSP_Inventory_UpdateThumbnail] 
@invId INT,
@thumbnail VARCHAR(255)
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;
	BEGIN TRY

        DECLARE @returnMessage VARCHAR(MAX);
		DECLARE @updatedProduct AS TABLE(inventorySku varchar(50));

        IF (SELECT COUNT(1) FROM md_inventory WHERE invId = @invId) = 0
        BEGIN
            SET @returnMessage = '[System Error] No such itemId exist.';
            THROW 60000, @returnMessage, 1;
        END
		
		UPDATE md_inventory SET
			thumbnailImage = @thumbnail
		OUTPUT inserted.inventorySku
		INTO @updatedProduct
		WHERE invId = @invId

		SET @returnMessage = (SELECT TOP 1 inventorySku + ' successfully updated' FROM @updatedProduct)

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


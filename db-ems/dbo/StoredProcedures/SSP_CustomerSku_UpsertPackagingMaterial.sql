-- =============================================
-- Author:		ZY Wong
-- Create date: 2026-09-10
-- Description:	Add/ Update/ Delete packaging material based on customer sku
-- Used By:		EMS -> Customer Module -> Edit Customer Sku -> Add/ Update/ Delete Packaging Material

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2026-09-10	1.0			ZY Wong		Initial version
-- =============================================
/*
select * from md_CustomerSkuPackagingMaterial where customerSkuId = 712 and packagingMaterialInvId = 5744
-- Add:		EXEC [SSP_CustomerSku_UpsertPackagingMaterial] N'{ "packagingMaterialList": {"companyId":"6","customerSkuId":"712","productQty":"1","packagingMaterialInvId":"5744","packagingMaterialQty": "13.14","action": "Add"}}', 1
-- Update:	EXEC [SSP_CustomerSku_UpsertPackagingMaterial] N'{ "packagingMaterialList": {"companyId":"6","customerSkuPackagingMaterialId":"88","customerSkuId":"712","productQty":"1","packagingMaterialInvId":"5744","packagingMaterialQty": "13.1415","action": "Update"}}', 1
-- Delete:	EXEC [SSP_CustomerSku_UpsertPackagingMaterial] N'{ "packagingMaterialList": {"companyId":"6","customerSkuPackagingMaterialId":"88","action": "Delete"}}', 1
*/
CREATE PROCEDURE [dbo].[SSP_CustomerSku_UpsertPackagingMaterial]
@Json NVARCHAR(MAX),
@userId INT 
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;
	BEGIN TRY

        DECLARE @ErrMessage VARCHAR(MAX);
        --declare @Json NVARCHAR(MAX), @userId INT = 1;

		DROP TABLE IF EXISTS #packaging;

		SELECT companyId, customerSkuPackagingMaterialId, customerSkuId, productQty, packagingMaterialInvId, CONVERT(NUMERIC(18,4), packagingMaterialQty) as packagingMaterialQty, actionType            
		INTO #packaging
		FROM  OPENJSON(@Json, '$.packagingMaterialList') 
   			WITH (
                companyId INT							N'$.companyId',
				customerSkuPackagingMaterialId BIGINT	N'$.customerSkuPackagingMaterialId',
				customerSkuId BIGINT					N'$.customerSkuId',
				productQty INT							N'$.productQty',
				packagingMaterialInvId BIGINT			N'$.packagingMaterialInvId',
				packagingMaterialQty VARCHAR(20)		N'$.packagingMaterialQty',
				actionType VARCHAR(10)					N'$.action'
			)

		DECLARE @companyId INT, @customerSkuPackagingMaterialId BIGINT, @customerSkuId BIGINT, @productQty INT, @packagingMaterialInvId BIGINT, @packagingMaterialQty NUMERIC(18,4), @actionType VARCHAR(10);
		DECLARE @oriPackagingMaterialInvId BIGINT, @packagingMaterial VARCHAR(255), @customerSku VARCHAR(30);

		SELECT @companyId = companyId, @customerSkuPackagingMaterialId = customerSkuPackagingMaterialId, @customerSkuId = customerSkuId, @productQty = productQty,
			@packagingMaterialInvId = packagingMaterialInvId, @packagingMaterialQty = packagingMaterialQty, @actionType = actionType
		FROM #packaging

		-- check missing actionType
        IF @actionType IS NULL
        BEGIN
            SET @ErrMessage = '[System Error] Action Type is required.';
			THROW 60000, @ErrMessage, 1;
        END

		IF @actionType IN ('Update', 'Delete')
		BEGIN
			-- check missing customerSkuPackagingMaterialId
			IF @customerSkuPackagingMaterialId IS NULL
			BEGIN
				SET @ErrMessage = '[System Error] Customer Sku Packaging Material ID is required.';
				THROW 60000, @ErrMessage, 1;
			END

			-- check invalid customerSkuPackagingMaterialId
			IF NOT EXISTS (
				SELECT 1 FROM md_CustomerSkuPackagingMaterial
				WHERE customerSkuPackagingMaterialId = @customerSkuPackagingMaterialId
					AND statusFlag = 1
			)
			BEGIN
				SET @ErrMessage = '[System Error] Customer Sku Packaging Material ID ' + CAST(@customerSkuPackagingMaterialId as VARCHAR) + ' not found in the system.';
				THROW 60000, @ErrMessage, 1;
			END 
		END

        IF @actionType IN ('Add', 'Update')
        BEGIN
			-- check missing productQty
			IF ISNULL(@productQty, 0) = 0
			BEGIN
				SET @ErrMessage = '[System Error] Product Qty is required.';
				THROW 60000, @ErrMessage, 1;
			END

			-- check missing packagingMaterialQty
			IF ISNULL(@packagingMaterialQty, '0.0000') = '0.0000'
			BEGIN
				SET @ErrMessage = '[System Error] Packaging Material Qty is required.';
				THROW 60000, @ErrMessage, 1;
			END
        END

		IF @actionType = 'Add'
		BEGIN
			-- check missing customerSkuId
			IF @customerSkuId IS NULL
			BEGIN
				SET @ErrMessage = '[System Error] Customer Sku ID is required.';
				THROW 60000, @ErrMessage, 1;
			END
			
			-- check invalid customerSkuId
			IF NOT EXISTS (
				SELECT 1 FROM md_CustomerSku
				WHERE customerSkuId = @customerSkuId
					AND companyId = @companyId
					AND statusflag = 1
			)
			BEGIN
				SET @ErrMessage = '[System Error] Customer Sku ID ' + CAST(@customerSkuId as VARCHAR) + ' not found in the system.';
				THROW 60000, @ErrMessage, 1;
			END 

			-- check missing packagingMaterialInvId
			IF @packagingMaterialInvId IS NULL
			BEGIN
				SET @ErrMessage = '[System Error] Packaging Material Inv ID is required.';
				THROW 60000, @ErrMessage, 1;
			END

			-- check invalid packagingMaterialInvId
			IF NOT EXISTS (
				SELECT 1 FROM md_Inventory 
				WHERE invId = @packagingMaterialInvId
					AND companyId = @companyId
					AND status = 1
			)
			BEGIN
				SET @ErrMessage = '[System Error] Packaging Material Inv ID ' + CAST(@packagingMaterialInvId as VARCHAR) + ' not found in the system.';
				THROW 60000, @ErrMessage, 1;
			END

			-- check packagingMaterialInvId duplicates for same customerSkuId to add
			IF EXISTS (
				SELECT 1 FROM md_customerSkuPackagingMaterial
				WHERE customerSkuId = @customerSkuId
					AND packagingMaterialInvId = @packagingMaterialInvId
					AND statusFlag = 1
			)
            BEGIN
				SET @packagingMaterial = (SELECT productName FROM md_Inventory WHERE companyId = @companyId AND invId = @packagingMaterialInvId AND status = 1);
				SET @customerSku = (SELECT customerSku FROM md_CustomerSku WHERE customerSkuId = @customerSkuId AND statusflag = 1);
                
				SET @ErrMessage = 'Packaging Material [' + @packagingMaterial + '] for Customer Sku [' + @customerSku + '] already exists in the system. Please enter a new Packaging Material, or edit the existing Packaging Material.';
                THROW 60000, @ErrMessage, 1;
            END

			-- get existed deleted packagingMaterialInvId
			SELECT @oriPackagingMaterialInvId = customerSkuPackagingMaterialId 
			FROM md_CustomerSkuPackagingMaterial 
			WHERE customerSkuId = @customerSkuId
				AND packagingMaterialInvId = @packagingMaterialInvId
				AND statusFlag = 0
		END

        BEGIN TRANSACTION

            IF @actionType = 'Delete'
            BEGIN
                UPDATE md_CustomerSkuPackagingMaterial SET
                    statusFlag = 0,
                    updateBy = @userId,
                    updateDateTime = GETDATE()
                WHERE customerSkuPackagingMaterialId = @customerSkuPackagingMaterialId

                SET @ErrMessage = 'deleted.'
            END

            IF @actionType = 'Update'
            BEGIN
                UPDATE md_CustomerSkuPackagingMaterial SET
					productQty = @productQty,
                    unitsPerPackagingMaterial = @packagingMaterialQty,
                    updateBy = @userId,
                    updateDateTime = GETDATE()
                WHERE customerSkuPackagingMaterialId = @customerSkuPackagingMaterialId
 
                SET @ErrMessage = 'updated.'
            END

            IF @actionType = 'Add'
            BEGIN
				IF @oriPackagingMaterialInvId IS NULL
				BEGIN
					INSERT INTO md_CustomerSkuPackagingMaterial (customerSkuId, productQty, packagingMaterialInvId, unitsPerPackagingMaterial, statusFlag, enterBy, createDateTime, updateBy, updateDateTime)
					SELECT @customerSkuId, @productQty, @packagingMaterialInvId, @packagingMaterialQty, 1 as statusFlag, @userId, GETDATE(), @userId, GETDATE()
				END
				ELSE
				BEGIN
					UPDATE md_CustomerSkuPackagingMaterial SET
						productQty = @productQty,
						unitsPerPackagingMaterial = @packagingMaterialQty,
						statusFlag = 1,
						updateBy = @userId,
						updateDateTime = GETDATE()
					WHERE customerSkuPackagingMaterialId = @oriPackagingMaterialInvId
				END

                SET @ErrMessage = 'added.'
            END

        COMMIT TRANSACTION

        SET @ErrMessage = 'Customer Sku Packaging Material is successfully ' + @ErrMessage;

		SELECT '_SUCCESS_' as status, @ErrMessage as returnMessage

        RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END  
 
        IF @ErrMessage IS NULL 
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE()

		SELECT
			'_FAILURE_' as status, @ErrMessage as returnMessage

		RETURN -1
	END CATCH
END

GO
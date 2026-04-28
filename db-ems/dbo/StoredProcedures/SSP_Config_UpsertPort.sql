-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-07-03
-- Description:	Add/Update/Delete/Reactivate Port
-- Used By:		System Setting -> Port

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-03-07	1.0			WL Leong	Initial version
-- =============================================
--EXEC  [dbo].[SSP_Config_UpsertPort]
--    N'{
--	        "portList": [
--		        {
--			        "portId": null,
--			        "portType": "loading",
--			        "portName": "Tanjung Sepat",
--			        "action": "ADD"
--		        }
--	        ]
--        }', 
--        1;

CREATE PROCEDURE [dbo].[SSP_Config_UpsertPort]
@Json VARCHAR(MAX),
@userId INT 
AS
BEGIN
SET NOCOUNT ON
SET XACT_ABORT ON
    BEGIN TRY

        --DECLARE @Json VARCHAR(MAX) = 
        --'{
	       -- "portList": [
		      --  {
			     --   "portId": null,
			     --   "portType": "4",
			     --   "portName": "123",
			     --   "action": "ADD"
		      --  }
	       -- ]
        --}', 
        --@userId INT = 1;
 
		DECLARE @ErrMessage VARCHAR(MAX);

		DROP TABLE IF EXISTS #port;

		SELECT portId, portType, portName, actionType
		INTO #port
		FROM  OPENJSON(@Json, '$.portList') 
   			WITH (
				portId INT                  N'$.portId',
                portType VARCHAR(20)	    N'$.portType',
                portName VARCHAR(50)		N'$.portName',
				actionType VARCHAR(10)		N'$.action'
			)

 
		DECLARE @actionType VARCHAR(10), @portId INT, @portType VARCHAR(20), @portName VARCHAR(50);

		SELECT @actionType = actionType, @portId = portId, @portType = portType, @portName = portName, @actionType = actionType
		FROM #port

        IF ISNULL(@actionType,'') = '' 
        BEGIN
            SET @ErrMessage = '[System Error] Action is required.';
            THROW 60000, @ErrMessage, 1;
        END

        IF ISNULL(@userId,0) = 0 
        BEGIN
            SET @ErrMessage = '[System Error] User Id is required.';
            THROW 60000, @ErrMessage, 1;
        END
                
        IF @actionType IN ('Add', 'Update') 
        BEGIN
            IF ISNULL(@portName, '') = ''
            BEGIN
                SET @ErrMessage = 'Port Name is compulsory.';
                THROW 60000, @ErrMessage, 1;
            END

            IF ISNULL(@portType, '') = ''
            BEGIN
                SET @ErrMessage = 'Port Type [Loading/Discharge] is compulsory.';
                THROW 60000, @ErrMessage, 1;
            END
        END

        IF @actionType = 'Add'
        BEGIN
            IF (SELECT COUNT(1) FROM md_port WHERE portType = @portType AND portName = @portName ) > 0
            BEGIN
                SET @ErrMessage = (SELECT 'Port - ' + @portType  + ' under ' + @portType + 'already exists in the system.'  );
                THROW 60000, @ErrMessage, 1;
            END

        END

        IF @actionType IN ('Update', 'Delete', 'Reactivate') 
        BEGIN
            IF ISNULL(@portId, 0) = 0
            BEGIN
                SET @ErrMessage = '[System Error] Port Id is required.';
                THROW 60000, @ErrMessage, 1;
            END
        END

        BEGIN TRANSACTION
 
        IF @actionType = 'Add'
        BEGIN
            INSERT INTO md_port (portType, portName, statusFlag, createDate, createBy)
            SELECT @portType, @portName, 1 as statusFlag, getdate(), @userId            

            SET @ErrMessage = 'created.';

        END

        IF @actionType = 'Update'
        BEGIN

            UPDATE md_port SET
                portType = @portType,
                portName = @portName,
                updateBy = @userId,
                updateDate = getdate()
            WHERE portId = @portId
  

            SET @ErrMessage = 'updated.';

        END

        IF @actionType = 'Delete'
        BEGIN
            UPDATE md_port SET
                statusFlag = 0,
                updateBy = @userId,
                updateDate = getdate()
            WHERE portId = @portId

            SET @ErrMessage = 'deleted.';
        END
     
        IF @actionType = 'Reactivate'
        BEGIN
            UPDATE md_port SET
                statusFlag = 1,
                updateBy = @userId,
                updateDate = getdate()
            WHERE portId = @portId

            SET @ErrMessage = 're-activated.';
        END

        SET @ErrMessage = 'Port information successfully ' + @ErrMessage;
        
		COMMIT TRANSACTION

		SELECT '_SUCCESS_' as status, @ErrMessage AS returnMessage

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


-- =============================================
-- Author:		WL Leong
-- Create date: 2024-05-05
-- Used By:	    EMS -> LR Module -> LR Listing -> Update Lr Details Summary page

-- Description : 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-03-19   2.0         ZY Wong     Change to use lrContainer table when update ContainerType
-- 2024-05-05	1.0			WL Leong	Initial
-- ==========================================================================================
/*
exec [SSP_LoadingRequest_UpdateLrHeader] 10337,1,3155,'',1
*/
CREATE PROCEDURE [dbo].[SSP_LoadingRequest_UpdateLrHeader]
@lrHeaderId BIGINT,
@containerSeq INT,
@newContainerType INT,
@lrNote VARCHAR(2000),
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
        
        DECLARE @returnMessage VARCHAR(1000)
        DECLARE @existingContainerTypeId INT

        SET @existingContainerTypeId = (SELECT DISTINCT containerTypeId
                                        FROM lrContainer
                                        WHERE lrHeaderId = @lrHeaderId 
                                            AND containerSeq = @containerseq)

        BEGIN TRANSACTION

            IF @existingContainerTypeId <>  @newContainerType
            BEGIN
                UPDATE lr  SET
                    containerTypeId = @newContainerType,
                    updateBy = @userId,
                    updateDate = getdate()
                FROM lrContainer lr
                WHERE lr.lrHeaderId = @lrHeaderId
                    AND lr.containerSeq = @containerSeq

                UPDATE lr SET
                    lrNote = @lrNote,
                    updateBy = @userId,
                    updateDate = getdate()
                FROM lrHeader lr
                WHERE lrHeaderId = @lrHeaderId

                SET @returnMessage = 'Container Type Update Succesfully'
            END 
            ELSE
            BEGIN
                UPDATE lr SET
                    lrNote = @lrNote,
                    updateBy = @userId,
                    updateDate = getdate()
                FROM lrHeader lr
                WHERE lrHeaderId = @lrHeaderId

                SET @returnMessage = 'Container Notes Update Succesfully'
            END

		COMMIT TRANSACTION

		SELECT '_SUCCESS_' as status, @returnMessage as returnMessage
				
		RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0)
		BEGIN
			ROLLBACK TRANSACTION 
		END 

		IF (XACT_STATE()) = 1  
		BEGIN  
			COMMIT TRANSACTION ;     
		END;  
 
		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as returnMessage

		RETURN -1
	END CATCH
END

GO


-- =============================================
-- Author:		WL Leong
-- Create date: 2025-05-26
-- Used By:	    EMS -> Loading Request -> Loading Listing -> Update container

-- Description : 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-05-26	1.0			WL Leong 	Initial
-- ==========================================================================================
 
 		 --EXEC SSP_LoadingRequest_UpdateContainer
			 --N'{"ContainerList":[{"lrHeaderId":"26","containerTypeId":"","containerSeq":"1","containerNo":"CAIU7599320","containerSealNo":"dasdfasdd","containerMaxGross":"0","containerTare":"0","containerPullInDate":"2025-05-29","containerPullOutDate":"2025-05-29","containerReadyDate":null}]}'
			 --,  1;
			--select * from aa
			-- drop table aa
			--select * from lrContainer where lrHeaderId = 26 and containerSEq = 1

CREATE PROCEDURE [dbo].[SSP_LoadingRequest_UpdateContainer]
@Json VARCHAR(MAX),
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		--DECLARE @Json VARCHAR(MAX) = 
		--	N'{"ContainerList":[{
		--	       "lrHeader":1,
		--		   "containerSeq":1,
  --                 "containerNo":"1",	   
		--	       "containerSealNo":"1",
		--	       "containerMaxGross":"111.2200",
		--	       "containerTare":"111.2200",
		--	       "containerPullInDate":"2024-06-10",
		--	       "containerPullOutDate":"2024-06-11",
		--	       "containerReadyDate":"2024-06-11",
		--	}]}'
		--	, @userId INT = 1;

 

		DECLARE @returnMessage VARCHAR(1000);
 
        DROP TABLE IF EXISTS #containerInfo;

        SELECT lrHeaderId, containerSeq, containerNo, containerTypeId,
            CASE WHEN ISNULL(containerSealNo,'') = '' THEN '' ELSE containerSealNo END as containerSealNo, 
            CASE WHEN ISNULL(containerMaxGross,'') = '' THEN '0.0000' ELSE CAST(containerMaxGross as DECIMAL(18,4)) END as containerMaxGross, 
            CASE WHEN ISNULL(containerTare,'') = '' THEN '0.0000' ELSE CAST(containerTare as DECIMAL(18,4)) END as containerTare, 
            CASE WHEN ISNULL(containerPullInDate,'') = '' THEN NULL ELSE CONVERT(SMALLDATETIME, containerPullInDate) END as containerPullInDate, 
            CASE WHEN ISNULL(containerPullOutDate,'') = '' THEN NULL ELSE CONVERT(SMALLDATETIME, containerPullOutDate) END as containerPullOutDate, 
            CASE WHEN ISNULL(cargoReadyDate,'') = '' THEN NULL ELSE CONVERT(SMALLDATETIME, cargoReadyDate) END as cargoReadyDate
        INTO #containerInfo 
        FROM OPENJSON(@Json, '$.ContainerList') 
   				WITH (
					lrHeaderId BIGINT							N'$.lrHeaderId',
					containerSeq INT							N'$.containerSeq',
					containerTypeId INT							N'$.containerTypeId',
                    containerNo VARCHAR(100)                    N'$.containerNo',
                    containerSealNo VARCHAR(100)                N'$.containerSealNo',
                    containerMaxGross VARCHAR(10)               N'$.containerMaxGross',
                    containerTare VARCHAR(10)                   N'$.containerTare',
                    containerPullInDate VARCHAR(20)             N'$.containerPullInDate',
                    containerPullOutDate VARCHAR(20)            N'$.containerPullOutDate',
					cargoReadyDate VARCHAR(20)					N'$.cargoReadyDate'
                )
        
		 

		BEGIN TRANSACTION

		    UPDATE cont SET
                containerNo = CASE WHEN ISNULL(s.containerNo,'') = '' THEN cont.containerNo ELSE s.containerNo END,
				containerTypeId = s.containerTypeId,
                containerSealNo = s.containerSealNo,
            	containerMaxGross = s.containerMaxGross,
                containerTare = s.containerTare,
			    containerPullInDate = s.containerPullInDate,
			    containerPullOutDate = s.containerPullOutDate,
				--cargoReadyDate = s.cargoReadyDate, 
			    updateBy = @userId,
			    updateDate = getdate()
		    FROM lrContainer cont
                INNER JOIN #containerInfo s
		            ON cont.lrHeaderId = s.lrHeaderId
					AND cont.containerSeq = s.containerSeq
 
		COMMIT TRANSACTION
        
        SELECT '_SUCCESS_' as status, 'Container Info success update.' as returnMessage

		RETURN 0
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


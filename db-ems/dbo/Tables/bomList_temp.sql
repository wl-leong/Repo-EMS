CREATE TABLE [dbo].[bomList_temp] (
    [bomListId]       INT             IDENTITY (1, 1) NOT NULL,
    [bomBuildId]      INT             NOT NULL,
    [bomInvId]        INT             NOT NULL,
    [usageQty]        NUMERIC (13, 4) NOT NULL,
    [buildInvId]      INT             NOT NULL,
    [buildQty]        INT             NOT NULL,
    [status]          INT             NOT NULL,
    [createBy]        VARCHAR (20)    NOT NULL,
    [createDateTime]  DATETIME        NOT NULL,
    [updatedBy]       VARCHAR (20)    NOT NULL,
    [updatedDateTime] DATETIME        NOT NULL
);


GO


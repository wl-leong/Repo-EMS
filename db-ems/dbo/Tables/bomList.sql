CREATE TABLE [dbo].[bomList] (
    [bomListId]       INT             IDENTITY (1, 1) NOT NULL,
    [bomBuildId]      INT             NOT NULL,
    [bomInvId]        INT             NOT NULL,
    [usageQty]        NUMERIC (13, 4) CONSTRAINT [DF_processDetails_invQty] DEFAULT ((1)) NOT NULL,
    [buildInvId]      INT             NOT NULL,
    [buildQty]        INT             CONSTRAINT [DF_processDetails_buildQty] DEFAULT ((1)) NOT NULL,
    [status]          INT             CONSTRAINT [DF_workInProgressDetails_status] DEFAULT ((1)) NOT NULL,
    [createBy]        VARCHAR (20)    NOT NULL,
    [createDateTime]  DATETIME        CONSTRAINT [DF_processDetails_createDateTime] DEFAULT (getdate()) NOT NULL,
    [updatedBy]       VARCHAR (20)    NOT NULL,
    [updatedDateTime] DATETIME        CONSTRAINT [DF_processDetails_updatedDateTime] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_processDetails] PRIMARY KEY CLUSTERED ([bomListId] ASC)
);


GO


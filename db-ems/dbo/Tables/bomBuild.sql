CREATE TABLE [dbo].[bomBuild] (
    [bomBuildId]      INT           IDENTITY (1, 1) NOT NULL,
    [companyId]       INT           NOT NULL,
    [bomBuildName]    VARCHAR (50)  NOT NULL,
    [remarks]         VARCHAR (500) CONSTRAINT [DF_process_remarks] DEFAULT ('') NOT NULL,
    [status]          INT           CONSTRAINT [DF_workInProgress_status] DEFAULT ((1)) NOT NULL,
    [createBy]        VARCHAR (20)  NOT NULL,
    [createDateTime]  DATETIME      CONSTRAINT [DF_process_createDateTime] DEFAULT (getdate()) NOT NULL,
    [updatedBy]       VARCHAR (20)  NOT NULL,
    [updatedDateTime] DATETIME      CONSTRAINT [DF_process_updatedDateTime] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_process] PRIMARY KEY CLUSTERED ([bomBuildId] ASC)
);


GO


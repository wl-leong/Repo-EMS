CREATE TABLE [dbo].[md_Port] (
    [portId]     INT          IDENTITY (1, 1) NOT NULL,
    [portType]   VARCHAR (20) CONSTRAINT [DF_Table_1_portOfDischarge] DEFAULT ('') NOT NULL,
    [portName]   VARCHAR (50) CONSTRAINT [DF_md_Port_portName] DEFAULT ('') NOT NULL,
    [statusFlag] INT          CONSTRAINT [DF_md_Port_statusFlag] DEFAULT ((1)) NOT NULL,
    [createBy]   INT          NOT NULL,
    [createDate] DATETIME     CONSTRAINT [DF_md_Port_createDate] DEFAULT (getdate()) NOT NULL,
    [updateBy]   INT          NULL,
    [updateDate] DATETIME     NULL,
    CONSTRAINT [PK_md_Port] PRIMARY KEY CLUSTERED ([portId] ASC)
);


GO


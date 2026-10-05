CREATE TABLE [dbo].[rawBom] (
    [rawBomId]    BIGINT          IDENTITY (1, 1) NOT NULL,
    [companyId]   INT             NOT NULL,
    [invId]       BIGINT          NOT NULL,
    [rawBomInvId] BIGINT          CONSTRAINT [DF_rawBom_rawBomInvId] DEFAULT ((0)) NOT NULL,
    [rawBomQty]   NUMERIC (18, 4) CONSTRAINT [DF_rawBom_rawBomQty] DEFAULT ((0)) NOT NULL,
    [status]      INT             NOT NULL,
    [enterBy]     VARCHAR (20)    CONSTRAINT [DF_rawBom_enterBy] DEFAULT ('') NOT NULL,
    [enterDate]   DATETIME        CONSTRAINT [DF_rawBom_enterDate] DEFAULT (getdate()) NOT NULL,
    [updateBy]    VARCHAR (20)    CONSTRAINT [DF_rawBom_updateBy] DEFAULT ('') NOT NULL,
    [updateDate]  DATETIME        CONSTRAINT [DF_rawBom_updateDate] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_rawBom] PRIMARY KEY CLUSTERED ([rawBomId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_rawBom_status]
    ON [dbo].[rawBom]([status] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_rawBom_invId]
    ON [dbo].[rawBom]([invId] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_rawBom_rawBomInvId]
    ON [dbo].[rawBom]([rawBomInvId] ASC);


GO


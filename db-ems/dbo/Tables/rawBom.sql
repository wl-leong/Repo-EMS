CREATE TABLE [dbo].[rawBom] (
    [rawBomId]    BIGINT          IDENTITY (1, 1) NOT NULL,
    [companyId]   INT             NOT NULL,
    [invId]       BIGINT          NOT NULL,
    [rawBomInvId] BIGINT          CONSTRAINT [DF_rawBom_rawBomInvId] DEFAULT ((0)) NOT NULL,
    [rawBomQty]   NUMERIC (18, 4) CONSTRAINT [DF_rawBom_rawBomQty] DEFAULT ((0)) NOT NULL,
    [status]      INT             NOT NULL,
    [enterBy]     VARCHAR (20)    CONSTRAINT [DF__rawBom__enterBy__6AD0B01E] DEFAULT ('') NOT NULL,
    [enterDate]   DATETIME        CONSTRAINT [DF__rawBom__enterDat__6BC4D457] DEFAULT (getdate()) NOT NULL,
    [updateBy]    VARCHAR (20)    CONSTRAINT [DF__rawBom__updateBy__6CB8F890] DEFAULT ('') NOT NULL,
    [updateDate]  DATETIME        CONSTRAINT [DF__rawBom__updateDa__6DAD1CC9] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK__rawBom__5CF9DE439A341E1F] PRIMARY KEY CLUSTERED ([rawBomId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_rawBom_status]
    ON [dbo].[rawBom]([status] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_rawBom_invId]
    ON [dbo].[rawBom]([invId] ASC);


GO


CREATE TABLE [dbo].[procurementProcess] (
    [procurementProcessId] BIGINT          IDENTITY (1, 1) NOT NULL,
    [companyId]            INT             NOT NULL,
    [soHeaderId]           BIGINT          NOT NULL,
    [soName]               VARCHAR (50)    NOT NULL,
    [soLineItemId]         BIGINT          NOT NULL,
    [invId]                BIGINT          NOT NULL,
    [processQty]           INT             NOT NULL,
    [rawBomInvId]          BIGINT          NOT NULL,
    [rawBomQty]            NUMERIC (13, 4) NOT NULL,
    [rawBomTotalQty]       NUMERIC (13, 4) CONSTRAINT [DF_procurementProcess_rawBomTotalQty] DEFAULT ((0)) NOT NULL,
    [poQty]                NUMERIC (13, 4) CONSTRAINT [DF__procureme__poQty__459F2B6F] DEFAULT ((0)) NOT NULL,
    [lockQty]              NUMERIC (13, 4) CONSTRAINT [DF_procurementProcess_lockQty] DEFAULT ((0)) NOT NULL,
    [status]               INT             NOT NULL,
    [enterBy]              INT             CONSTRAINT [DF__procureme__enter__46934FA8] DEFAULT ('') NOT NULL,
    [enterDate]            DATETIME        CONSTRAINT [DF__procureme__enter__478773E1] DEFAULT (getdate()) NOT NULL,
    [updateBy]             INT             CONSTRAINT [DF__procureme__updat__487B981A] DEFAULT ('') NOT NULL,
    [updateDate]           DATETIME        CONSTRAINT [DF__procureme__updat__496FBC53] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK__procurem__4174F80D324698FD] PRIMARY KEY CLUSTERED ([procurementProcessId] ASC)
);


GO


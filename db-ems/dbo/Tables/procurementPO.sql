CREATE TABLE [dbo].[procurementPO] (
    [procurementPoId]      BIGINT   IDENTITY (1, 1) NOT NULL,
    [procurementProcessId] BIGINT   NOT NULL,
    [poLineItemId]         BIGINT   NOT NULL,
    [poQty]                INT      CONSTRAINT [DF_procurementPO_poQty] DEFAULT ((0)) NOT NULL,
    [status]               INT      CONSTRAINT [DF_procurementPO_status] DEFAULT ((0)) NOT NULL,
    [enterDate]            DATETIME CONSTRAINT [DF_procurementPO_enterDate] DEFAULT (getdate()) NOT NULL,
    [enterBy]              INT      NOT NULL,
    [updateDate]           DATETIME NULL,
    [updateBy]             INT      NULL,
    CONSTRAINT [PK_procurementPO] PRIMARY KEY CLUSTERED ([procurementPoId] ASC)
);


GO


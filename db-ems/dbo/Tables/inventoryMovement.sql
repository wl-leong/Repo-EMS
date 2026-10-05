CREATE TABLE [dbo].[inventoryMovement] (
    [inventoryMovementId] BIGINT        IDENTITY (1, 1) NOT NULL,
    [warehouseId]         INT           NOT NULL,
    [companyId]           INT           NOT NULL,
    [action]              VARCHAR (20)  NOT NULL,
    [actionKey]           VARCHAR (80)  CONSTRAINT [DF_inventoryMovement_actionKey] DEFAULT ('') NULL,
    [invId]               BIGINT        NOT NULL,
    [qty]                 INT           NOT NULL,
    [whBalanceQty]        INT           CONSTRAINT [DF_inventoryMovement_whBalanceQty] DEFAULT ((0)) NOT NULL,
    [reason]              VARCHAR (200) NULL,
    [enterBy]             INT           NOT NULL,
    [enterDate]           DATETIME      NOT NULL,
    CONSTRAINT [PK_inventoryMovement] PRIMARY KEY CLUSTERED ([inventoryMovementId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_inventoryMovement_companyId_enterDate]
    ON [dbo].[inventoryMovement]([companyId] ASC, [enterDate] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_inventoryMovement_invId_warehouseId]
    ON [dbo].[inventoryMovement]([invId] ASC, [warehouseId] ASC);


GO


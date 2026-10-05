CREATE TABLE [dbo].[inventoryBalanceWh_Lock] (
    [warehouseBalanceLockId] BIGINT          IDENTITY (1, 1) NOT NULL,
    [companyId]              INT             NOT NULL,
    [soHeaderId]             BIGINT          NULL,
    [soLineItemId]           BIGINT          NULL,
    [warehouseId]            INT             NOT NULL,
    [invid]                  INT             NOT NULL,
    [lockQty]                NUMERIC (13, 4) NOT NULL,
    [releaseQty]             NUMERIC (13, 4) CONSTRAINT [DF_inventoryBalanceWh_Lock_releaseQty] DEFAULT ((0)) NOT NULL,
    [notes]                  VARCHAR (5000)  NULL,
    [enterBy]                INT             CONSTRAINT [DF__inventory__enter__08611305] DEFAULT ('') NOT NULL,
    [enterDate]              DATETIME        CONSTRAINT [DF__inventory__enter__0955373E] DEFAULT (getdate()) NOT NULL,
    [updateBy]               INT             CONSTRAINT [DF__inventory__updat__0A495B77] DEFAULT ('') NOT NULL,
    [updateDate]             DATETIME        CONSTRAINT [DF__inventory__updat__0B3D7FB0] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_inventoryBalanceWh_Lock] PRIMARY KEY CLUSTERED ([warehouseBalanceLockId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_inventoryBalanceWh_Lock_soLineItemId]
    ON [dbo].[inventoryBalanceWh_Lock]([soLineItemId] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_inventoryBalanceWh_Lock_invid_warehouseId]
    ON [dbo].[inventoryBalanceWh_Lock]([invid] ASC, [warehouseId] ASC)
    INCLUDE([lockQty], [releaseQty]);


GO


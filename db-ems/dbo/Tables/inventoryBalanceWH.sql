CREATE TABLE [dbo].[inventoryBalanceWH] (
    [invBalanceId] INT      IDENTITY (1, 1) NOT NULL,
    [warehouseId]  INT      NOT NULL,
    [companyId]    INT      NOT NULL,
    [invId]        BIGINT   NOT NULL,
    [balanceQty]   INT      CONSTRAINT [DF__inventory__inv_b__75035A77] DEFAULT ((0)) NOT NULL,
    [lockQty]      INT      CONSTRAINT [DF__inventory__inv_l__75F77EB0] DEFAULT ((0)) NOT NULL,
    [createBy]     INT      NOT NULL,
    [createDate]   DATETIME NOT NULL,
    [updateBy]     INT      NULL,
    [updateDate]   DATETIME CONSTRAINT [DF__inventory__updat__76EBA2E9] DEFAULT (getdate()) NULL,
    CONSTRAINT [PK__inventor__BCC6D63E44BDC5D3] PRIMARY KEY CLUSTERED ([invBalanceId] ASC)
);


GO


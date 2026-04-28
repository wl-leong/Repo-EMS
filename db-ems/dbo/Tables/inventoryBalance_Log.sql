CREATE TABLE [dbo].[inventoryBalance_Log] (
    [logID]       BIGINT         IDENTITY (1, 1) NOT NULL,
    [entryDate]   DATETIME       CONSTRAINT [DF__inventory__entry__6A85CC04] DEFAULT (getdate()) NOT NULL,
    [companyId]   INT            NOT NULL,
    [warehouseId] INT            NOT NULL,
    [actionType]  VARCHAR (20)   CONSTRAINT [DF__inventory__actio__6B79F03D] DEFAULT ('') NOT NULL,
    [invID]       INT            NOT NULL,
    [qty]         INT            CONSTRAINT [DF__inventoryBa__qty__6C6E1476] DEFAULT ((0)) NOT NULL,
    [notes]       VARCHAR (1000) CONSTRAINT [DF__inventory__notes__6D6238AF] DEFAULT ('') NOT NULL,
    [createBy]    INT            NOT NULL,
    [createDate]  DATETIME       NOT NULL,
    [updateBy]    INT            NOT NULL,
    [updateDate]  DATETIME       NOT NULL,
    CONSTRAINT [PK__inventor__7839F62DD006952A] PRIMARY KEY CLUSTERED ([logID] ASC)
);


GO


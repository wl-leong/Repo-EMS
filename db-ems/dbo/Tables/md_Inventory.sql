CREATE TABLE [dbo].[md_Inventory] (
    [invID]              BIGINT         IDENTITY (1, 1) NOT NULL,
    [companyId]          INT            NULL,
    [itemCode]           VARCHAR (50)   NOT NULL,
    [productCategory]    INT            NOT NULL,
    [productSubCategory] INT            NOT NULL,
    [productType]        INT            NOT NULL,
    [modelNo]            VARCHAR (50)   NOT NULL,
    [inventorySKU]       VARCHAR (50)   NOT NULL,
    [productName]        VARCHAR (255)  NOT NULL,
    [productPrice]       FLOAT (53)     NOT NULL,
    [itemDesc]           NVARCHAR (500) NULL,
    [netWeight]          FLOAT (53)     CONSTRAINT [DF_md_Inventory_netWeight] DEFAULT ((0)) NOT NULL,
    [netLength]          FLOAT (53)     CONSTRAINT [DF_md_Inventory_netDepth] DEFAULT ((0)) NOT NULL,
    [netWidth]           FLOAT (53)     CONSTRAINT [DF_md_Inventory_netWidth] DEFAULT ((0)) NOT NULL,
    [netHeight]          FLOAT (53)     CONSTRAINT [DF_md_Inventory_netHeight] DEFAULT ((0)) NOT NULL,
    [grossWeight]        FLOAT (53)     NOT NULL,
    [grossLength]        FLOAT (53)     NOT NULL,
    [grossWidth]         FLOAT (53)     NOT NULL,
    [grossHeight]        FLOAT (53)     NOT NULL,
    [cbm]                FLOAT (53)     NOT NULL,
    [measurement]        INT            NULL,
    [glCode]             VARCHAR (50)   NULL,
    [isVirtual]          INT            CONSTRAINT [DF_isVirtual] DEFAULT ((0)) NULL,
    [isBuffer]           INT            NULL,
    [status]             INT            CONSTRAINT [DF_md_Inventory_status] DEFAULT ('1') NOT NULL,
    [CreateDateTime]     DATETIME       CONSTRAINT [DF_md_Inventory_createDateTime] DEFAULT (getdate()) NOT NULL,
    [UpdateDateTime]     DATETIME       CONSTRAINT [DF_md_Inventory_UpdateDateTime] DEFAULT (getdate()) NOT NULL,
    [thumbnailImage]     VARCHAR (255)  NULL,
    CONSTRAINT [PK_md_Inventory_invId] PRIMARY KEY CLUSTERED ([invID] ASC),
    CONSTRAINT [FK_md_Inventory_md_Company] FOREIGN KEY ([companyId]) REFERENCES [dbo].[md_Company] ([companyId]),
    CONSTRAINT [FK_md_Inventory_md_InventoryCategory] FOREIGN KEY ([productCategory]) REFERENCES [dbo].[md_InventoryCategory] ([prodCategoryId]),
    CONSTRAINT [FK_md_Inventory_md_InventoryCategory1] FOREIGN KEY ([productSubCategory]) REFERENCES [dbo].[md_InventoryCategory] ([prodCategoryId]),
    CONSTRAINT [FK_md_Inventory_md_inventoryType] FOREIGN KEY ([productType]) REFERENCES [dbo].[md_inventoryType] ([inventoryTypeId])
);


GO


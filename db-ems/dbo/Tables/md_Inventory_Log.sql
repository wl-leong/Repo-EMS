CREATE TABLE [dbo].[md_Inventory_Log] (
    [invID]              BIGINT         IDENTITY (1, 1) NOT NULL,
    [invorgID]           BIGINT         NOT NULL,
    [companyId]          INT            NULL,
    [itemCode]           VARCHAR (255)  NULL,
    [productCategory]    INT            NULL,
    [productSubCategory] INT            NULL,
    [productType]        INT            NULL,
    [modelNo]            VARCHAR (255)  NULL,
    [inventorySKU]       VARCHAR (50)   NULL,
    [productName]        VARCHAR (255)  NULL,
    [productPrice]       FLOAT (53)     NULL,
    [itemDesc]           VARCHAR (5000) NULL,
    [grossWeight]        FLOAT (53)     NULL,
    [grossWidth]         FLOAT (53)     NULL,
    [grossHeight]        FLOAT (53)     NULL,
    [grossDepth]         FLOAT (53)     NULL,
    [cbm]                FLOAT (53)     NULL,
    [measurement]        INT            NULL,
    [CreateDateTime]     DATETIME       CONSTRAINT [DF__md_invent__Creat__4CA06362] DEFAULT (getdate()) NULL,
    [status]             INT            CONSTRAINT [DF__md_invent__statu__4D94879B] DEFAULT ('1') NULL,
    [UpdateDateTime]     DATETIME       CONSTRAINT [DF__md_invent__Updat__4E88ABD4] DEFAULT (getdate()) NULL,
    [actiontype]         VARCHAR (10)   NOT NULL,
    CONSTRAINT [PK_md_Inventory_Log] PRIMARY KEY CLUSTERED ([invID] ASC)
);


GO


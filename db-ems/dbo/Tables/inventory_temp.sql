CREATE TABLE [dbo].[inventory_temp] (
    [invID]              BIGINT         IDENTITY (1, 1) NOT NULL,
    [companyId]          INT            NULL,
    [upc]                VARCHAR (50)   NOT NULL,
    [productCategory]    INT            NOT NULL,
    [productSubCategory] INT            NOT NULL,
    [productType]        INT            NOT NULL,
    [modelNo]            VARCHAR (50)   NOT NULL,
    [inventorySKU]       VARCHAR (50)   NOT NULL,
    [productName]        VARCHAR (255)  NOT NULL,
    [productPrice]       FLOAT (53)     NOT NULL,
    [itemDesc]           VARCHAR (5000) NOT NULL,
    [netWeight]          FLOAT (53)     NOT NULL,
    [netWidth]           FLOAT (53)     NOT NULL,
    [netHeight]          FLOAT (53)     NOT NULL,
    [netDepth]           FLOAT (53)     NOT NULL,
    [grossWeight]        FLOAT (53)     NOT NULL,
    [grossWidth]         FLOAT (53)     NOT NULL,
    [grossHeight]        FLOAT (53)     NOT NULL,
    [grossDepth]         FLOAT (53)     NOT NULL,
    [cbm]                FLOAT (53)     NOT NULL,
    [measurement]        INT            NULL,
    [CreateDateTime]     DATETIME       NOT NULL,
    [status]             INT            NOT NULL,
    [UpdateDateTime]     DATETIME       NOT NULL,
    [IsVirtual]          INT            NULL,
    [glCode]             VARCHAR (50)   NULL
);


GO


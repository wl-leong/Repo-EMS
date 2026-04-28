CREATE TABLE [dbo].[poReceivedHeader] (
    [poRcvHeaderId] BIGINT         IDENTITY (1, 1) NOT NULL,
    [companyId]     INT            NOT NULL,
    [supplierId]    INT            NOT NULL,
    [poRcvDate]     DATE           NOT NULL,
    [poRcvName]     VARCHAR (50)   NOT NULL,
    [supplierDO]    VARCHAR (50)   NOT NULL,
    [warehouseId]   INT            CONSTRAINT [DF_poReceivedHeader_warehouseId] DEFAULT ((0)) NOT NULL,
    [poRcvStatus]   INT            NOT NULL,
    [notes]         VARCHAR (2000) NULL,
    [enterBy]       INT            NOT NULL,
    [enterDate]     DATETIME       CONSTRAINT [DF_poReceivedHeader_enterDate] DEFAULT (getdate()) NOT NULL,
    [updateBy]      INT            NULL,
    [updateDate]    DATETIME       NULL,
    CONSTRAINT [PK_poReceivedHeader] PRIMARY KEY CLUSTERED ([poRcvHeaderId] ASC),
    CONSTRAINT [FK_poReceivedHeader_md_Warehouse] FOREIGN KEY ([warehouseId]) REFERENCES [dbo].[md_Warehouse] ([warehouseId])
);


GO


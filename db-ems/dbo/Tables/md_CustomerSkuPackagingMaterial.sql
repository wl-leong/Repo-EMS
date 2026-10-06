CREATE TABLE [dbo].[md_CustomerSkuPackagingMaterial]
(
    [customerSkuPackagingMaterialId] BIGINT IDENTITY (1, 1) NOT NULL,
    [customerSkuId]                  INT             NOT NULL,
    [productQty]                     INT             NOT NULL,
    [packagingMaterialInvId]         BIGINT          NOT NULL,
    [unitsPerPackagingMaterial]      NUMERIC(13,4)   NOT NULL,
    [statusFlag]                     INT
        CONSTRAINT [DF_md_CustomerSkuPackagingMaterial_statusFlag]
        DEFAULT ((1)) NOT NULL,
    [enterBy]                        INT             NOT NULL,
    [createDateTime]                 DATETIME
        CONSTRAINT [DF_md_CustomerSkuPackagingMaterial_createDateTime]
        DEFAULT (GETDATE()) NOT NULL,
    [updateBy]                       INT             NOT NULL,
    [updateDateTime]                 DATETIME
        CONSTRAINT [DF_md_CustomerSkuPackagingMaterial_updateDateTime]
        DEFAULT (GETDATE()) NOT NULL,

    CONSTRAINT [PK_md_CustomerSkuPackagingMaterial]
        PRIMARY KEY CLUSTERED
        ([customerSkuPackagingMaterialId] ASC),

    CONSTRAINT [FK_CustomerSkuPackagingMaterial_CustomerSku]
        FOREIGN KEY ([customerSkuId])
        REFERENCES [dbo].[md_CustomerSku] ([customerskuId]),

    CONSTRAINT [FK_CustomerSkuPackagingMaterial_PackagingInventory]
        FOREIGN KEY ([packagingMaterialInvId])
        REFERENCES [dbo].[md_Inventory] ([invID]),

    CONSTRAINT [UQ_CustomerSkuPackagingMaterial]
        UNIQUE ([customerSkuId], [packagingMaterialInvId]),

    CONSTRAINT [CK_CustomerSkuPackagingMaterial_Quantity]
        CHECK ([unitsPerPackagingMaterial] > 0),

    CONSTRAINT [CK_CustomerSkuPackagingMaterial_ProductQuantity]
        CHECK ([productQty] > 0),

    CONSTRAINT [CK_CustomerSkuPackagingMaterial_Status]
        CHECK ([statusFlag] IN (0, 1))
);
GO
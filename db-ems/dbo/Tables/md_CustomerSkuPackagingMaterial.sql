CREATE TABLE md_CustomerSkuPackagingMaterial
(
    customerSkuPackagingMaterialId BIGINT IDENTITY(1,1) NOT NULL,
    customerSkuId                  INT NOT NULL,
    packagingMaterialInvId         BIGINT NOT NULL,
    unitsPerPackagingMaterial      DECIMAL(18,4) NOT NULL,
    statusFlag                     INT NOT NULL DEFAULT 1,
    enterBy                        INT NOT NULL,
    createDateTime                 DATETIME NOT NULL DEFAULT GETDATE(),
    updateBy                       INT NOT NULL,
    updateDateTime                 DATETIME NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_md_CustomerSkuPackagingMaterial
        PRIMARY KEY (customerSkuPackagingMaterialId),

    CONSTRAINT FK_CustomerSkuPackaging_CustomerSku
        FOREIGN KEY (customerSkuId)
        REFERENCES dbo.md_CustomerSku(customerskuId),

    CONSTRAINT FK_CustomerSkuPackaging_Inventory
        FOREIGN KEY (packagingMaterialInvId)
        REFERENCES dbo.md_Inventory(invID),

    CONSTRAINT UQ_CustomerSkuPackaging
        UNIQUE (customerSkuId, packagingMaterialInvId),

    CONSTRAINT CK_CustomerSkuPackaging_Units
        CHECK (unitsPerPackagingMaterial > 0)
);
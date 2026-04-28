CREATE TABLE [dbo].[md_SupplierTerm] (
    [supplierTnCId] INT         IDENTITY (1, 1) NOT NULL,
    [companyId]     INT         NOT NULL,
    [supplierId]    INT         NOT NULL,
    [module]        VARCHAR (3) NOT NULL,
    [termRow]       INT         NOT NULL,
    [termCondition] TEXT        CONSTRAINT [DF_md_SupplierTerm_termCondition] DEFAULT ('') NOT NULL,
    [statusFlag]    INT         NOT NULL,
    [enterBy]       INT         NOT NULL,
    [enterDate]     DATETIME    CONSTRAINT [DF_md_SupplierTerm_enterDate] DEFAULT (getdate()) NOT NULL,
    [updateBy]      INT         NULL,
    [updateDate]    DATETIME    NULL,
    CONSTRAINT [PK_md_SupplierTerm] PRIMARY KEY CLUSTERED ([supplierTnCId] ASC),
    CONSTRAINT [FK_md_SupplierTerm_md_Supplier] FOREIGN KEY ([supplierId]) REFERENCES [dbo].[md_Supplier] ([supplierId])
);


GO


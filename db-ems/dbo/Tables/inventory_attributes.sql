CREATE TABLE [dbo].[inventory_attributes] (
    [attributesId] BIGINT        IDENTITY (1, 1) NOT NULL,
    [invID]        BIGINT        NOT NULL,
    [categoryId]   INT           NOT NULL,
    [value]        VARCHAR (255) NOT NULL,
    CONSTRAINT [PK_product_attributes] PRIMARY KEY CLUSTERED ([attributesId] ASC),
    CONSTRAINT [FK_inventory_attributes_md_Inventory] FOREIGN KEY ([invID]) REFERENCES [dbo].[md_Inventory] ([invID])
);


GO


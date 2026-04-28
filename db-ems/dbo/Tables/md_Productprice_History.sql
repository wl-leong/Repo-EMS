CREATE TABLE [dbo].[md_Productprice_History] (
    [historyId]      BIGINT     IDENTITY (1, 1) NOT NULL,
    [invID]          INT        NOT NULL,
    [productPrice]   FLOAT (53) NOT NULL,
    [updateDateTime] DATETIME   CONSTRAINT [DF__md_Produc__updat__6477ECF3] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_md_Productprice_History] PRIMARY KEY CLUSTERED ([historyId] ASC)
);


GO


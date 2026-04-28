CREATE TABLE [dbo].[md_CurrencyRate] (
    [rateId]          INT             IDENTITY (1, 1) NOT NULL,
    [companyId]       INT             NOT NULL,
    [startDate]       DATE            NOT NULL,
    [endDate]         DATE            NOT NULL,
    [homeCurrency]    VARCHAR (3)     NOT NULL,
    [foreignCurrency] VARCHAR (3)     NOT NULL,
    [foreignRate]     NUMERIC (13, 6) CONSTRAINT [DF_md_CurrencyRate_foreignRate] DEFAULT ((1)) NOT NULL,
    [status]          INT             NOT NULL,
    [enterBy]         INT             NOT NULL,
    [enterDate]       DATETIME        NOT NULL,
    [updateBy]        INT             NOT NULL,
    [updateDate]      DATETIME        CONSTRAINT [DF_md_CurrencyRate_updatedDate] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_md_CurrencyRate] PRIMARY KEY CLUSTERED ([rateId] ASC)
);


GO


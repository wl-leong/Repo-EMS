CREATE TABLE [dbo].[md_SequenceNumber] (
    [Id]          INT          IDENTITY (1, 1) NOT NULL,
    [csID]        INT          NULL,
    [companyCode] VARCHAR (3)  NULL,
    [condition]   VARCHAR (50) NOT NULL,
    [ItemFormat]  VARCHAR (50) NOT NULL,
    [FormatIndex] INT          NOT NULL,
    [NextNum]     BIGINT       NOT NULL,
    [MaxNum]      BIGINT       NOT NULL,
    CONSTRAINT [PK_MD_SequenceNumber] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO


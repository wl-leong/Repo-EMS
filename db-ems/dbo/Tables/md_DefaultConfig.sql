CREATE TABLE [dbo].[md_DefaultConfig] (
    [configId]    INT           IDENTITY (1, 1) NOT NULL,
    [companyId]   INT           NULL,
    [configName]  VARCHAR (50)  NULL,
    [configValue] VARCHAR (200) NULL,
    [insertedon]  DATETIME      CONSTRAINT [DF_md_DefaultConfig_insertedon] DEFAULT (getdate()) NULL,
    CONSTRAINT [PK_md_DefaultConfig] PRIMARY KEY CLUSTERED ([configId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_md_DefaultConfig_companyId_configName]
    ON [dbo].[md_DefaultConfig]([companyId] ASC, [configName] ASC)
    INCLUDE([configValue]);


GO


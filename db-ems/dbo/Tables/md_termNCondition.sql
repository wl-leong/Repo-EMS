CREATE TABLE [dbo].[md_termNCondition] (
    [customerTermId] INT            IDENTITY (1, 1) NOT NULL,
    [companyId]      INT            NOT NULL,
    [customerId]     INT            NOT NULL,
    [module]         VARCHAR (3)    NULL,
    [termRow]        INT            NOT NULL,
    [termText]       VARCHAR (5000) NULL,
    [statusFlag]     INT            NULL,
    [enterBy]        INT            NULL,
    [enterDate]      DATETIME       CONSTRAINT [DEFAULT_md_customerTerm_enterDate] DEFAULT (getdate()) NULL,
    [updateBy]       INT            NULL,
    [updateDate]     DATETIME       NULL
);


GO


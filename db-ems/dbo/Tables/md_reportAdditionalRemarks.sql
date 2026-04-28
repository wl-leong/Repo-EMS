CREATE TABLE [dbo].[md_reportAdditionalRemarks] (
    [rptRemarksId] BIGINT         IDENTITY (1, 1) NOT NULL,
    [companyId]    INT            NOT NULL,
    [customerId]   INT            CONSTRAINT [DF_md_reportAdditionalRemarks_customerId] DEFAULT ((0)) NULL,
    [supplierId]   INT            CONSTRAINT [DF_md_reportAdditionalRemarks_supplierId] DEFAULT ((0)) NULL,
    [module]       VARCHAR (3)    NOT NULL,
    [lineNum]      INT            NOT NULL,
    [remarksName]  VARCHAR (100)  NULL,
    [remarks]      VARCHAR (5000) NOT NULL,
    [statusFlag]   INT            DEFAULT ((1)) NOT NULL,
    [enterBy]      INT            NOT NULL,
    [enterDate]    DATETIME       DEFAULT (getdate()) NOT NULL,
    [updateBy]     INT            NULL,
    [updateDate]   DATETIME       NULL,
    PRIMARY KEY CLUSTERED ([rptRemarksId] ASC)
);


GO


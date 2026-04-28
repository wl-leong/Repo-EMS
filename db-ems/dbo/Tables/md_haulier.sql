CREATE TABLE [dbo].[md_haulier] (
    [haulierId]   INT          IDENTITY (1, 1) NOT NULL,
    [forwarderId] INT          NOT NULL,
    [haulier]     VARCHAR (50) NOT NULL,
    [statusFlag]  INT          CONSTRAINT [DF_md_haulier_statusFlag] DEFAULT ((1)) NULL,
    [enterBy]     INT          NULL,
    [enterDate]   DATETIME     CONSTRAINT [DF_md_haulier_enterDate] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_md_haulier] PRIMARY KEY CLUSTERED ([haulierId] ASC)
);


GO


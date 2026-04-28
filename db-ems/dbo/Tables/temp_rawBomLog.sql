CREATE TABLE [dbo].[temp_rawBomLog] (
    [rawBomLogId] BIGINT        IDENTITY (1, 1) NOT NULL,
    [upc]         VARCHAR (50)  NOT NULL,
    [rawBomUpc]   VARCHAR (50)  NOT NULL,
    [rawBomQty]   VARCHAR (20)  NOT NULL,
    [fileName]    VARCHAR (150) NOT NULL,
    [enterBy]     VARCHAR (20)  DEFAULT ('') NOT NULL,
    [enterDate]   DATETIME      DEFAULT (getdate()) NOT NULL
);


GO


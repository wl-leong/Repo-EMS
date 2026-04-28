CREATE TABLE [dbo].[md_log] (
    [logId]        BIGINT   IDENTITY (1, 1) NOT NULL,
    [log_datetime] DATETIME CONSTRAINT [DF__md_log__log_date__5070F446] DEFAULT (getdate()) NOT NULL,
    [log_string]   TEXT     NOT NULL,
    [log_createby] INT      NOT NULL,
    CONSTRAINT [PK_md_log] PRIMARY KEY CLUSTERED ([logId] ASC)
);


GO


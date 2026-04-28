CREATE TABLE [dbo].[temp_poReceivedLog] (
    [poReceivedLogId] BIGINT         IDENTITY (1, 1) NOT NULL,
    [companyId]       INT            NOT NULL,
    [recordType]      VARCHAR (2)    NOT NULL,
    [column1]         VARCHAR (50)   NOT NULL,
    [column2]         VARCHAR (20)   NOT NULL,
    [column3]         VARCHAR (2500) NULL,
    [column4]         VARCHAR (50)   NOT NULL,
    [column5]         VARCHAR (10)   NOT NULL,
    [column6]         VARCHAR (2500) NULL,
    [fileName]        VARCHAR (150)  NOT NULL,
    [enterBy]         INT            NOT NULL,
    [enterDate]       DATETIME       NOT NULL,
    PRIMARY KEY CLUSTERED ([poReceivedLogId] ASC)
);


GO


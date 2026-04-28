CREATE TABLE [dbo].[systemImage] (
    [ImageId]       INT             IDENTITY (1, 1) NOT NULL,
    [ImageCategory] VARCHAR (20)    NULL,
    [referenceId]   INT             NULL,
    [ImageName]     VARCHAR (50)    NULL,
    [ImageMimeType] VARCHAR (50)    NULL,
    [ImageBits]     VARBINARY (MAX) NULL,
    [createDate]    DATETIME        CONSTRAINT [DF_Table_1_createdDate] DEFAULT (getdate()) NULL,
    [createBy]      INT             NULL,
    [updateDate]    DATETIME        NULL,
    [updateBy]      INT             NULL,
    CONSTRAINT [PK_systemImage] PRIMARY KEY CLUSTERED ([ImageId] ASC)
);


GO


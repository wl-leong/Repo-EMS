CREATE TABLE [dbo].[md_State] (
    [stateId]   INT           IDENTITY (1, 1) NOT NULL,
    [stateName] VARCHAR (100) NOT NULL,
    [country]   INT           CONSTRAINT [DF__md_state__countr__1E6F845E] DEFAULT (NULL) NULL,
    [status]    INT           CONSTRAINT [DF__md_state__status__1F63A897] DEFAULT ('1') NOT NULL,
    CONSTRAINT [PK_md_State] PRIMARY KEY CLUSTERED ([stateId] ASC)
);


GO


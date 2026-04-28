CREATE TABLE [dbo].[temp_SoFilelog] (
    [sofilelog_Id]       BIGINT        IDENTITY (1, 1) NOT NULL,
    [companyId]          INT           NOT NULL,
    [customerName]       VARCHAR (50)  NOT NULL,
    [customerPO]         VARCHAR (20)  NOT NULL,
    [thirdPartyCustomer] VARCHAR (20)  NULL,
    [thirdPartyPO]       VARCHAR (20)  NULL,
    [poType]             VARCHAR (10)  NULL,
    [deptCode]           VARCHAR (10)  NULL,
    [csitemCode]         VARCHAR (20)  NOT NULL,
    [thirdPartyItemCode] VARCHAR (20)  NOT NULL,
    [customerSku]        VARCHAR (20)  NOT NULL,
    [ItemDescription]    VARCHAR (100) NOT NULL,
    [orderQty]           INT           NOT NULL,
    [shipDate]           DATE          NULL,
    [cancelDate]         DATE          NULL,
    [destinationlabel]   VARCHAR (20)  NOT NULL,
    [destination]        VARCHAR (100) NOT NULL,
    [fileLoaded]         VARCHAR (100) NOT NULL,
    [createDate]         DATETIME      CONSTRAINT [DF_so_filelog_enterDate] DEFAULT (getdate()) NOT NULL,
    [createBy]           VARCHAR (20)  NOT NULL,
    CONSTRAINT [PK_so_filelog] PRIMARY KEY CLUSTERED ([sofilelog_Id] ASC)
);


GO


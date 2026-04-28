CREATE TABLE [dbo].[shipmentAddress] (
    [shipmentAddressId]   BIGINT        IDENTITY (1, 1) NOT NULL,
    [shipmentId]          BIGINT        NOT NULL,
    [shipId]              VARCHAR (50)  NOT NULL,
    [locNo]               VARCHAR (20)  NOT NULL,
    [shipToName]          VARCHAR (100) NOT NULL,
    [shipToLabel]         VARCHAR (50)  NOT NULL,
    [shipToEmail]         VARCHAR (100) NOT NULL,
    [shipToContactNumber] VARCHAR (20)  NOT NULL,
    [shipToFaxNumber]     VARCHAR (20)  NOT NULL,
    [shipToAddressLine1]  VARCHAR (200) NOT NULL,
    [shipToAddressLine2]  VARCHAR (200) NOT NULL,
    [shipToCity]          VARCHAR (50)  NOT NULL,
    [shipToState]         VARCHAR (50)  NOT NULL,
    [shipToPostCode]      VARCHAR (10)  NOT NULL,
    [country]             INT           NOT NULL,
    [createDate]          DATETIME      NOT NULL,
    [createBy]            INT           NOT NULL,
    [updateDate]          DATETIME      NULL,
    [updateBy]            INT           NULL,
    CONSTRAINT [PK_shipmentAddress] PRIMARY KEY CLUSTERED ([shipmentAddressId] ASC)
);


GO


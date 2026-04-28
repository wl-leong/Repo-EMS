CREATE TABLE [dbo].[md_ShipToDestination] (
    [shipToId]            INT           IDENTITY (1, 1) NOT NULL,
    [companyId]           INT           NOT NULL,
    [customerId]          INT           NOT NULL,
    [warehouseId]         INT           NOT NULL,
    [addrType]            VARCHAR (20)  CONSTRAINT [DF_md_ShipToDestination_addrType] DEFAULT ('') NOT NULL,
    [locNo]               VARCHAR (20)  CONSTRAINT [DF_md_ShipToDestination_locNo] DEFAULT ('') NOT NULL,
    [shipToName]          VARCHAR (100) CONSTRAINT [DF_md_ShipToDestination_shipToName] DEFAULT ('') NOT NULL,
    [shipToLabel]         VARCHAR (50)  CONSTRAINT [DF_md_ShipToDestination_shipToLabel] DEFAULT ('') NOT NULL,
    [shipToEmail]         VARCHAR (100) CONSTRAINT [DF_md_ShipToDestination_shipToEmail] DEFAULT ('') NOT NULL,
    [shipToContactNumber] VARCHAR (20)  CONSTRAINT [DF_md_ShipToDestination_shipToContactNumber] DEFAULT ('') NOT NULL,
    [shipToFaxNumber]     VARCHAR (20)  CONSTRAINT [DF_md_ShipToDestination_shipToFaxNumber] DEFAULT ('') NOT NULL,
    [shipToAddressLine1]  VARCHAR (200) CONSTRAINT [DF_md_ShipToDestination_shipToAddressLine1] DEFAULT ('') NOT NULL,
    [shipToAddressLine2]  VARCHAR (200) CONSTRAINT [DF_md_ShipToDestination_shipToAddressLine2] DEFAULT ('') NOT NULL,
    [shipToCity]          VARCHAR (50)  CONSTRAINT [DF_md_ShipToDestination_shipToCity] DEFAULT ('') NOT NULL,
    [shipToState]         VARCHAR (50)  CONSTRAINT [DF_md_ShipToDestination_shipToState] DEFAULT ('') NOT NULL,
    [shipToPostCode]      VARCHAR (10)  CONSTRAINT [DF_md_ShipToDestination_shipToPostCode] DEFAULT ('') NOT NULL,
    [country]             INT           NOT NULL,
    [pod]                 VARCHAR (50)  NULL,
    [createDateTime]      DATETIME      CONSTRAINT [DF_md_ShipToDestination_createDateTime] DEFAULT (getdate()) NOT NULL,
    [updateDate]          DATETIME      NULL,
    [updateBy]            VARCHAR (10)  NULL,
    CONSTRAINT [PK_md_ShipToDestination_1] PRIMARY KEY CLUSTERED ([shipToId] ASC)
);


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'port of discharge', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'md_ShipToDestination', @level2type = N'COLUMN', @level2name = N'pod';


GO


CREATE TABLE [History].[soHeader] (
    [soheaderId]        BIGINT         NOT NULL,
    [companyId]         INT            NOT NULL,
    [customerId]        INT            NOT NULL,
    [supplierId]        INT            NOT NULL,
    [soName]            VARCHAR (50)   NOT NULL,
    [soDate]            DATE           NOT NULL,
    [customerPO]        VARCHAR (200)  NULL,
    [thirdParty]        VARCHAR (200)  NULL,
    [thirdPartyPO]      VARCHAR (500)  NULL,
    [shipToId]          INT            NOT NULL,
    [shipWay]           INT            NOT NULL,
    [vesselBooking]     VARCHAR (50)   NOT NULL,
    [portOfLanding]     VARCHAR (50)   NOT NULL,
    [portOfDestination] VARCHAR (50)   NOT NULL,
    [earlyShipDate]     DATE           NULL,
    [lateShipDate]      DATE           NULL,
    [soInvAmnt]         FLOAT (53)     NOT NULL,
    [soInvoice]         VARCHAR (200)  NOT NULL,
    [soInvoiceDate]     DATE           NULL,
    [reference1]        VARCHAR (500)  NULL,
    [reference2]        VARCHAR (500)  NULL,
    [reference3]        VARCHAR (500)  NULL,
    [soNote]            VARCHAR (1000) NOT NULL,
    [soStatus]          INT            NOT NULL,
    [createBy]          INT            NOT NULL,
    [createDate]        DATETIME       NOT NULL,
    [updateBy]          INT            NOT NULL,
    [updateDate]        DATETIME       NOT NULL,
    [apiStatus]         VARCHAR (10)   NULL,
    [poaDate]           DATETIME       NULL,
    [syncDate]          DATETIME       NULL,
    [ValidFrom]         DATETIME2 (7)  NOT NULL,
    [ValidTo]           DATETIME2 (7)  NOT NULL,
    [lastUpdatedDate]   DATETIME       NULL,
    [locNo]             VARCHAR (20)   DEFAULT ('') NULL
);


GO

CREATE CLUSTERED INDEX [ix_soHeader]
    ON [History].[soHeader]([ValidTo] ASC, [ValidFrom] ASC) WITH (DATA_COMPRESSION = PAGE);


GO


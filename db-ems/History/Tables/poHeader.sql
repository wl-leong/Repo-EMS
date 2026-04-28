CREATE TABLE [History].[poHeader] (
    [poID]                BIGINT          NOT NULL,
    [companyId]           INT             NOT NULL,
    [supplierId]          INT             NOT NULL,
    [poName]              VARCHAR (50)    NOT NULL,
    [poDate]              DATE            NOT NULL,
    [poReferenceId]       VARCHAR (50)    NOT NULL,
    [shipToId]            INT             NOT NULL,
    [shipVia]             VARCHAR (50)    NOT NULL,
    [vesselBooking]       VARCHAR (100)   NOT NULL,
    [portOfLanding]       VARCHAR (50)    NOT NULL,
    [portOfDestination]   VARCHAR (50)    NOT NULL,
    [poEarlyShipDate]     DATE            NULL,
    [poLateShipDate]      DATE            NULL,
    [poStatus]            INT             NOT NULL,
    [poNote]              VARCHAR (5000)  NOT NULL,
    [poNetTotal]          NUMERIC (18, 4) NOT NULL,
    [poDiscount]          NUMERIC (18, 4) NOT NULL,
    [poTax]               NUMERIC (18, 4) NOT NULL,
    [poGrossTotal]        NUMERIC (18, 4) NOT NULL,
    [uploadFile]          VARCHAR (200)   NOT NULL,
    [reference1]          VARCHAR (200)   NOT NULL,
    [reference2]          VARCHAR (200)   NOT NULL,
    [reference3]          VARCHAR (200)   NOT NULL,
    [poApprovalBy]        VARCHAR (20)    NULL,
    [poConfirmBy]         VARCHAR (20)    NULL,
    [poCancelBy]          VARCHAR (20)    NULL,
    [poApprovalDate]      DATETIME        NULL,
    [poConfirmDate]       DATETIME        NULL,
    [poCancelDate]        DATETIME        NULL,
    [enterDate]           DATETIME        NOT NULL,
    [enterBy]             VARCHAR (20)    NOT NULL,
    [updateDate]          DATETIME        NOT NULL,
    [updateBy]            VARCHAR (20)    NOT NULL,
    [ValidFrom]           DATETIME2 (7)   NOT NULL,
    [ValidTo]             DATETIME2 (7)   NOT NULL,
    [lastUpdatedDate]     DATETIME        NULL,
    [foreignCurrencyCode] VARCHAR (3)     NULL,
    [homeCurrencyCode]    VARCHAR (3)     NULL,
    [foreignCurrencyRate] NUMERIC (13, 4) NULL,
    [warehouseId]         INT             CONSTRAINT [DF_history_poHeader] DEFAULT ((0)) NOT NULL,
    [locNo]               VARCHAR (20)    DEFAULT ('') NULL
);


GO

CREATE CLUSTERED INDEX [ix_poHeader]
    ON [History].[poHeader]([ValidTo] ASC, [ValidFrom] ASC) WITH (DATA_COMPRESSION = PAGE);


GO


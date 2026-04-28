CREATE TABLE [dbo].[shipment] (
    [shipmentId]             BIGINT          NOT NULL,
    [lrHeaderId]             BIGINT          NULL,
    [invoiceId]              VARCHAR (50)    NULL,
    [customerName]           VARCHAR (100)   NOT NULL,
    [lrName]                 VARCHAR (50)    NULL,
    [PL]                     VARCHAR (50)    NULL,
    [shipId]                 VARCHAR (30)    NOT NULL,
    [shipmentDate]           DATETIME        NOT NULL,
    [shipmentStatus]         INT             NOT NULL,
    [soName]                 VARCHAR (50)    NULL,
    [customerPO]             VARCHAR (50)    NOT NULL,
    [pol]                    VARCHAR (100)   NULL,
    [pod]                    VARCHAR (100)   NULL,
    [containerTypeId]        INT             NOT NULL,
    [containerNo]            VARCHAR (100)   NULL,
    [ETD]                    DATE            NULL,
    [shipmentWeight]         DECIMAL (18, 4) NOT NULL,
    [bolTotalShipmentWeight] DECIMAL (18, 4) NOT NULL,
    [apiStatus]              VARCHAR (10)    NULL
);


GO


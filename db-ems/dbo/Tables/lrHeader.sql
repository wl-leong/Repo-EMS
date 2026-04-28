CREATE TABLE [dbo].[lrHeader] (
    [lrHeaderId]             BIGINT         IDENTITY (1, 1) NOT NULL,
    [companyId]              INT            NOT NULL,
    [supplierId]             INT            NOT NULL,
    [customerId]             INT            CONSTRAINT [DF_lrHeader_customerId] DEFAULT ((0)) NOT NULL,
    [lrName]                 VARCHAR (50)   NOT NULL,
    [lrDate]                 DATE           CONSTRAINT [DF_lrHeader_lrDate] DEFAULT (getdate()) NOT NULL,
    [lrRequestDate]          DATE           NULL,
    [lrShipDate]             DATE           NULL,
    [lrNote]                 VARCHAR (1000) CONSTRAINT [DF_lrHeader_lrNote] DEFAULT ('') NULL,
    [lrStatus]               INT            NOT NULL,
    [ref_customerLrHeaderId] BIGINT         NULL,
    [customerLrName]         VARCHAR (50)   CONSTRAINT [DF_lrHeader_lrReferenceId] DEFAULT ('') NULL,
    [enterBy]                INT            NOT NULL,
    [enterDate]              DATETIME       CONSTRAINT [DF_lrHeader_createDate] DEFAULT (getdate()) NOT NULL,
    [lrApprovalBy]           INT            NULL,
    [lrApprovalDate]         DATETIME       NULL,
    [lrConfirmDate]          DATETIME       NULL,
    [lrCancelBy]             INT            NULL,
    [lrCancelDate]           DATETIME       NULL,
    [updateBy]               INT            NULL,
    [updateDate]             DATETIME       CONSTRAINT [DF_lrHeader_updateDate] DEFAULT (getdate()) NULL,
    [apiStatus]              VARCHAR (20)   CONSTRAINT [DF_lrHeader_apiStatus] DEFAULT ('') NULL,
    [lraDate]                DATETIME       NULL,
    CONSTRAINT [PK_lrHeader] PRIMARY KEY CLUSTERED ([lrHeaderId] ASC)
);


GO


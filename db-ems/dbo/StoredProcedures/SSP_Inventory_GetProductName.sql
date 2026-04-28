-- =============================================
-- Author:		WL Leong
-- Create date: 2024-10-07
-- Used By:	    Use to generate all Inventory #

-- Description : Generate productname based on the naming convention

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-10-07	1.0			WL Leong	Initial
-- ==========================================================================================
/**
DECLARE @StringFormat varchar(50)

EXEC SSP_Inventory_GetProductName
2618,
N'{
	"inventory": [
		{
			"modelno": "22296",
			"color": "ESP",
			"description": "MS 3 SHELF BOOKCASE",
			"colorname": "ESPRESSO",
			"netheight": "1200MM",
			"netlength": "800MM",
			"netwidth": "500MM"
		}
	]
}', 
@StringFormat OUTPUT

SELECT @StringFormat

**/
CREATE PROCEDURE [dbo].[SSP_Inventory_GetProductName]
@inventoryTypeId INT,
@attributesJson NVARCHAR(MAX),
@StringFormat varchar(255) OUTPUT
AS 
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

    DECLARE @namingConvention VARCHAR(2000), @productName VARCHAR(1000)

	DROP TABLE IF EXISTS #inventoryAttributes;

	SELECT 
        ISNULL(modelNo, '') as modelno, 
        ISNULL(color, '') as color, 
        ISNULL(colorName, '') as colorName, 
        ISNULL(netHeight, '') as netHeight, 
        ISNULL(netLength, '') as netLength, 
        ISNULL(netWidth, '') as netWidth, 
        ISNULL(inventoryType, '') as inventoryType, 
        ISNULL(boardGrade, '') as boardGrade, 
        ISNULL(grammage, '') as grammage, 
        ISNULL(edgingType, '') as edgingType, 
        ISNULL(surface, '') as surface, 
        ISNULL(backerType, '') as backerType, 
        ISNULL(paperType, '') as paperType, 
        ISNULL(aiSize, '') as aiSize, 
        ISNULL(aiType, '') as aiType, 
        ISNULL(pages, '') as pages, 
        ISNULL(direction, '') as direction
	INTO #inventoryAttributes
	FROM  OPENJSON(@attributesJson, '$.inventory') 
   		WITH (
			modelNo VARCHAR(50)         N'$.modelno',
            color VARCHAR(50)           N'$.color',
            colorName VARCHAR(50)       N'$.colorname',
            netHeight VARCHAR(50)       N'$.netheight',
            netLength VARCHAR(50)       N'$.netlength',
            netWidth VARCHAR(50)        N'$.netwidth',
            inventoryType VARCHAR(50)   N'$.inventorytype',
            boardGrade VARCHAR(50)      N'$.boardgrade',
            grammage  VARCHAR(50)       N'$.grammage',
            edgingType  VARCHAR(50)     N'$.edgingtype',
            surface  VARCHAR(50)        N'$.surface',
            backerType  VARCHAR(50)     N'$.backertype',
            paperType  VARCHAR(50)      N'$.papertype',
            aiSize  VARCHAR(50)         N'$.aisize',
            aiType  VARCHAR(50)         N'$.aitype',
            pages  VARCHAR(50)          N'$.pages',
            direction  VARCHAR(50)      N'$.direction'
		)
 
    SELECT @namingConvention = namingConvention
    FROM md_InventoryType
    WHERE inventoryTypeId = @inventoryTypeId
 
    SELECT @productName = 
        REPLACE(
        REPLACE(
        REPLACE(
        REPLACE(
        REPLACE(
        REPLACE(
        REPLACE(
        REPLACE(
        REPLACE(
        REPLACE(
            REPLACE(
            REPLACE(
            REPLACE(
            REPLACE(
            REPLACE(
            REPLACE(
            REPLACE(@namingConvention, 
                    '[modelno]', modelNo), 
                    '[color]', color),
                    '[colorname]', colorName),
                        '[netHeight]', netHeight),
                        '[netLength]', netLength),
                        '[netWidth]', netWidth),
                        '[inventoryType]', inventoryType),
                        '[boardgrade]', boardgrade),
                        '[grammage]', grammage),
                        '[edgingtype]', edgingtype),
                        '[surface]', surface),
                        '[backertype]', backertype),
                        '[papertype]', papertype),
                        '[aisize]', aisize),
                        '[aitype]', aitype),
                        '[pages]', pages),
                        '[direction]', direction)
    FROM #inventoryAttributes
 
    SET @StringFormat = REPLACE(REPLACE(REPLACE(@productName, '[space]', ' '), '[,]', ','), '+', '')

 
END

GO


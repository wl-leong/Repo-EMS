-- =============================================
-- Author:		ZY Wong
-- Create date: 2023-10-27
-- Description:	Keep company info related table to be updated
-- Used By:		

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-07-11   2.0         ZY Wong     Add begin trans & commit trans, standardize returnMessage
-- 2023-10-27	1.0			ZY Wong		Initial version
-- =============================================
-- exec  [dbo].[SSP_UpdateCompanyInfo] 10
CREATE PROCEDURE [dbo].[SSP_Company_UpdateInfo]
@companyId INT 
AS
BEGIN
SET NOCOUNT ON
SET XACT_ABORT ON
	BEGIN TRY
		
		--DECLARE @companyId INT = 10

		DROP TABLE IF EXISTS #coInfo;

		SELECT companyName, companyShortCode, registerNo, address, addressLine2, city, state, postcode, country, telephoneNumber, faxNumber, websiteUrl, emailAddress, contactPersonName, contactPersonPhoneNumber, contactPersonEmail, status as coStatus
		INTO #coInfo
		FROM md_Company
		WHERE companyId = @companyId

        BEGIN TRANSACTION

		UPDATE md_Customer SET
			customerName = companyName,
			customerShortCode = companyShortCode,
			customerAddressName = companyName,
			customerAddress = address,
			customerAddressLine2 = addressLine2,
			customerCity = city,
			customerStates = state,
			customerPostcode = postcode,
			customerCountry = country,
			customerContactNumber = telephoneNumber,
			customerFaxNumber = faxNumber,
			customerEmail = emailAddress,
			status = coStatus
		FROM #coInfo
		WHERE internal_branchId = @companyId

		UPDATE md_Supplier SET
			supplierCompanyName = companyName,
			supplierCompanyRegno = registerNo,
			supplierAddressName = companyName,
			supplierAddress = address,
			supplierAddressLine2 = addressLine2,
			supplierCity = city,
			supplierStates = state,
			supplierPostcode = postcode,
			supplierCountry = country,
			supplierContactNumber = telephoneNumber,
			supplierFaxNumber = faxNumber,
			supplierEmail = emailAddress,
			supplierContactPerson = contactPersonName,
			supplierContactPersonPhoneNumber = contactPersonPhoneNumber,
			supplierContactPersonEmail = contactPersonEmail,
			status = coStatus
		FROM #coInfo
		WHERE internal_branchId = @companyId

        COMMIT TRANSACTION

        RETURN 0
	END TRY

	BEGIN CATCH	
	
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END

		SELECT '_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as returnMessage

        RETURN -1
	END CATCH
END

GO


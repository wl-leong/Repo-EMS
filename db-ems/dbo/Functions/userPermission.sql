CREATE FUNCTION dbo.userPermission(@userId INT, @CompanyId INT, @menuLevel2 INT)
RETURNS TABLE
AS
RETURN
(
	SELECT crf.functionAdd, crf.functionEdit, crf.functionDelete
	FROM companyRole cr
		INNER JOIN companyRoleFunction crf
			ON cr.companyRoleId = crf.companyRoleId
		INNER JOIN md_role r
			ON cr.roleId = r.roleId
		INNER JOIN userRole usrr
			ON cr.companyRoleId = usrr.userroleCOmpanyRoleId
	WHERE usrr.userId = @userId
		and crf.menuLevel2Id = @menuLevel2
		and cr.companyId = @CompanyId
);

GO


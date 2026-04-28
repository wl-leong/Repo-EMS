CREATE FUNCTION [dbo].[NumbersTable] (
  @fromNumber int,
  @toNumber int,
  @byStep int
)
RETURNS @NumbersTable TABLE (i int)
AS
BEGIN

  WITH CTE_NumbersTable AS (

    SELECT @fromNumber AS i

    UNION ALL

    SELECT i + @byStep
    FROM CTE_NumbersTable
    WHERE
      (i + @byStep) <= @toNumber
  )
  INSERT INTO @NumbersTable
  SELECT i FROM CTE_NumbersTable OPTION (MAXRECURSION 0)

  RETURN;
END

GO


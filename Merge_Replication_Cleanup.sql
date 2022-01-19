--Script used in clearing Merge Replication resolved conflicts

--Get List of resolved conflicts
SELECT MA.conflict_table, CI.rowguid, CI.origin_datasource
      INTO #resolved_conflicts
      FROM dbo.MSmerge_conflicts_info CI
      JOIN sysmergearticles MA
      ON CI.tablenick = MA.nickname

--Perform Cleaup
DECLARE @conflict_table nvarchar(255)
DECLARE @rowguid uniqueidentifier
DECLARE @origin_datasource nvarchar(255)

DECLARE conflict_cursor CURSOR FOR
	SELECT conflict_table, rowguid, origin_datasource FROM #resolved_conflicts
		OPEN conflict_cursor;
			FETCH NEXT FROM conflict_cursor INTO @conflict_table, @rowguid, @origin_datasource;
			WHILE @@FETCH_STATUS = 0

				BEGIN
					EXEC sp_deletemergeconflictrow
					  @conflict_table = @conflict_table,
					  @rowguid = @rowguid,
					  @origin_datasource = @origin_datasource

				   FETCH NEXT FROM conflict_cursor
				   INTO @conflict_table, @rowguid, @origin_datasource;
				END
		CLOSE conflict_cursor;
		DEALLOCATE conflict_cursor;
DROP table #resolved_conflicts
GO

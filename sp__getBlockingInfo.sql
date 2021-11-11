CREATE PROCEDURE [dbo].[sp__getBlockingInfo]
(@BlockingFromMinutes TINYINT=1)
AS

BEGIN

SET NOCOUNT ON

SELECT spid, blocked, REPLACE (REPLACE (T.text, CHAR(10), ' '), CHAR (13), ' ' ) AS batch, hostname,program_name,loginame, (waittime/1000/60) AS BlockingFromMinutes
INTO #T
FROM sys.sysprocesses R CROSS APPLY sys.dm_exec_sql_text(R.sql_handle) T

;WITH blockers (spid, blocked, LEVEL, batch, hostname,program_name,loginame,BlockingFromMinutes)
AS
(
	SELECT spid, blocked, CAST (REPLICATE ('0', 4-LEN (CAST (spid AS VARCHAR))) + CAST (spid AS VARCHAR) AS VARCHAR (1000)) AS LEVEL, batch, hostname,program_name,loginame,BlockingFromMinutes FROM #T R
	WHERE (blocked = 0 OR blocked = spid)
	AND EXISTS (SELECT * FROM #T R2 WHERE R2.blocked = R.spid AND R2.blocked <> R2.spid)
UNION ALL
	SELECT R.spid, R.blocked, CAST (blockers.LEVEL + RIGHT (CAST ((1000 + R.spid) AS VARCHAR (100)), 4) AS VARCHAR (1000)) AS LEVEL, R.batch, R.hostname,R.program_name,R.loginame,R.BlockingFromMinutes FROM #T AS R INNER JOIN blockers ON R.blocked = blockers.spid WHERE R.blocked > 0 AND R.blocked <> R.spid
)

select loginame AS Login,hostname AS Host,program_name AS Program,spid AS SessionId
		,BlockingFromMinutes
		,CASE WHEN blocked=0 then 'None' ELSE CAST(blocked AS VARCHAR(16)) END BlockedBy
		,SUBSTRING(batch,0,1024) AS Query
		,CASE WHEN blocked = 0 AND (select MAX(BlockingFromMinutes) from blockers AS A where A.blocked = B.spid) < 5
				THEN 'The session is blocking other queries from <5 mins, you may want to wait for some more time, before you kill it.' 
			  WHEN blocked = 0 AND  (select MAX(BlockingFromMinutes) from blockers AS A where A.blocked = B.spid) >= 5
				THEN 'The session is blocking other queries from last ' + cast ((select MAX(BlockingFromMinutes) from blockers AS A where A.blocked = B.spid) as varchar) + ' minutes, kill the session and revisit the query to fine tune it' 
			  ELSE 'None' END RecommendedAction
from blockers AS B where (B.spid IN 
			(select A.blocked from blockers AS A 
			where program_name <> '***********Exclude any Program Name********' and blocked <> 0 and BlockingFromMinutes > @BlockingFromMinutes
			group by blocked
			having count(1) > 0) 
		
			OR 

			B.blocked IN 
						(select A.blocked from blockers AS A 
						where program_name <> '***********Exclude any Program Name********' and blocked <> 0 and BlockingFromMinutes > @BlockingFromMinutes
						group by blocked
						having count(1) > 0)
			) AND B.program_name <> '***********Exclude any Program Name********'

DROP TABLE #T
END

DECLARE @query1 Nvarchar(MAX)
DECLARE @query2 Nvarchar(MAX)
DECLARE @DBName varchar(256)

declare DBName cursor for
select name from sys.databases where name in ('DatabaseName') order by name asc

Open DBName
FETCH NEXT from DBName into @DBName

WHILE @@FETCH_STATUS = 0      
BEGIN 

set @query1='use ['+@DBName+'];
select * from 
(
SELECT  
	db_name() as DatabaseName,
    [UserType] = CASE princ.[type]
                    WHEN ''S'' THEN ''SQL User''
                    WHEN ''U'' THEN ''Windows User''
                 END,  
    [DatabaseUserName] = princ.[name],       
    [Role] = null,      
    [PermissionType] = perm.[permission_name],       
    [PermissionState] = perm.[state_desc],       
    [ObjectType] = obj.type_desc,--perm.[class_desc],       
    [ObjectName] = OBJECT_NAME(perm.major_id)
FROM    
    --database user
    sys.database_principals princ  
LEFT JOIN
    --Login accounts
    sys.login_token ulogin on princ.[sid] = ulogin.[sid]
LEFT JOIN        
    --Permissions
    sys.database_permissions perm ON perm.[grantee_principal_id] = princ.[principal_id]
LEFT JOIN
    --Table columns
    sys.columns col ON col.[object_id] = perm.major_id 
                    AND col.[column_id] = perm.[minor_id]
LEFT JOIN
    sys.objects obj ON perm.[major_id] = obj.[object_id]
WHERE 
    princ.[type] in (''S'',''U'') 
	and (perm.[permission_name] is not null and perm.[state_desc] is not null )
UNION
--List all access provisioned to a sql user or windows user/group through a database or application role
SELECT  
	db_name() as DatabaseName,
    [UserType] = CASE memberprinc.[type]
                    WHEN ''S'' THEN ''SQL User''
                    WHEN ''U'' THEN ''Windows User''
                 END, 
    [DatabaseUserName] = memberprinc.[name],   
    [Role] = roleprinc.[name],      
    [PermissionType] = perm.[permission_name],       
    [PermissionState] = perm.[state_desc],       
    [ObjectType] = obj.type_desc,--perm.[class_desc],   
    [ObjectName] = OBJECT_NAME(perm.major_id)
FROM    
    --Role/member associations
    sys.database_role_members members
JOIN
    --Roles
    sys.database_principals roleprinc ON roleprinc.[principal_id] = members.[role_principal_id]
JOIN
    --Role members (database users)
    sys.database_principals memberprinc ON memberprinc.[principal_id] = members.[member_principal_id]
LEFT JOIN
    --Login accounts
    sys.login_token ulogin on memberprinc.[sid] = ulogin.[sid]
LEFT JOIN        
    --Permissions
    sys.database_permissions perm ON perm.[grantee_principal_id] = roleprinc.[principal_id]
LEFT JOIN
    --Table columns
    sys.columns col on col.[object_id] = perm.major_id 
                    AND col.[column_id] = perm.[minor_id]
LEFT JOIN
    sys.objects obj ON perm.[major_id] = obj.[object_id]

UNION
--List all access provisioned to the public role, which everyone gets by default
SELECT  
	db_name() as DatabaseName,
    [UserType] = ''{All Users}'', 
    [DatabaseUserName] = ''{All Users}'',       
    [Role] = roleprinc.[name],      
    [PermissionType] = perm.[permission_name],       
    [PermissionState] = perm.[state_desc],       
    [ObjectType] = obj.type_desc,--perm.[class_desc],  
    [ObjectName] = OBJECT_NAME(perm.major_id)
FROM    
    --Roles
    sys.database_principals roleprinc
LEFT JOIN        
    --Role permissions
    sys.database_permissions perm ON perm.[grantee_principal_id] = roleprinc.[principal_id]
LEFT JOIN
    --Table columns
    sys.columns col on col.[object_id] = perm.major_id 
                    AND col.[column_id] = perm.[minor_id]                   
JOIN 
    --All objects   
    sys.objects obj ON obj.[object_id] = perm.[major_id]
WHERE
    --Only roles
    roleprinc.[type] = ''R'' AND
    --Only public role
    roleprinc.[name] = ''public'' AND
    --Only objects of ours, not the MS objects
    obj.is_ms_shipped = 0 )T 
	where T.DatabaseUserName NOT IN (''Mention_Users_Which_You_Dont Want to Show'')
ORDER BY
    2,3,4,5'

	exec sp_executesql @query1

FETCH Next from DBName into @DBName
END

Close DBName
DEALLOCATE DBName

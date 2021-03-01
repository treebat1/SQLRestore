
--future development:   add support for differential restore.

sp_helpdb 'SSISDB'

exec msdb.dbo.RestoreScriptingUtility @DBName = 'SSISDB', @TargetDBName = 'SSISDB_OLDDEV'
, @data_file_path = 'J:\Data01\'
, @client_folder = 'SSISDB_OLDDEV', @log_file_path = 'J:\Log\', @RecoveryOption = 'NORECOVERY'

---------


use msdb 
go


if exists (select 1
				from sys.objects o
				join sys.schemas s on o.schema_id = s.schema_id
				where o.name = 'RestoreScriptingUtility'
				and s.name = 'dbo')
drop procedure dbo.RestoreScriptingUtility
go

create procedure dbo.RestoreScriptingUtility (@DBName nvarchar(150)
, @TargetDBName nvarchar(150)
, @data_file_path NVARCHAR(512) = 'J:\Data01\'
, @client_folder nvarchar(512)
, @log_file_path NVARCHAR(512) = 'J:\Log\'
, @RecoveryOption nvarchar(50) = 'RECOVERY')
as


/* Created by Christopher Riley */

set nocount on

Declare @BackupFiles nvarchar(4000), @RestoreFileList nvarchar(4000)
, @RestoreStatement nvarchar(4000), @MoveFiles nvarchar(4000)

declare @i int --counter for while loop
declare @maxIdid int  --for while loop

DECLARE @filelist TABLE 
(LogicalName NVARCHAR(128) NOT NULL
, PhysicalName NVARCHAR(260) NOT NULL
, [Type] NCHAR(1) NOT NULL
, FileGroupName NVARCHAR(120) NULL
, Size NUMERIC(20, 0) NOT NULL
, MaxSize NUMERIC(20, 0) NOT NULL
, FileID BIGINT NULL
, CreateLSN NUMERIC(25,0) NULL
, DropLSN NUMERIC(25,0) NULL
, UniqueID UNIQUEIDENTIFIER NULL
, ReadOnlyLSN NUMERIC(25,0) NULL 
, ReadWriteLSN NUMERIC(25,0) NULL
, BackupSizeInBytes BIGINT NULL
, SourceBlockSize INT NULL
, FileGroup INT NULL
, LogGroupGUID UNIQUEIDENTIFIER NULL
, DfferentialBaseLSN NUMERIC(25,0)NULL
, DifferentialBaseGUID UNIQUEIDENTIFIER NULL
, IsReadOnly BIT NULL
, IsPresent BIT NULL
, TDEThumbprint VARBINARY(32) NULL) 

--SET @DBName = ''
--set @data_file_path
--SET @log_file_path  = 'F:\SQLLogs\'
--set @RecoveryOption = 'RECOVERY'

SET @data_file_path = @data_file_path + @client_folder + '\'

--Get last full backup:
SELECT @BackupFiles=Coalesce(@BackupFiles + ',', '') + 'DISK = N'''+physical_device_name+''''
FROM msdb.dbo.backupset S
JOIN msdb.dbo.backupmediafamily M ON M.media_set_id=S.media_set_id
WHERE backup_set_id = ( SELECT max(backup_set_id)
                    FROM msdb..backupset S
                    JOIN msdb..backupmediafamily M ON M.media_set_id=S.media_set_id
                    WHERE S.database_name = @DBName and Type = 'D')

SELECT @RestoreFileList= 'RESTORE FILELISTONLY FROM ' + @BackupFiles

IF (@@microsoftversion / 0x1000000) & 0xff >= 10 --TDE capability
Begin
    INSERT into @filelist (LogicalName,PhysicalName,Type,FileGroupName,Size,MaxSize,FileID,CreateLSN,DropLSN,UniqueID,ReadOnlyLSN,ReadWriteLSN,BackupSizeInBytes,SourceBlockSize
	,FileGroup,LogGroupGUID,DfferentialBaseLSN,DifferentialBaseGUID,IsReadOnly,IsPresent,TDEThumbprint)
    EXEC (@RestoreFileList)
End
Else
Begin
    INSERT into @filelist (LogicalName,PhysicalName,Type,FileGroupName,Size,MaxSize,FileID,CreateLSN,DropLSN,UniqueID,ReadOnlyLSN,ReadWriteLSN,BackupSizeInBytes,SourceBlockSize
	,FileGroup,LogGroupGUID,DfferentialBaseLSN,DifferentialBaseGUID,IsReadOnly,IsPresent)
    EXEC (@RestoreFileList)
End

--next version, do a count on filename, any >1 put in alternate data/log location.
SELECT  @MoveFiles= Coalesce(@MoveFiles + char(13) + char(10) + ',' ,'') + 'MOVE N''' + LogicalName + ''' to N''' +
    Case when type = 'D' and FileGroupName = 'Similarity_Lists' then @data_file_path+'Modeling\'+Right(physicalname, charindex('\',reverse(physicalname),1)-1)
	when type = 'D' Then @data_file_path+Right(physicalname, charindex('\',reverse(physicalname),1)-1)
    when type = 'L' Then @log_file_path+Right(physicalname, charindex('\',reverse(physicalname),1)-1)
    Else 'Full Text - code not complete'
    END
    +''''
From @filelist

SELECT @RestoreStatement='RESTORE DATABASE ' + @TargetDBName + CHAR(13) + char(10)
+ 'FROM ' + @BackupFiles + CHAR(13) + char(10)
+ 'WITH ' + @MoveFiles + char(13) + char(10)
+ ',' + @RecoveryOption + char(13) + char(10)
+ ',STATS = 10;' + char(13)+ char(10)+ char(13) + char(10)

Print @RestoreStatement 

------------------------------------------------
/* Last differential backup section */

--reinitialize variables
set @BackupFiles = NULL
set @MoveFiles = NULL
delete from @filelist

SELECT @BackupFiles=Coalesce(@BackupFiles + ',', '') + 'DISK = N'''+replace(physical_device_name,'Backup\\','Backup\')+''''
FROM msdb.dbo.backupset S
JOIN msdb.dbo.backupmediafamily M ON M.media_set_id=S.media_set_id
WHERE s.backup_set_id = (SELECT max(s3.backup_set_id)
						FROM msdb.dbo.backupset S3
						JOIN msdb.dbo.backupmediafamily M3 ON M3.media_set_id=S3.media_set_id
						WHERE S3.database_name = s.database_name 
						and s3.Type = 'I')
AND s.database_backup_lsn = (SELECT max(s2.first_lsn)
							FROM msdb.dbo.backupset S2
							JOIN msdb.dbo.backupmediafamily M2 ON M2.media_set_id=S2.media_set_id
							WHERE S2.database_name = S.database_name 
							and s2.Type = 'D')
and s.type = 'I'
and s.database_name = @DBName


SELECT @RestoreFileList= 'RESTORE FILELISTONLY FROM ' + @BackupFiles

IF (@@microsoftversion / 0x1000000) & 0xff >= 10 --TDE capability
Begin
    INSERT into @filelist (LogicalName,PhysicalName,Type,FileGroupName,Size,MaxSize,FileID,CreateLSN,DropLSN,UniqueID,ReadOnlyLSN,ReadWriteLSN,BackupSizeInBytes,SourceBlockSize,FileGroup,LogGroupGUID,DfferentialBaseLSN,DifferentialBaseGUID,IsReadOnly,IsPresent,TDEThumbprint)
    EXEC (@RestoreFileList)
End
Else
Begin
    INSERT into @filelist (LogicalName,PhysicalName,Type,FileGroupName,Size,MaxSize,FileID,CreateLSN,DropLSN,UniqueID,ReadOnlyLSN,ReadWriteLSN,BackupSizeInBytes,SourceBlockSize,FileGroup,LogGroupGUID,DfferentialBaseLSN,DifferentialBaseGUID,IsReadOnly,IsPresent)
    EXEC (@RestoreFileList)
End

SELECT  @MoveFiles= Coalesce(@MoveFiles + char(13) + char(10) + ',' ,'') + 'MOVE N''' + LogicalName + ''' to N''' +
    Case when type = 'D' and FileGroupName = 'Similarity_Lists' then @data_file_path+'Modeling\'+Right(physicalname, charindex('\',reverse(physicalname),1)-1)
	when type = 'D' Then @data_file_path+Right(physicalname, charindex('\',reverse(physicalname),1)-1)
    when type = 'L' Then @log_file_path+Right(physicalname, charindex('\',reverse(physicalname),1)-1)
    Else 'Full Text - code not complete'
    END
    +''''
From @filelist


SELECT @RestoreStatement='RESTORE DATABASE ' + @TargetDBName + char(13) + char(10) + 'FROM ' + @BackupFiles + char(13) + char(10) + 'WITH ' + @MoveFiles + char(13) + char(10) + ',STATS = 20 ' +char(13) + char(10) 
+ ',NORECOVERY' 
+ char(13) + char(10) + char(13) + char(10)

Print @RestoreStatement



----------------------------------------------------------------------------------------

--Log File Section

--reinitialize variables
set @BackupFiles = NULL
set @MoveFiles = NULL
delete from @filelist


create table #tempBackupFileName
(idid int not null identity(1,1)
, BackupFileName varchar(1000))

insert into #tempBackupFileName
(BackupFileName)
SELECT physical_device_name
FROM msdb.dbo.backupset S
JOIN msdb.dbo.backupmediafamily M ON M.media_set_id=S.media_set_id
WHERE S.database_name = @DBName 
AND database_backup_lsn = (SELECT max(s2.first_lsn)
							FROM msdb.dbo.backupset S2
							JOIN msdb.dbo.backupmediafamily M2 ON M2.media_set_id=S2.media_set_id
							WHERE S2.database_name = S.database_name 
							and s2.Type = 'D')
AND last_lsn > (SELECT coalesce(max(last_lsn),0)
							FROM msdb.dbo.backupset S2
							JOIN msdb.dbo.backupmediafamily M2 ON M2.media_set_id=S2.media_set_id
							WHERE S2.database_name = S.database_name 
							and s2.Type = 'I')
and s.type = 'L'
ORDER BY backup_set_id

select top 1 @BackupFiles = Coalesce(@BackupFiles + ',', '') + 'DISK = N'''+replace(BackupFileName,'Backup\\','Backup\')+''''
from #tempBackupFileName


SELECT @RestoreFileList= 'RESTORE FILELISTONLY FROM ' + @BackupFiles


IF (@@microsoftversion / 0x1000000) & 0xff >= 10 --TDE capability
Begin
    INSERT into @filelist (LogicalName,PhysicalName,Type,FileGroupName,Size,MaxSize,FileID,CreateLSN,DropLSN,UniqueID,ReadOnlyLSN,ReadWriteLSN,BackupSizeInBytes,SourceBlockSize,FileGroup,LogGroupGUID,DfferentialBaseLSN,DifferentialBaseGUID,IsReadOnly,IsPresent,TDEThumbprint)
    EXEC (@RestoreFileList)
End
Else
Begin
    INSERT into @filelist (LogicalName,PhysicalName,Type,FileGroupName,Size,MaxSize,FileID,CreateLSN,DropLSN,UniqueID,ReadOnlyLSN,ReadWriteLSN,BackupSizeInBytes,SourceBlockSize,FileGroup,LogGroupGUID,DfferentialBaseLSN,DifferentialBaseGUID,IsReadOnly,IsPresent)
    EXEC (@RestoreFileList)
End

SELECT  @MoveFiles= Coalesce(@MoveFiles + char(13) + char(10) + ',' ,'') + 'MOVE N''' + LogicalName + ''' to N''' +
    Case when type = 'D' and FileGroupName = 'Similarity_Lists' then @data_file_path+'Modeling\'+Right(physicalname, charindex('\',reverse(physicalname),1)-1)
	when type = 'D' Then @data_file_path+Right(physicalname, charindex('\',reverse(physicalname),1)-1)
    when type = 'L' Then @log_file_path+Right(physicalname, charindex('\',reverse(physicalname),1)-1)
    Else 'Full Text - code not complete'
    END
    +''''
From @filelist

select @maxIdid = MAX(idid) from #tempBackupFileName


set @i = 1

WHILE @i <= @maxIdid   
BEGIN  
	select @BackupFiles = BackupFileName from #tempBackupFileName where idid = @i
	SELECT @RestoreStatement='RESTORE LOG ' + @TargetDBName + char(13) + char(10)
	+ 'FROM DISK = N''' + @BackupFiles + '''' + CHAR(13) + char(10)
	+ 'WITH ' + @MoveFiles + char(13) + char(10)
	+ ',' + @RecoveryOption + char(13) + char(10)
	+ ',STATS = 10;' + char(13) + char(10) + char(13) + char(10)
	Print @RestoreStatement		
	set @i = @i + 1
END   

drop table #tempBackupFileName
go



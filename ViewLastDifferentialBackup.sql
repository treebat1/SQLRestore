SELECT name, backup_start_date, backup_finish_date, physical_device_name, *
FROM msdb.dbo.backupset S
JOIN msdb.dbo.backupmediafamily M ON M.media_set_id=S.media_set_id
WHERE backup_set_id = ( SELECT max(backup_set_id)
                    FROM msdb..backupset S
                    JOIN msdb..backupmediafamily M ON M.media_set_id=S.media_set_id
                    WHERE S.database_name = 'UBSP_Content_CL_Bi' and Type = 'I')
and m.mirror = 0
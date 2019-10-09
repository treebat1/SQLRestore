WITH LastRestores AS
(
SELECT
    DatabaseName = [d].[name] 
    --,[d].[create_date] 
    --,[d].[compatibility_level] 
    , r.restore_date
	, r.destination_database_name
	, r.[user_name]
	, r.restore_type
	, r.[replace]
	--, r.[recovery]
	--, restart
	--, stop_at
	--, device_count
	--, stop_at_mark_name, stop_before
	--,expiration_date
	--, b.name, description
	--, time_zone, first_lsn, last_lsn, checkpoint_lsn, database_backup_lsn
	--, b.database_creation_date
	--, b.backup_start_date
	, b.backup_finish_date
	, b.[type]
	--, database_version, backup_size, database_name, server_name, machine_name
	--, is_password_protected
	--, b.recovery_model
	--, has_bulk_logged_data, is_snapshot
	--, is_readonly, is_single_user
	--, b.has_backup_checksums
	--, is_damaged, begins_log_chain, is_force_offline, is_copy_only, compressed_backup_size
	--, m.media_set_id, family_sequence_number, media_family_id, media_count
	--, logical_device_name
	--, m.physical_device_name
	--, m.device_type
	--, physical_block_size
	--, m.mirror
    ,RowNum = ROW_NUMBER() OVER (PARTITION BY d.Name ORDER BY r.[restore_date] DESC)
FROM master.sys.databases d
LEFT OUTER JOIN msdb.dbo.[restorehistory] r 
ON r.[destination_database_name] = d.Name
left outer join msdb.dbo.backupset b
on r.backup_set_id = b.backup_set_id
left outer JOIN msdb.dbo.backupmediafamily M ON b.media_set_id=m.media_set_id
where --d.name = 'AboutThisServer'
--and 
r.restore_type in ('D','L')
)
SELECT *
FROM [LastRestores]
WHERE restore_date > '2019-05-05'
--and [RowNum] <= 10
order by restore_date
--select percent_complete, DATEDIFF(HOUR, start_time, GETDATE()) AS Hours_Running
--, command, start_time, database_id, *
--from sys.dm_exec_requests
--where command like 'restore%'





select percent_complete, DATEDIFF(HOUR, start_time, GETDATE()) AS Hours_Running, (DATEDIFF(HOUR, start_time, GETDATE())/percent_complete) * (100 - percent_complete) AS Hours_Left
, (DATEDIFF(HOUR, start_time, GETDATE())/percent_complete) AS Hours_Per_Percentage, command, start_time
from sys.dm_exec_requests
where command like 'restore%' 






--sp_who2 active

--select * 
--from sys.databases
--ORDER BY name

--KILL 908

--sp_spaceused 'User_Info'

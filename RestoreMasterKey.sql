USE master;
go
RESTORE MASTER KEY   
    FROM FILE = 'D:\TDE\MasterKey'   
    DECRYPTION BY PASSWORD = ''
	Encryption by password = ''-- 'New Password';
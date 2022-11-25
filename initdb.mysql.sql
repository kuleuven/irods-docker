CREATE DATABASE irods;
ALTER DATABASE irods CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER 'irods'@'%' IDENTIFIED WITH mysql_native_password BY 'irods';
GRANT ALL ON irods.* TO 'irods'@'%';
SET GLOBAL TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET GLOBAL log_bin_trust_function_creators = 1;

CREATE DATABASE IF NOT EXISTS local_library;
CREATE IF NOT EXISTS USER local_library WITH PASSWORD 'asdf1234';
GRANT ALL PRIVILEGES ON DATABASE local_library TO local_library;
ALTER USER local_library CREATEDB;
#!/bin/bash

set -e

cat << EOF | psql -h localhost -U postres
CREATE DATABASElocal_library;
CREATE USER local_library WITH PASSWORD 'asdf1234';
GRANT ALL PRIVILEGES ON DATABASE local_library TO local_library;
ALTER USER local_library CREATEDB;
EOF
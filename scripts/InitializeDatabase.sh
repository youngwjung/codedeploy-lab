#!/bin/bash

set -e

psql -h localhost -U postres < ./init-db.sql
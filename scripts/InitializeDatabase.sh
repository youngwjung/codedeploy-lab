#!/bin/bash

set -e

psql -h localhost -U postres < /opt/django-locallibrary-tutorial/scripts/init-db.sql
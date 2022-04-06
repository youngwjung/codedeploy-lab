#!/bin/bash

set -e

source /opt/venv/bin/activate
python /opt/django-locallibrary-tutorial/manage.py makemigrations --noinput
python /opt/django-locallibrary-tutorial/manage.py migrate --noinput
python /opt/django-locallibrary-tutorial/manage.py collectstatic --noinput

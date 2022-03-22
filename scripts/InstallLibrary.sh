#!/bin/bash

cd /opt && git clone https://github.com/octo16/django-locallibrary-tutorial.git

source /opt/venv/bin/activate
sudo pip install -r requirements.txt

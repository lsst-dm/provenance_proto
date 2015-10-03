#!/bin/sh

mysql -e "DROP DATABASE provProto"
mysql -e "CREATE DATABASE provProto"
mysql provProto < catalogSchema.sql
mysql provProto < provSchema.sql
./testProvProto.py

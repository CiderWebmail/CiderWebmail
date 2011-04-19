#!/bin/sh
PERL5LIB="./lib:$PERL5LIB" dbicdump -o dump_directory=./lib CiderWebmail::DB dbi:SQLite:root/var/user_settings.sql

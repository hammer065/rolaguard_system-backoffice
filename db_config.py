#!/usr/local/bin/python
from configparser import RawConfigParser
import os 
 
def config(filename='database.ini', section='postgresql'):
  db = {}
  if "DB_NAME" in os.environ:
    print('getting db settings from environment variables')
    db['host'] = os.environ['DB_HOST']
    db['port'] = os.environ['DB_PORT']
    db['database'] = os.environ['DB_NAME']
    db['user'] = os.environ['DB_USERNAME']
    db['password'] = os.environ['DB_PASSWORD']
  else:
    print('getting db settings from config file')
    # create a parser
    parser = RawConfigParser()
    # read config file
    parser.read(filename)

    # get section, default to postgresql

    if parser.has_section(section):
        params = parser.items(section)
        for param in params:
            db[param[0]] = param[1]
    else:
        raise Exception('Section {0} not found in the {1} file'.format(section, filename))

  return db
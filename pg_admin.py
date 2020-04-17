#!/usr/local/bin/python
import psycopg2
import sys
import time
import os
from db_config import config
from db_utils import cursor_pprint


def connect():
    DEV = True
    if 'ENVIRONMENT' in os.environ:
        env = os.environ['ENVIRONMENT']
        print('working on %s' % env)
        DEV = 'DEV' in env

    conn = None
    try:
        # get connection parameters
        params = config()
        conn = psycopg2.connect(**params)
        conn.autocommit = True
        cur = conn.cursor()

        sql_commands_full = ''
        if len(sys.argv) > 1 and os.path.exists(sys.argv[1]):
            sql_script = sys.argv[1]
            print('sql script file: ', sql_script)
            fd = open(sql_script, 'r')
            sql_commands_full = fd.read()
            fd.close()
        else:
            print('no sql script file defined')
            sql_commands_full = 'SELECT now();\n\nSELECT version()'

        sql_commands = sql_commands_full.split('\n\n')
        print('about to run %s sql commands:\n' % str(len(sql_commands)))
        SQL_CMD_RESULT = ('select', 'show')
        for sql_command in sql_commands:
            if len(sql_command) > 5 and sql_command.find('--') == -1:
                start = time.perf_counter()
                if DEV:
                    print('%s \n' % sql_command)

                cur.execute(sql_command)
                if cur.rowcount > 0:
                    if sql_command.lower().startswith(SQL_CMD_RESULT):
                        rows = cur.fetchall()
                        print(cursor_pprint(cur, rows, 1), '\n')
                    else:
                        conn.commit()
                        print('rows affected: ', cur.rowcount)
                else:
                    print('#### NO RESULTS ###')
                print('elapsed time: {0:.4f} minutes'.format((time.perf_counter() - start) / 60))
                print('============================')
                print('')

        # close the communication with the PostgreSQL
        cur.close()

    except (Exception, psycopg2.DatabaseError) as error:
        print('error: ' % error)
    finally:
        if conn is not None:
            conn.close()
            print('Database connection closed.')


if __name__ == '__main__':
    connect()

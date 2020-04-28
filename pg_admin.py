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

        sql_script = ''
        if len(sys.argv) > 1 and os.path.exists(sys.argv[1]):
            sql_script = sys.argv[1]
            print('sql script file: ', sql_script)
            fd = open(sql_script, 'r')
            sql_commands_full = fd.read()
            fd.close()
        else:
            print('no sql script file defined')
            sql_commands_full = 'select to_char(current_timestamp, \'YYYY-MM-DD HH12:MI:SS\') as now;\n\nselect version()'

        sql_commands = sql_commands_full.split('\n\n')
        print('about to run %s sql commands:\n' % str(len(sql_commands)))
        print('============================')

        if sql_script != '' and sql_script.lower().find('db_sp_') != -1:
            # call stored procedure
            print('store procedure: %s \n' % sql_commands_full)
            cur.callproc(sql_commands_full)
        else:
            SQL_CMD_RESULT = ('select', 'show')
            for sql_command in sql_commands:
                sql_command_to_run = ''
                lines = sql_command.split('\n')
                for line in lines:
                    if not line.startswith('--'):
                        sql_command_to_run = sql_command_to_run + line + '\n'
                if len(sql_command_to_run) > 5:
                    start = time.perf_counter()
                    print('%s \n' % sql_command)
                    cur.execute(sql_command_to_run)

                if cur.rowcount > 0:
                    if sql_command_to_run.lower().startswith(SQL_CMD_RESULT) and sql_command_to_run.lower().find('into') == -1:
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

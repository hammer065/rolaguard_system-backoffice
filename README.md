# RoLaGuard Community Edition

## System Backoffice
This repository contains the source code of system-backoffice. This module it is used for system maintenance of the database, and also to schedule jobs.

To access the main project with instructions to easily run the rolaguard locally visit the [Rolaguard](./../README.md) repository. 
For contributions, please visit the [CONTRIBUTIONS](./../CONTRIBUTING.MD) file.

### How to use it locally

Build a docker image locally:
```
docker build -t rolaguard-system-backoffice .
```

Test docker image locally:
- passing sql script file to run as arg:
```
docker run rolaguard-system-backoffice python pg_admin.py scripts/sql/db_health_status.sql
```

- setting env var before call a py script:
```
docker run rolaguard-system-backoffice /bin/sh -c "export DB_HOST=localhost.rolaguard && export DB_NAME=rolaguard_local && export DB_USERNAME=postgres && export DB_PASSWORD=post_gres && python pg_admin.py scripts/sql/db_health_status.sql"
 ```
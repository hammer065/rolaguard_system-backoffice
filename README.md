# RoLaGuard Community Edition

## system-backoffice

This repository contains the source code of the RoLaGuard system-backoffice. This component is the responsible of the running some programated jobs in the database

To access the main project with instructions to easily run the rolaguard locally visit the [RoLaGuard](./../README.md) repository.  For contributions, please visit the [CONTRIBUTIONS](./../CONTRIBUTING.MD) file.

### Building the docker image

To build the docker image locally:

```bash
docker build -t loraguard-system-backoffice .
```

To test docker image locally:

- passing sql script file to run as arg:

```bash
docker run loraguard-system-backoffice python pg_admin.py scripts/sql/test.sql
```

- setting env var before call a py script:

```bash
docker run loraguard-system-backoffice /bin/sh -c "export TABLE_NAME=packet && export DB_HOST=xxx.rolaguard.com && export DB_NAME=xxx_development && export DB_USERNAME=xxx_admin && export DB_PASSWORD='xxx_.!mnsjd)!bX63W6ap?0w2kejB>whw7H37a(' && python pg_admin.py scripts/sql/db_health_status.sql"
 ```
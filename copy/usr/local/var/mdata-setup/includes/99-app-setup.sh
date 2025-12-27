#!/bin/bash

# setup kiwifrei mailer
if /native/usr/sbin/mdata-get mail_smarthost 1>/dev/null 2>&1; then
  echo "* Setup kivi config for mail"
  MAIL_UID=$(/native/usr/sbin/mdata-get mail_auth_user)
  MAIL_PWD=$(/native/usr/sbin/mdata-get mail_auth_pass)
  MAIL_HOST=$(/native/usr/sbin/mdata-get mail_smarthost)
  sed -i \
      -e "s#host = localhost#host = ${MAIL_HOST}#" \
      -e "s/#port = 25/port = 587/" \
      -e "s#security = none#security = tls#" \
      -e "s#login = mail_account_login#login = ${MAIL_UID}#" \
      -e "s#password = mail_account_pwd#password = ${MAIL_PWD}#" \
      /usr/local/src/kiwifrei-erp/config/kivitendo.conf
fi

# set masterkey for secrets encryption
MASTERKEY=$(openssl rand -hex 64)
sed -i \
    -e "s#master_key =#master_key = ${MASTERKEY}#" \
    /usr/local/src/kiwifrei-erp/config/kivitendo.conf

# setup kiwifrei admin password
if /native/usr/sbin/mdata-get kiwifrei_admin_pwd 1>/dev/null 2>&1; then
  echo "* Setup kivi config for auth"
  ADM_PWD=$(/native/usr/sbin/mdata-get kiwifrei_admin_pwd)
  sed -i \
      -e "s#admin_password = admin123#admin_password = ${ADM_PWD}#" \
      /usr/local/src/kiwifrei-erp/config/kivitendo.conf
fi

# setup kiwifrei database password
if /native/usr/sbin/mdata-get psql_kivitendo_pwd 1>/dev/null 2>&1; then
  echo "* Setup kivi config for db"
  DB_USER_PWD=$(/native/usr/sbin/mdata-get psql_kivitendo_pwd)
  sed -i \
      -e "s#password = kivitendo_pwd#password = ${DB_USER_PWD}#" \
      /usr/local/src/kiwifrei-erp/config/kivitendo.conf
fi

# setup kiwifrei alert email
if /native/usr/sbin/mdata-get kiwifrei_alert_email 1>/dev/null 2>&1; then
  echo "* Setup kivi config for mail"
  ALERT_MAIL=$(/native/usr/sbin/mdata-get kiwifrei_alert_email)
  sed -i \
      -e "s#send_email_to  = alert@example.com#send_email_to  = ${ALERT_MAIL}#" \
      /usr/local/src/kiwifrei-erp/config/kivitendo.conf
fi

if /native/usr/sbin/mdata-get kiwifrei_fromn_email 1>/dev/null 2>&1; then
  echo "* Setup kivi config for mail"
  MAIL_FROM=$(/native/usr/sbin/mdata-get kiwifrei_fromn_email)
  sed -i \
      -e "s#email_from     = kiwifrei Daemon <root@localhost>#email_from     = ${MAIL_FROM}#g" \
      /usr/local/src/kiwifrei-erp/config/kivitendo.conf
fi

# fix error: new encoding (UTF8) is incompatible with the encoding of the template database (SQL_ASCII)
echo "* fix encoding issue"
su - postgres -c 'psql UPDATE pg_database SET datistemplate = FALSE WHERE datname = 'template1';'
su - postgres -c 'psql DROP DATABASE template1;'
su - postgres -c 'psql CREATE DATABASE template1 WITH TEMPLATE = template0 ENCODING = 'UNICODE';'
su - postgres -c 'psql UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template1';'

echo "* enable plpgsql extension in db"
su - postgres -c 'psql template1 --file=/usr/local/src/kiwifrei-erp/config/psql_kivi_template1.sql' || true
rm /usr/local/src/kiwifrei-erp/config/psql_kivi_template1.sql

# setup postgesql superuser
if /native/usr/sbin/mdata-get psql_postgres_pwd 1>/dev/null 2>&1; then
  echo "* Create db superuser"
  DB_SUPERUSER_PWD=$(/native/usr/sbin/mdata-get psql_postgres_pwd)
  sed -i \
      -e "s#foobar#${DB_SUPERUSER_PWD}#" \
      /usr/local/src/kiwifrei-erp/config/psql_kivi_superuser.sql
  su - postgres -c 'psql --file=/usr/local/src/kiwifrei-erp/config/psql_kivi_superuser.sql'
  rm /usr/local/src/kiwifrei-erp/config/psql_kivi_superuser.sql
fi

# setup postgesql kiwifrei user
if /native/usr/sbin/mdata-get psql_kivitendo_pwd 1>/dev/null 2>&1; then
  echo "* Create db regular users"
  DB_USER_PWD=$(/native/usr/sbin/mdata-get psql_kivitendo_pwd)
  sed -i \
      -e "s#foobar#${DB_USER_PWD}#" \
      /usr/local/src/kiwifrei-erp/config/psql_kivi_user.sql
  su - postgres -c 'psql --file=/usr/local/src/kiwifrei-erp/config/psql_kivi_user.sql'
  rm /usr/local/src/kiwifrei-erp/config/psql_kivi_user.sql
  # allow the user to create databases
  su - postgres -c 'psql -c "ALTER USER kivitendo CREATEDB;"'
  systemctl restart postgresql &
  systemctl enable postgresql || true
fi

# setup webdav
if /native/usr/sbin/mdata-get webdav_user 1>/dev/null 2>&1; then
  echo "* Setup kivi config for webdav"
  WEBDAV_USR=$(/native/usr/sbin/mdata-get webdav_user)
  WEBDAV_PWD=$(/native/usr/sbin/mdata-get webdav_pwd)
  echo "${WEBDAV_PWD}" | htpasswd -c -i /etc/apache2/webdav.password "${WEBDAV_USR}"
  systemctl restart apache2
fi

if [[ $(/native/usr/sbin/mdata-get start_kiwifrei_api 2>&1) = "true" ]]; then
  echo "* Setup kivi-api"
  # install kiwifrei-api
  /usr/local/bin/install_kiwifrei_api
fi

echo "* Add robots.txt"
cat > /usr/local/src/kiwifrei-erp/robots.txt << 'EOF'
User-agent: *
Disallow: /
EOF

cd /usr/local/src/kiwifrei-erp
git add .
git commit -m "after deploy changes /2"

# start task-server
if [[ $(/native/usr/sbin/mdata-get start_task_server 2>&1) = "true" ]]; then
  echo "* Start taskserver"
  systemctl enable kiwifrei-task-server.service
  systemctl start kiwifrei-task-server.service
fi

echo "* Restart apache"
systemctl restart apache2

# install texlive 2020?
# if [[ $(/native/usr/sbin/mdata-get activate_zugpferd 2>&1) = "true" ]]; then
#   /usr/local/bin/install_texlive_2020
# fi

# TODO
# - change values in kivitendo.conf related to mdata values
# -- dial_command =
# -- external_prefix = 0
# -- international_dialing_prefix = 00

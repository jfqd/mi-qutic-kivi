#!/bin/bash

# start task-server
if [[ $(/native/usr/sbin/mdata-get start_task_server 2>&1) = "true" ]]; then
  systemctl enable kivitendo-task-server.service
  systemctl start kivitendo-task-server.service
fi

# setup kivitendo mailer
if /native/usr/sbin/mdata-get mail_smarthost 1>/dev/null 2>&1; then
  MAIL_UID=$(/native/usr/sbin/mdata-get mail_auth_user)
  MAIL_PWD=$(/native/usr/sbin/mdata-get mail_auth_pass)
  MAIL_HOST=$(/native/usr/sbin/mdata-get mail_smarthost)
  sed -i \
      -e "s#host = localhost#host = ${MAIL_HOST}#" \
      -e "s/#port = 25/port = 587/" \
      -e "s#security = none#security = tls#" \
      -e "s#login = mail_account_login#login = ${MAIL_UID}#" \
      -e "s#password = mail_account_pwd#password = ${MAIL_PWD}#" \
      /usr/local/src/kivitendo-erp/config/kivitendo.conf
fi

# setup kivitendo admin password
if /native/usr/sbin/mdata-get kivitendo_admin_pwd 1>/dev/null 2>&1; then
  ADM_PWD=$(/native/usr/sbin/mdata-get kivitendo_admin_pwd)
  sed -i \
      -e "s#admin_password = admin123#admin_password = ${ADM_PWD}#" \
      /usr/local/src/kivitendo-erp/config/kivitendo.conf
fi

# setup kivitendo database password
if /native/usr/sbin/mdata-get psql_kivitendo_pwd 1>/dev/null 2>&1; then
  DB_USER_PWD=$(/native/usr/sbin/mdata-get psql_kivitendo_pwd)
  sed -i \
      -e "s#password = kivitendo_pwd#password = ${DB_USER_PWD}#" \
      /usr/local/src/kivitendo-erp/config/kivitendo.conf
fi

# setup kivitendo alert email
if /native/usr/sbin/mdata-get kivitendo_alert_email 1>/dev/null 2>&1; then
  ALERT_MAIL=$(/native/usr/sbin/mdata-get kivitendo_alert_email)
  sed -i \
      -e "s#send_email_to  = alert@example.com#send_email_to  = ${ALERT_MAIL}#" \
      /usr/local/src/kivitendo-erp/config/kivitendo.conf
fi

if /native/usr/sbin/mdata-get kivitendo_fromn_email 1>/dev/null 2>&1; then
  MAIL_FROM=$(/native/usr/sbin/mdata-get kivitendo_fromn_email)
  sed -i \
      -e "s#email_from     = kivitendo Daemon <root@localhost>#email_from     = ${MAIL_FROM}#g" \
      /usr/local/src/kivitendo-erp/config/kivitendo.conf
fi

# setup postgesql superuser
if /native/usr/sbin/mdata-get psql_postgres_pwd 1>/dev/null 2>&1; then
  DB_SUPERUSER_PWD=$(/native/usr/sbin/mdata-get psql_postgres_pwd)
  sed -i \
      -e "s#foobar#${DB_SUPERUSER_PWD}#" \
      /usr/local/src/kivitendo-erp/config/psql_kivi_superuser.sql
  su - postgres -c 'psql --file=/usr/local/src/kivitendo-erp/config/psql_kivi_superuser.sql'
  rm /usr/local/src/kivitendo-erp/config/psql_kivi_superuser.sql
fi

# setup postgesql kivitendo user
if /native/usr/sbin/mdata-get psql_kivitendo_pwd 1>/dev/null 2>&1; then
  DB_USER_PWD=$(/native/usr/sbin/mdata-get psql_kivitendo_pwd)
  sed -i \
      -e "s#foobar#${DB_USER_PWD}#" \
      /usr/local/src/kivitendo-erp/config/psql_kivi_user.sql
  su - postgres -c 'psql --file=/usr/local/src/kivitendo-erp/config/psql_kivi_user.sql'
  rm /usr/local/src/kivitendo-erp/config/psql_kivi_user.sql
  # allow the user to create databases
  su - postgres -c 'psql -c "ALTER USER kivitendo CREATEDB;"'
  systemctl restart postgresql &
  systemctl enable postgresql || true
fi

# setup postgesql kivitendo user
if /native/usr/sbin/mdata-get webdav_user 1>/dev/null 2>&1; then
  WEBDAV_USR=$(/native/usr/sbin/mdata-get webdav_user)
  WEBDAV_PWD=$(/native/usr/sbin/mdata-get webdav_user)
  WEBDAV_CRYPTED_PWD=$(openssl passwd -apr1 $WEBDAV_PWD)
  echo "${WEBDAV_USR}:${WEBDAV_CRYPTED_PWD}" > /etc/apache2/webdav.password
  systemctl restart apache2
fi

if [[ $(/native/usr/sbin/mdata-get start_kivi_api 2>&1) = "true" ]]; then
  # install kivitendo-api
  /usr/local/bin/install_kivitendo_api
  
  # setup kivitendo-api postgesql-connection
  if /native/usr/sbin/mdata-get psql_kivitendo_pwd 1>/dev/null 2>&1; then
    DB_USER_PWD=$(/native/usr/sbin/mdata-get psql_kivitendo_pwd)
    sed -i \
        -e "s#postgres://pg-user:pg-pwd@pg-host/pg-db-name#postgres://kivitendo:${DB_USER_PWD}@127.0.0.1/kivitendo#" \
        /home/ruby/www/kivitendo_rest_api/config/secrets.yml
  fi

  # setup kivitendo-api http-basic user
  if /native/usr/sbin/mdata-get kivi_api_user 1>/dev/null 2>&1; then
    API_USR=$(/native/usr/sbin/mdata-get kivi_api_user)
    sed -i \
        -e "s#enter-http-user-here#${API_USR}#" \
        /home/ruby/www/kivitendo_rest_api/config/secrets.yml
  fi

  # setup kivitendo-api http-basic password
  if /native/usr/sbin/mdata-get kivi_api_pwd 1>/dev/null 2>&1; then
    API_PWD=$(/native/usr/sbin/mdata-get kivi_api_pwd)
    sed -i \
        -e "s#enter-http-password-here#${API_PWD}#" \
        /home/ruby/www/kivitendo_rest_api/config/secrets.yml
  fi

  # start kivitendo-api
  systemctl enable kivitendo-api.service
  systemctl start kivitendo-api.service
fi

# fix a link
sed -i \
    -e "s#kivitendo Homepage#kivitendo Infoseite#g"
    -e "s#http://kivitendo.de#https://qutic.com/kivitendo#" \
    /usr/local/src/kivitendo-erp/templates/webpages/login/company_logo.html

# sed -i \
#     -e "s#kivitendo Webseite (extern)#kivitendo Infoseite#" \
#     /usr/local/src/kivitendo-erp/locale/de/all

# install texlive 2020?
if [[ $(/native/usr/sbin/mdata-get activate_zugpferd 2>&1) = "true" ]]; then
  /usr/local/bin/install_texlive_2020
fi

# TODO
# - change values in kivitendo.conf related to mdata values
# -- dial_command =
# -- external_prefix = 0
# -- international_dialing_prefix = 00

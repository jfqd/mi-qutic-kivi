#!/bin/bash

# to start the taskserver automatically use:
# systemctl start kivitendo-task-server.service

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
if /native/usr/sbin/mdata-get psql_kivi_pwd 1>/dev/null 2>&1; then
  DB_USER_PWD=$(/native/usr/sbin/mdata-get psql_kivi_pwd)
  sed -i \
       -e "s#password = kivitendo_pwd#password = ${DB_USER_PWD}#" \
       /usr/local/src/kivitendo-erp/config/kivitendo.conf
fi

# setup kivitendo alert email
if /native/usr/sbin/mdata-get kivitendo_alert_email 1>/dev/null 2>&1; then
  ALERT_MAIL=$(/native/usr/sbin/mdata-get kivitendo_alert_email)
  sed -i \
       -e "s#send_email_to  = alert@example.com#end_email_to  = ${ALERT_MAIL}#" \
       /usr/local/src/kivitendo-erp/config/kivitendo.conf
fi

# setup postgesql kivitendo user
if /native/usr/sbin/mdata-get psql_kivi_pwd 1>/dev/null 2>&1; then
  DB_USER_PWD=$(/native/usr/sbin/mdata-get psql_kivi_pwd)
  sed -i \
       -e "s#foobar#{DB_USER_PWD}#" \
       /usr/local/src/kivitendo-erp/config/psql_kivi_user.sql
  su - postgres -c 'psql --file=/usr/local/src/kivitendo-erp/config/psql_kivi_user.sql'
  rm /usr/local/src/kivitendo-erp/config/psql_kivi_user.sql
  # allow the user to create databases
  su - postgres -c 'psql -c "ALTER USER kivitendo CREATEDB;"'
fi

# setup postgesql kivitendo user
if /native/usr/sbin/mdata-get webdav_user 1>/dev/null 2>&1; then
  WEBDAV_USR=$(/native/usr/sbin/mdata-get webdav_user)
  WEBDAV_PWD=$(/native/usr/sbin/mdata-get webdav_user)
  WEBDAV_CRYPTED_PWD=$(openssl passwd -apr1 $WEBDAV_PWD)
  echo "${WEBDAV_USR}:${WEBDAV_CRYPTED_PWD}" > /usr/local/src/kivitendo-erp/config/psql_kivi_user.sql
  systemctl restart apache2
fi

# TODO
# - change values in kivitendo.conf related to mdata values
# -- email_from     = kivitendo Daemon <root@localhost>
# -- dial_command =
# -- external_prefix = 0
# -- international_dialing_prefix = 00

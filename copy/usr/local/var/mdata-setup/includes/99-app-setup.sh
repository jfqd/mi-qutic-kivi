#!/bin/bash

# start task-server
if [[ $(/native/usr/sbin/mdata-get start_task_server 2>&1) = "true" ]]; then
  echo "* Start taskserver"
  systemctl enable kivitendo-task-server.service
  systemctl start kivitendo-task-server.service
fi

# setup kivitendo mailer
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
      /usr/local/src/kivitendo-erp/config/kivitendo.conf
fi

# setup kivitendo admin password
if /native/usr/sbin/mdata-get kivitendo_admin_pwd 1>/dev/null 2>&1; then
  echo "* Setup kivi config for auth"
  ADM_PWD=$(/native/usr/sbin/mdata-get kivitendo_admin_pwd)
  sed -i \
      -e "s#admin_password = admin123#admin_password = ${ADM_PWD}#" \
      /usr/local/src/kivitendo-erp/config/kivitendo.conf
fi

# setup kivitendo database password
if /native/usr/sbin/mdata-get psql_kivitendo_pwd 1>/dev/null 2>&1; then
  echo "* Setup kivi config for db"
  DB_USER_PWD=$(/native/usr/sbin/mdata-get psql_kivitendo_pwd)
  sed -i \
      -e "s#password = kivitendo_pwd#password = ${DB_USER_PWD}#" \
      /usr/local/src/kivitendo-erp/config/kivitendo.conf
fi

# setup kivitendo alert email
if /native/usr/sbin/mdata-get kivitendo_alert_email 1>/dev/null 2>&1; then
  echo "* Setup kivi config for mail"
  ALERT_MAIL=$(/native/usr/sbin/mdata-get kivitendo_alert_email)
  sed -i \
      -e "s#send_email_to  = alert@example.com#send_email_to  = ${ALERT_MAIL}#" \
      /usr/local/src/kivitendo-erp/config/kivitendo.conf
fi

if /native/usr/sbin/mdata-get kivitendo_fromn_email 1>/dev/null 2>&1; then
  echo "* Setup kivi config for mail"
  MAIL_FROM=$(/native/usr/sbin/mdata-get kivitendo_fromn_email)
  sed -i \
      -e "s#email_from     = kivitendo Daemon <root@localhost>#email_from     = ${MAIL_FROM}#g" \
      /usr/local/src/kivitendo-erp/config/kivitendo.conf
fi

echo "* enable plpgsql extension in db"
su - postgres -c 'psql template1 --file=/usr/local/src/kivitendo-erp/config/psql_kivi_template1.sql' || true
rm /usr/local/src/kivitendo-erp/config/psql_kivi_template1.sql

# setup postgesql superuser
if /native/usr/sbin/mdata-get psql_postgres_pwd 1>/dev/null 2>&1; then
  echo "* Create db superuser"
  DB_SUPERUSER_PWD=$(/native/usr/sbin/mdata-get psql_postgres_pwd)
  sed -i \
      -e "s#foobar#${DB_SUPERUSER_PWD}#" \
      /usr/local/src/kivitendo-erp/config/psql_kivi_superuser.sql
  su - postgres -c 'psql --file=/usr/local/src/kivitendo-erp/config/psql_kivi_superuser.sql'
  rm /usr/local/src/kivitendo-erp/config/psql_kivi_superuser.sql
fi

# setup postgesql kivitendo user
if /native/usr/sbin/mdata-get psql_kivitendo_pwd 1>/dev/null 2>&1; then
  echo "* Create db regular users"
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
  echo "* Setup kivi config for webdav"
  WEBDAV_USR=$(/native/usr/sbin/mdata-get webdav_user)
  WEBDAV_PWD=$(/native/usr/sbin/mdata-get webdav_pwd)
  echo "${WEBDAV_PWD}" | htpasswd -c -i /etc/apache2/webdav.password "${WEBDAV_USR}"
  systemctl restart apache2
fi

if [[ $(/native/usr/sbin/mdata-get start_kivi_api 2>&1) = "true" ]]; then
  echo "* Setup kivi-api"
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
echo "* Patch kivi link"
sed -i \
    -e "s#kivitendo Homepage#kivitendo Hosting#g" \
    -e "s#http://www.kivitendo.de#https://qutic.com/kivitendo#g" \
    -e "s#http://kivitendo.de#https://qutic.com/kivitendo#g" \
    /usr/local/src/kivitendo-erp/templates/webpages/login/company_logo.html
sed -i \
    -e "s#kivitendo Homepage#kivitendo Hosting#g" \
    -e "s#http://www.kivitendo.de#https://qutic.com/kivitendo#g" \
    -e "s#http://kivitendo.de#https://qutic.com/kivitendo#g" \
    /usr/local/src/kivitendo-erp/templates/design40_webpages/login/company_logo.html
sed -i \
    -e "s#http://www.kivitendo.de#https://qutic.com/kivitendo#g" \
    -e "s#http://kivitendo.de#https://qutic.com/kivitendo#g" \
    /usr/local/src/kivitendo-erp/templates/design40_webpages/login_screen/user_login.html
sed -i \
    -e "s#http://www.kivitendo.de#https://qutic.com/kivitendo#g" \
    -e "s#http://kivitendo.de#https://qutic.com/kivitendo#g" \
    /usr/local/src/kivitendo-erp/templates/webpages/login_screen/user_login.html
sed -i \
    -e "s#http://www.kivitendo.de#https://qutic.com/kivitendo#g" \
    -e "s#http://kivitendo.de#https://qutic.com/kivitendo#g" \
    /usr/local/src/kivitendo-erp/templates/design40_webpages/admin/adminlogin.html
sed -i \
    -e "s#http://www.kivitendo.de#https://qutic.com/kivitendo#g" \
    /usr/local/src/kivitendo-erp/menus/admin/00-admin.yaml
sed -i \
    -e "s#http://www.kivitendo.de#https://qutic.com/kivitendo#g" \
    /usr/local/src/kivitendo-erp/menus/user/00-erp.yaml

echo "* Patch kivitendo css"
cat >> /usr/local/src/kivitendo-erp/css/design40/style.css << EOF

/* changes by qutic development GmbH */
#frame-header div.frame-header-quicksearch span.frame-header-quicksearch input {
  background-color: #efefef;
}
#menuv3 {
  background-color: #e0e0e0;
}
#menuv3>ul>li {
  background-color: #e0e0e0;
}
#menuv3>ul>li:hover {
  background-color: #d0d0d0;
}
#menuv3>ul>li>ul>li {
  background-color: #d0d0d0;
}
#menuv3>ul>li>ul>li:hover {
  background-color: #e0e0e0;
}
#menuv3>ul>li>ul>li>ul>li {
  background-color: #d0d0d0;
}
#menuv3>ul>li>ul>li>ul>li:hover {
  background-color: #e0e0e0;
}
body #content {
  background-image: none;
  background: #efefef;
}
#content>h1 {
  background-color: #79b61b;
  border-top: 1px solid black;
}
table.tbl-list {
  width: 100%;
}
body {
  background-color: #efefef;
}
.control-panel {
  background: #e0e0e0;
}
EOF

echo "* Restart apache"
systemctl restart apache2

# sed -i \
#     -e "s#kivitendo Webseite (extern)#kivitendo Infoseite#" \
#     /usr/local/src/kivitendo-erp/locale/de/all

# install texlive 2020?
# if [[ $(/native/usr/sbin/mdata-get activate_zugpferd 2>&1) = "true" ]]; then
#   /usr/local/bin/install_texlive_2020
# fi

# TODO
# - change values in kivitendo.conf related to mdata values
# -- dial_command =
# -- external_prefix = 0
# -- international_dialing_prefix = 00

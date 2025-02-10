#!/bin/bash

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
cat >> /usr/local/src/kivitendo-erp/css/design40/style.css << 'EOF'

/* changes by qutic development GmbH */
* {
  -webkit-box-sizing: border-box;
  -moz-box-sizing: border-box;
  box-sizing: border-box;
}
body div.admin {
  background: #efefef;
}
#frame-header {
  background-color: #525c66;
}
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
  margin-left: 10px;
  margin-right: 10px;
}
#content>h1 {
  background-color: #79b61b;
  border-top: 1px solid #666;
  margin: 0 -10px 0 -10px;
  padding: .7em .5em .7em 10px;
}
#content>p {
  margin: .6em 2em 1em 1px;
}
table.tbl-list {
  width: 100%;
}
body {
  background-color: #efefef;
}
body div.admin {
  background-color: #efefef;
}
.control-panel {
  background: #e0e0e0;
}
.layout-actionbar div.layout-actionbar-combobox div.layout-actionbar-combobox-head>div {
  background-color: #e0e0e0;
  border: 1px #666 solid;
}
.layout-actionbar div.layout-actionbar-combobox div.layout-actionbar-combobox-head>span {
  background-color: #e0e0e0;
}
.layout-actionbar div.layout-actionbar-combobox div.layout-actionbar-combobox-list div.layout-actionbar-action {
  background-color: #e0e0e0;
}
.layout-actionbar div.layout-actionbar-combobox div.layout-actionbar-combobox-list div.layout-actionbar-action:hover {
  background-color: #e0e0e0;
}
.layout-actionbar>div.layout-actionbar-action {
  background-color: #e0e0e0;
}
.flash_message.flash_message_error {
  color: black;
}
table.tbl-list tbody tr:nth-child(odd) {
  background-color: #e6e6e6;
}
table.tbl-list tbody tr:nth-child(even) {
  background-color: #f3f3f3;
}
table.tbl-list tbody tr:hover {
  background-color: #ffffff;
}
table td img, table th img {
  width: 20px !important;
}
.tabwidget>ul.ui-tabs-nav {
  margin-left: -10px;
  margin-right: -10px;
}
#menuv3>ul>li {
  height: 32px;
}
.wrapper {
  margin-left: 0;
  margin-right: 0;
}
#reconciliation_form {
  margin-top: 40px;
}
#document_list_purchase_invoice .buttons input:nth-child(1),
#attachment_list_purchase_invoice .buttons input:nth-child(1),
#document_list_sales_order .buttons input:nth-child(1),
#attachment_list_sales_order .buttons input:nth-child(1) {
  display: none !important;
}
#document_list_purchase_invoice tr th:nth-child(1),
#document_list_purchase_invoice tr td:nth-child(1),
#attachment_list_purchase_invoice tr th:nth-child(1),
#attachment_list_purchase_invoice tr td:nth-child(1),
#document_list_sales_order tr th:nth-child(1),
#document_list_sales_order tr td:nth-child(1),
#attachment_list_sales_order tr th:nth-child(1),
#attachment_list_sales_order tr td:nth-child(1) {
  text-align: center !important;
  width: 150px;
}
#html-menu .s0.menu-open a:hover,
div.layout-split-left #html-menu .s0.menu-open a:active,
div.layout-split-left #html-menu .s0.menu-open {
  background-color: #79b61b !important;
}
div.layout-split-left #html-menu .s1 a:hover,
div.layout-split-left #html-menu .s1 a:active {
  background-color: #ffffff;
}
div.layout-split-left #html-menu .s0,
div.layout-split-left #html-menu .s1,
div.layout-split-left #html-menu .s2 {
  background-color: #eeeee9;
}
#link_table tbody tr:nth-child(odd) {
  background-color: #e6e6e6;
}
#link_table tbody tr:nth-child(even) {
  background-color: #f3f3f3;
}
#link_table tbody tr:hover {
  background-color: #ffffff;
}
#link_table td {
  padding-top: 3px;
  padding-bottom: 3px;
}
EOF

echo "* Add robots.txt"
cat >> /usr/local/src/kivitendo-erp/robots.txt << 'EOF'
User-agent: *
Disallow: /
EOF

cd /usr/local/src/kivitendo-erp
git add .
git commit -m "after deploy changes /2"

# start task-server
if [[ $(/native/usr/sbin/mdata-get start_task_server 2>&1) = "true" ]]; then
  echo "* Start taskserver"
  systemctl enable kivitendo-task-server.service
  systemctl start kivitendo-task-server.service
fi

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

#!/usr/bin/bash

# setup kiwifrei mailer
if /native/usr/sbin/mdata-get mail_smarthost 1>/dev/null 2>&1; then
  echo "* Setup kiwifrei config for mail"
  MAIL_UID=$(/native/usr/sbin/mdata-get mail_auth_user)
  MAIL_PWD=$(/native/usr/sbin/mdata-get mail_auth_pass)
  MAIL_HOST=$(/native/usr/sbin/mdata-get mail_smarthost)
  sed -i \
      -e "s#host = localhost#host = ${MAIL_HOST}#" \
      -e "s/#port = 25/port = 587/" \
      -e "s#security = none#security = tls#" \
      -e "s#login = mail_account_login#login = ${MAIL_UID}#" \
      -e "s#password = mail_account_pwd#password = ${MAIL_PWD}#" \
      /usr/local/src/kiwifrei-erp/config/kiwifrei.conf
fi

# set masterkey for secrets encryption
MASTERKEY=$(openssl rand -hex 64)
sed -i \
    -e "s#master_key =#master_key = ${MASTERKEY}#" \
    /usr/local/src/kiwifrei-erp/config/kiwifrei.conf

# setup kiwifrei admin password
if /native/usr/sbin/mdata-get kiwifrei_admin_pwd 1>/dev/null 2>&1; then
  echo "* Setup kiwifrei config for auth"
  ADM_PWD=$(/native/usr/sbin/mdata-get kiwifrei_admin_pwd)
  sed -i \
      -e "s#admin_password = admin123#admin_password = ${ADM_PWD}#" \
      /usr/local/src/kiwifrei-erp/config/kiwifrei.conf
fi

# setup kiwifrei database password
if /native/usr/sbin/mdata-get psql_kiwifrei_pwd 1>/dev/null 2>&1; then
  echo "* Setup kiwifrei config for db"
  DB_USER_PWD=$(/native/usr/sbin/mdata-get psql_kiwifrei_pwd)
  sed -i \
      -e "s#password = kiwifrei_pwd#password = ${DB_USER_PWD}#" \
      /usr/local/src/kiwifrei-erp/config/kiwifrei.conf
fi

# setup kiwifrei alert email
if /native/usr/sbin/mdata-get kiwifrei_alert_email 1>/dev/null 2>&1; then
  echo "* Setup kiwifrei config for mail"
  ALERT_MAIL=$(/native/usr/sbin/mdata-get kiwifrei_alert_email)
  sed -i \
      -e "s#send_email_to  = alert@example.com#send_email_to  = ${ALERT_MAIL}#" \
      /usr/local/src/kiwifrei-erp/config/kiwifrei.conf
fi

if /native/usr/sbin/mdata-get kiwifrei_from_email 1>/dev/null 2>&1; then
  echo "* Setup kiwifrei config for mail"
  MAIL_FROM=$(/native/usr/sbin/mdata-get kiwifrei_from_email)
  sed -i \
      -e "s#email_from     = kiwifrei Daemon <root@localhost>#email_from     = ${MAIL_FROM}#g" \
      /usr/local/src/kiwifrei-erp/config/kiwifrei.conf
fi

# fix error: new encoding (UTF8) is incompatible with the encoding of the template database (SQL_ASCII)
echo "* fix encoding issue"
su - postgres -c 'psql UPDATE pg_database SET datistemplate = FALSE WHERE datname = "template1";' || true
su - postgres -c 'psql DROP DATABASE template1;' || true
su - postgres -c 'psql CREATE DATABASE template1 WITH TEMPLATE = template0 ENCODING = "UNICODE";' || true
su - postgres -c 'psql UPDATE pg_database SET datistemplate = TRUE WHERE datname = "template1";' || true

echo "* enable plpgsql extension in db"
su - postgres -c 'psql template1 --file=/usr/local/src/kiwifrei-erp/config/psql_kiwifrei_template1.sql' || true
rm /usr/local/src/kiwifrei-erp/config/psql_kiwifrei_template1.sql

# setup postgesql superuser
if /native/usr/sbin/mdata-get psql_postgres_pwd 1>/dev/null 2>&1; then
  echo "* Create db superuser"
  DB_SUPERUSER_PWD=$(/native/usr/sbin/mdata-get psql_postgres_pwd)
  sed -i \
      -e "s#foobar#${DB_SUPERUSER_PWD}#" \
      /usr/local/src/kiwifrei-erp/config/psql_kiwifrei_superuser.sql
  su - postgres -c 'psql --file=/usr/local/src/kiwifrei-erp/config/psql_kiwifrei_superuser.sql'
  rm /usr/local/src/kiwifrei-erp/config/psql_kiwifrei_superuser.sql
fi

# setup postgesql kiwifrei user
if /native/usr/sbin/mdata-get psql_kiwifrei_pwd 1>/dev/null 2>&1; then
  echo "* Create db regular users"
  DB_USER_PWD=$(/native/usr/sbin/mdata-get psql_kiwifrei_pwd)
  sed -i \
      -e "s#foobar#${DB_USER_PWD}#" \
      /usr/local/src/kiwifrei-erp/config/psql_kiwifrei_user.sql
  su - postgres -c 'psql --file=/usr/local/src/kiwifrei-erp/config/psql_kiwifrei_user.sql'
  rm /usr/local/src/kiwifrei-erp/config/psql_kiwifrei_user.sql
  # allow the user to create databases
  su - postgres -c 'psql -c "ALTER USER kivitendo CREATEDB;"'
  systemctl restart postgresql &
  systemctl enable postgresql || true
fi

# setup webdav
if /native/usr/sbin/mdata-get webdav_user 1>/dev/null 2>&1; then
  echo "* Setup kiwifrei config for webdav"
  WEBDAV_USR=$(/native/usr/sbin/mdata-get webdav_user)
  WEBDAV_PWD=$(/native/usr/sbin/mdata-get webdav_pwd)
  echo "${WEBDAV_PWD}" | htpasswd -c -i /etc/apache2/webdav.password "${WEBDAV_USR}"
  systemctl restart apache2
  cp /etc/apache2/webdav.password /etc/nginx/.htpasswd
fi

if [[ $(/native/usr/sbin/mdata-get start_kiwifrei_api 2>&1) = "true" ]]; then
  echo "* Setup kiwifrei-api"
  # install kiwifrei-api
  /usr/local/bin/install_kiwifrei_api
fi

echo "* Add robots.txt"
cat > /usr/local/src/kiwifrei-erp/robots.txt << 'EOF'
User-agent: *
Disallow: /
EOF

echo "* Create LaTeX print template"
cd /usr/local/src/kiwifrei-erp
cp -rpav templates/print/marei templates/latex-druckvorlage

# start task-server
if [[ $(/native/usr/sbin/mdata-get start_task_server 2>&1) = "true" ]]; then
  echo "* Start taskserver"
  systemctl enable kiwifrei-task-server.service
  systemctl start kiwifrei-task-server.service
fi

mkdir -p /etc/apache2/sites-enabled || true
rm /etc/apache2/sites-enabled/default || true

if /native/usr/sbin/mdata-get sso_auth_domain 1>/dev/null 2>&1; then
  echo "* Setup auth service option"
  RESOLVERS=$(cat /etc/resolv.conf |grep nameserver |awk '{ print $2 }' 2>/dev/null |sed -z "s/\n/:53 /g")
  SSO_AUTH_DOMAIN=$(/native/usr/sbin/mdata-get sso_auth_domain)
  
  if /native/usr/sbin/mdata-get sso_auth_secret 1>/dev/null 2>&1; then
    SECURE_PROXY_SECRET=$(/native/usr/sbin/mdata-get sso_auth_secret)
  else
    SECURE_PROXY_SECRET=$(LC_ALL=C tr -cd '[:alnum:]_.' < /dev/urandom | head -c32)
  fi
s  sed -i \
      -e "s/10.10.10.10:53/${RESOLVERS}/" \
      -e "s#auth.example.com#${SSO_AUTH_DOMAIN}#" \
      /etc/nginx/sites-available/kiwifrei.conf

  sed -i \
      -e "s#SECURE_PROXY_SECRET#${SECURE_PROXY_SECRET}#" \
      -e "s#SECURE_PROXY_ENABLED#1#" \
      /usr/local/src/kiwifrei-erp/config/kiwifrei.conf

  ln -nfs /etc/apache2/sites-available/with-proxy-auth.conf /etc/apache2/sites-enabled/with-proxy-auth
  mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
  mv /usr/local/var/tmp/nginx.conf /etc/nginx/nginx.conf
  systemctl enable nginx
  systemctl restart nginx
else
  sed -i \
      -e "s#SECURE_PROXY_ENABLED#0#" \
      /usr/local/src/kiwifrei-erp/config/kiwifrei.conf

  ln -nfs /etc/apache2/sites-available/native.conf /etc/apache2/sites-enabled/default
  
  systemctl disable nginx || true
  systemctl stop nginx || true
fi

echo "* Restart apache"
systemctl restart apache2

# install texlive 2020?
# if [[ $(/native/usr/sbin/mdata-get activate_zugpferd 2>&1) = "true" ]]; then
#   /usr/local/bin/install_texlive_2020
# fi

# TODO
# - change values in kiwifrei.conf related to mdata values
# -- dial_command =
# -- external_prefix = 0
# -- international_dialing_prefix = 00

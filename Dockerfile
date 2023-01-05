FROM centos:7 AS mysql

ARG VERSION

ADD etc/yum.repos.d/ /etc/yum.repos.d/
RUN yum install -y epel-release

RUN groupadd -r -g 594 irods && \
  useradd -r -c 'iRODS Administrator' -d /var/lib/irods -s /bin/bash -u 599 -g 594 irods

# Use patched irods if present
#ADD /rpm /rpm
#RUN yum localinstall -y /rpm/irods-server-${VERSION}-1.x86_64.rpm /rpm/irods-runtime-${VERSION}-1.x86_64.rpm /rpm/irods-devel-${VERSION}-1.x86_64.rpm || true

RUN yum install -y \
  unixODBC \
  gettext \
  jq \
  python-pip \
  python-enum \
  lnav \
  crontabs \
  mailx \
  nc \
  rsyslog \
  python3 \
  python3-distro \
  python3-requests \
  python3-psutil \
  python-devel \
  python3-devel \
  python36-jsonschema \
  mysql \
  libexif-devel \
  libxml2-devel \
  openssl \
  openssl-devel \
  gcc-c++ \
  unixODBC-devel

# Use more recent mysql odbc connector
RUN yum localinstall -y https://repo.mysql.com/yum/mysql-connectors-community/el/7/x86_64/mysql-connector-odbc-8.0.25-1.el7.x86_64.rpm

# Install of curl-devel conflicts with filelists, specify repo
RUN yum install -y --disablerepo=* --enablerepo=base,updates,extras curl-devel

RUN yum install -y \
  irods-server-${VERSION} \
  irods-runtime-${VERSION} \
  irods-icommands-${VERSION} \
  irods-database-plugin-mysql-${VERSION} \
  irods-rule-engine-plugin-python-${VERSION}.0 \
  irods-devel-${VERSION} \
  irods-resource-plugin-s3-${VERSION}.*

RUN yum install -y netcdf-devel gcc hdf5-devel

RUN pip3 install \
    supervisor \
    supervisor-stdout

ADD supervisor_stdout.py /usr/local/lib/python3.6/site-packages/supervisor_stdout.py

RUN if echo -e "$VERSION\n4.3.0" | sort -V | head -n1 | grep -q "4.3.0"; then \
  pip3 install cython && pip3 install \
    jsonschema \
    requests==2.6.0 \
    requests-cache==0.5.2 \
    xmltodict \
    jinja2 \
    pathvalidate \
    cftime==1.5.1 \
    netcdf4==1.5.3 \
    pandas \
    python-irodsclient \
    pyodbc \
    jsonpath-ng; \
else \
  pip install --upgrade pip==18.0 setuptools==18.0 && pip install cython && pip install \
    jsonschema \
    requests==2.6.0 \
    requests-cache==0.5.2 \
    xmltodict \
    jinja2 \
    pathvalidate \
    cftime==1.5.1 \
    netcdf4==1.5.3 \
    pandas \
    python-irodsclient \
    jsonpath-ng; \
fi

ADD etc/ /etc/
ADD $VERSION/etc/ /etc/
ADD bin/ /usr/local/bin/
ADD $VERSION/bin/ /usr/local/bin/

RUN apply-patches

RUN mkdir -p /etc/irods/ssl && openssl dhparam -2 -out /etc/irods/ssl/dhparams.pem 1024
RUN mkdir -p /var/log/supervisor /var/run/supervisor

ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]

ENV SERVER=irods \
  ZONE=test \
  ADMIN_USER=rods \
  ADMIN_PASS=hunter2 \
  SRV_NEGOTIATION_KEY= \
  SRV_ZONE_KEY= \
  CTRL_PLANE_KEY= \
  CTRL_PLANE_PORT=1248 \
  SRV_PORT=1247 \
  SRV_PORT_RANGE_START=20000 \
  SRV_PORT_RANGE_END=20199 \
  DB_NAME= \
  DB_USER= \
  DB_PASSWORD= \
  DB_SRV_HOST=mysql \
  DB_SRV_PORT=3306 \
  DEFAULT_VAULT_DIR=/vault \
  SSL_CERTIFICATE_CHAIN_FILE= \
  SSL_CERTIFICATE_KEY_FILE= \
  SSL_CA_BUNDLE= \
  RE_RULEBASE_SET="core" \
  PYTHON_RULESETS="" \
  FEDERATION="[]" \
  AMQP=ANONYMOUS@localhost:5672 \
  DEFAULT_RESOURCE=default \
  ROLE=provider \
  SHORT_TIER=t \
  VERSION=${VERSION}

# Irods port
EXPOSE 1247

# Control plane port - only to be used with consumers
EXPOSE 1248

# Metalnx rmd
EXPOSE 8000

VOLUME /var/lib/irods/log

FROM mysql AS postgres

RUN yum swap -y irods-database-plugin-mysql-${VERSION} irods-database-plugin-postgres-${VERSION}

ADD variants/postgres/bin/ /usr/local/bin/

RUN apply-patches-postgres

ENV DB_SRV_PORT=5432

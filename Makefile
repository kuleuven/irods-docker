.PHONY: all default ssl

DOCKER=GEM_HOME= GEM_PATH= docker

# TAG can either be mysql or postgres
TAG?=mysql

# IRODS version
VERSION?=4.2.11

MYSQL_IMAGE?=mysql:8
POSTGRES_IMAGE?=postgres:11
IRODS_IMAGE?="irods:$(VERSION)-$(TAG)"
METALNX_IMAGE?=registry.icts.kuleuven.be/hpc/metalnx:2.6.0
METALNXDB_IMAGE?=postgres:11
RABBITMQ_IMAGE?=registry.icts.kuleuven.be/lnx/rabbitmq:3.8.3
LOGSTASH_IMAGE?=registry.icts.kuleuven.be/hpc/logstash-irods:latest

MYSQL_NAME?=mysql
POSTGRES_NAME?=postgres
IRODS_NAME?=irods

IRODS_ZONE=test
IRODS_HOST=localhost

DATABASE_HOST?=$(shell hostname -I | awk '{print $$1}')

MYSQL_ROOT_PASSWORD?=rootpassword
POSTGRES_PASSWORD?=rootpassword

ROLE=provider
SRV_NEGOTIATION_KEY?=$(shell openssl rand -hex 16)
SRV_ZONE_KEY?=$(shell openssl rand -hex 16)
FEDERATION?=[]

# Dockerfile to build
DOCKERFILE=Dockerfile

PWD=$(shell pwd)

default: all

all: $(TAG) irods

with-postgres:
	$(MAKE) TAG=postgres all

clean: clean-ssl clean-mysql clean-postgres clean-irods
	$(DOCKER) volume prune --force

clean-ssl:
	rm -rf ssl/$(INSTANCE)

clean-mysql:
	$(DOCKER) rm -f $(MYSQL_NAME) || echo Container was already removed

clean-postgres:
	$(DOCKER) rm -f $(POSTGRES_NAME) || echo Container was already removed

clean-irods:
	$(DOCKER) rm -f $(IRODS_NAME) || echo Container was already removed

ssl: ssl/$(INSTANCE)$(CONSUMER)

ssl/$(INSTANCE)$(CONSUMER):
	mkdir -p ssl/$(INSTANCE)$(CONSUMER)
	openssl req -x509 -nodes -newkey rsa:4096 -keyout ssl/$(INSTANCE)$(CONSUMER)/key.pem -out ssl/$(INSTANCE)$(CONSUMER)/cert.pem -days 365 \
	  -subj '/CN=$(IRODS_HOST)' \
	  -addext "subjectAltName = DNS:$(IRODS_HOST)"
	$(MAKE) ca-bundle

ca-bundle:
	find ssl -name cert.pem | xargs cat > ssl/ca-bundle.pem

mysql: clean-mysql
	$(DOCKER) run -d --rm -p 3306:3306 --name $(MYSQL_NAME) -e MYSQL_ROOT_PASSWORD=$(MYSQL_ROOT_PASSWORD) \
	  --health-cmd "mysqladmin ping -h localhost" --health-interval 0 --health-retries 12 --health-start-period 10s \
	  $(MYSQL_IMAGE) \
	  --server-id=1 --gtid-mode=ON --enforce-gtid-consistency=ON
	@$(MAKE) --no-print-directory wait-for-mysql
	$(DOCKER) exec -i $(MYSQL_NAME) mysql -uroot -p$(MYSQL_ROOT_PASSWORD) < initdb.mysql.sql

wait-for-mysql:
	@echo "Waiting for mysql to start ... (max 180s)"
	@for i in {1..30}; \
		do \
		echo -n "."; \
		./healthcheck.sh $(MYSQL_NAME) 1>/dev/null && break; \
		sleep 1; \
		done
	@sleep 1; echo -n ".";
	@for i in {1..30}; \
		do \
		echo -n "."; \
		./healthcheck.sh $(MYSQL_NAME) 1>/dev/null && break; \
		sleep 1; \
		done; \
		echo
	@echo "Mysql is up and running."

postgres: clean-postgres
	$(DOCKER) run -d --rm -p 5432:5432 --name $(POSTGRES_NAME) -e POSTGRES_PASSWORD=$(POSTGRES_PASSWORD) -e PGPASSWORD=$(POSTGRES_PASSWORD) \
	  --health-cmd "pg_isready -U postgres" --health-interval 0 --health-retries 12 --health-start-period 10s \
	  $(POSTGRES_IMAGE)
	@$(MAKE) --no-print-directory wait-for-postgres
	$(DOCKER) exec -i $(POSTGRES_NAME) psql -U postgres < initdb.postgres.sql

wait-for-postgres:
	@echo "Waiting for postgres to start ... (max 180s)"
	@for i in {1..180}; \
		do \
		echo -n "."; \
		./healthcheck.sh $(POSTGRES_NAME) 1>/dev/null && break; \
		sleep 1; \
		done; \
		echo " waited $$i seconds"
	@./healthcheck.sh $(POSTGRES_NAME) 1>/dev/null
	@echo "Postgres is up and running."

build-irods:
	$(DOCKER) build -t $(IRODS_IMAGE) -f $(DOCKERFILE) --target $(TAG) --build-arg VERSION=$(VERSION) .

irods: clean-irods ssl build-irods
	$(DOCKER) run -d --rm --name $(IRODS_NAME) \
	  --hostname $(IRODS_HOST) \
	  -v $(PWD)/ssl:/ssl \
	  -e SERVER=$(IRODS_HOST) \
	  -e ROLE=$(ROLE) \
	  -e PROVIDER_SERVER=$(IRODS_HOST) \
	  -e ZONE=$(IRODS_ZONE) \
	  -e SRV_NEGOTIATION_KEY=$(SRV_NEGOTIATION_KEY) \
	  -e SRV_ZONE_KEY=$(SRV_ZONE_KEY) \
	  -e CTRL_PLANE_KEY=$(shell openssl rand -hex 16) \
	  -e DB_NAME=irods \
	  -e DB_USER=irods \
	  -e DB_PASSWORD=irods \
	  -e DB_SRV_HOST=$(DATABASE_HOST) \
	  -e SSL_CERTIFICATE_CHAIN_FILE=/ssl/$(INSTANCE)$(CONSUMER)/cert.pem \
	  -e SSL_CERTIFICATE_KEY_FILE=/ssl/$(INSTANCE)$(CONSUMER)/key.pem \
	  -e SSL_CA_BUNDLE=/ssl/ca-bundle.pem \
	  -e AMQP=admin:hunter2@$(RABBITMQ_HOST):5672 \
	  -e FEDERATION='$(FEDERATION)' \
	  --health-cmd "healthcheck" --health-interval 0 --health-retries 12 \
	  $(IRODS_IMAGE)
ifeq ($(LOG),1)
	$(DOCKER) logs -f $(IRODS_NAME)
else
	@$(MAKE) --no-print-directory wait-for-irods
	@echo "Irods is reachable at $(IRODS_HOST) inside the container"
endif

wait-for-irods:
	@echo "Waiting for irods to start ... (max 180s)"
	@for i in {1..180}; \
		do \
		echo -n "."; \
		./healthcheck.sh $(IRODS_NAME) 1>/dev/null && break; \
		sleep 1; \
		done; \
		echo " waited $$i seconds"
	@./healthcheck.sh $(IRODS_NAME) 1>/dev/null
	@echo "Irods is up and running."

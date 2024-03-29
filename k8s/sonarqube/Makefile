include ../crd.Makefile
include ../gcloud.Makefile
include ../var.Makefile

APP_ID ?= sonarqube-managed-updates
VERIFY_WAIT_TIMEOUT = 600

# The digest should be updated automatically, or tag <major>.<minor>.<path/build>
# should be available on GCP Marketplace.
# Use `.build/sonarqube/VERSION` target to fill the RELEASE variable.
SONAR_TAG ?= sha256:4a6886e3db2f93764a7a641f214ae52b2ca9ac5563c772f6f67206584abb0d53
POSTGRESQL_TAG ?= 9.6-kubernetes
METRICS_EXPORTER_TAG ?= v0.5.1

BUILD_ID := $(shell date --utc +%Y%m%d-%H%M%S)
TRACK ?= 7.7
RELEASE ?= 7.7.0-$(BUILD_ID)

$(info ---- TRACK = $(TRACK))
$(info ---- RELEASE = $(RELEASE))

APP_DEPLOYER_IMAGE ?= $(REGISTRY)/$(APP_ID)/deployer:$(RELEASE)
APP_DEPLOYER_IMAGE_TRACK_TAG ?= $(REGISTRY)/$(APP_ID)/deployer:$(TRACK)
APP_GCS_PATH ?= $(GCS_URL)/$(APP_ID)/$(TRACK)

NAME ?= $(APP_ID)-1

ifdef DB_PASSWORD
  DB_PASSWORD_FIELD = , "postgresql.db.password": "$(DB_PASSWORD)"
endif

ifdef METRICS_EXPORTER_ENABLED
  METRICS_EXPORTER_ENABLED_FIELD = , "metrics.enabled": $(METRICS_EXPORTER_ENABLED)
endif

APP_PARAMETERS ?= { \
  "name": "$(NAME)", \
  "namespace": "$(NAMESPACE)" \
  $(DB_PASSWORD) \
  $(METRICS_EXPORTER_ENABLED_FIELD) \
}

TESTER_IMAGE ?= $(REGISTRY)/$(APP_ID)/tester:$(RELEASE)

# app_v2.Makefile provides the main targets for installing the
# application.
# It requires several APP_* variables defined above, and thus
# must be included after.
include ../app_v2.Makefile

app/build:: .build/sonarqube/deployer \
            .build/sonarqube/sonarqube \
            .build/sonarqube/postgresql \
            .build/sonarqube/postgresql-exporter \
            .build/sonarqube/prometheus-to-sd \
            .build/sonarqube/tester \
            .build/sonarqube/VERSION


.build/sonarqube: | .build
	mkdir -p "$@"


.PHONY: .build/sonarqube/VERSION
.build/sonarqube/VERSION:
	docker run --rm --entrypoint=printenv marketplace.gcr.io/google/sonarqube7@$(SONAR_TAG) SONAR_VERSION


.build/sonarqube/deployer: deployer/* \
                           chart/sonarqube/* \
                           chart/sonarqube/templates/* \
                           schema.yaml \
                           .build/var/APP_DEPLOYER_IMAGE \
                           .build/var/APP_DEPLOYER_IMAGE_TRACK_TAG \
                           .build/var/MARKETPLACE_TOOLS_TAG \
                           .build/var/REGISTRY \
                           .build/var/TRACK \
                           .build/var/RELEASE \
                           | .build/sonarqube
	docker build \
	    --build-arg REGISTRY="$(REGISTRY)/$(APP_ID)" \
	    --build-arg TAG="$(RELEASE)" \
	    --build-arg MARKETPLACE_TOOLS_TAG="$(MARKETPLACE_TOOLS_TAG)" \
	    --tag "$(APP_DEPLOYER_IMAGE)" \
	    -f deployer/Dockerfile \
	    .
	docker tag "$(APP_DEPLOYER_IMAGE)" "$(APP_DEPLOYER_IMAGE_TRACK_TAG)"
	docker push "$(APP_DEPLOYER_IMAGE)"
	docker push "$(APP_DEPLOYER_IMAGE_TRACK_TAG)"
	@touch "$@"


.build/sonarqube/sonarqube: .build/var/REGISTRY \
                            .build/var/TRACK \
                            .build/var/RELEASE \
                            | .build/sonarqube
	docker pull marketplace.gcr.io/google/sonarqube7@$(SONAR_TAG)
	docker tag marketplace.gcr.io/google/sonarqube7@$(SONAR_TAG) \
	    "$(REGISTRY)/$(APP_ID):$(TRACK)"
	docker tag "$(REGISTRY)/$(APP_ID):$(TRACK)" \
	    "$(REGISTRY)/$(APP_ID):$(RELEASE)"
	docker push "$(REGISTRY)/$(APP_ID):$(TRACK)"
	docker push "$(REGISTRY)/$(APP_ID):$(RELEASE)"
	@touch "$@"


.build/sonarqube/postgresql: .build/var/REGISTRY \
                             .build/var/TRACK \
                             .build/var/RELEASE \
                             | .build/sonarqube
	docker pull marketplace.gcr.io/google/postgresql9:$(POSTGRESQL_TAG)
	docker tag marketplace.gcr.io/google/postgresql9:$(POSTGRESQL_TAG) \
	    "$(REGISTRY)/$(APP_ID)/postgresql:$(TRACK)"
	docker tag "$(REGISTRY)/$(APP_ID)/postgresql:$(TRACK)" \
	    "$(REGISTRY)/$(APP_ID)/postgresql:$(RELEASE)"
	docker push "$(REGISTRY)/$(APP_ID)/postgresql:$(TRACK)"
	docker push "$(REGISTRY)/$(APP_ID)/postgresql:$(RELEASE)"
	@touch "$@"


.build/sonarqube/postgresql-exporter: .build/var/REGISTRY \
                                      .build/var/TRACK \
                                      .build/var/RELEASE \
                                      | .build/sonarqube
	docker pull marketplace.gcr.io/google/postgresql9:exporter
	docker tag marketplace.gcr.io/google/postgresql9:exporter \
	    "$(REGISTRY)/$(APP_ID)/postgresql-exporter:$(TRACK)"
	docker tag "$(REGISTRY)/$(APP_ID)/postgresql-exporter:$(TRACK)" \
	    "$(REGISTRY)/$(APP_ID)/postgresql-exporter:$(RELEASE)"
	docker push "$(REGISTRY)/$(APP_ID)/postgresql-exporter:$(TRACK)"
	docker push "$(REGISTRY)/$(APP_ID)/postgresql-exporter:$(RELEASE)"
	@touch "$@"


.build/sonarqube/prometheus-to-sd: .build/var/REGISTRY \
                                   .build/var/TRACK \
                                   .build/var/RELEASE \
                                   | .build/sonarqube
	docker pull k8s.gcr.io/prometheus-to-sd:$(METRICS_EXPORTER_TAG)
	docker tag k8s.gcr.io/prometheus-to-sd:$(METRICS_EXPORTER_TAG) \
	    "$(REGISTRY)/$(APP_ID)/prometheus-to-sd:$(TRACK)"
	docker tag "$(REGISTRY)/$(APP_ID)/prometheus-to-sd:$(TRACK)" \
	    "$(REGISTRY)/$(APP_ID)/prometheus-to-sd:$(RELEASE)"
	docker push "$(REGISTRY)/$(APP_ID)/prometheus-to-sd:$(TRACK)"
	docker push "$(REGISTRY)/$(APP_ID)/prometheus-to-sd:$(RELEASE)"
	@touch "$@"


.build/sonarqube/tester: .build/var/TESTER_IMAGE \
                         $(shell find apptest -type f) \
                         | .build/sonarqube
	$(call print_target,$@)
	cd apptest/tester \
	    && docker build --tag "$(TESTER_IMAGE)" .
	docker push "$(TESTER_IMAGE)"
	@touch "$@"

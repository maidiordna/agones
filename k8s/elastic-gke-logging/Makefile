include ../crd.Makefile
include ../gcloud.Makefile
include ../var.Makefile

APP_ID ?= elastic-gke-logging-managed-updates
VERIFY_WAIT_TIMEOUT = 1200

# The digest should be updated automatically, or tag <major>.<minor>.<path/build>
# should be available on GCP Marketplace.
# Use `.build/elastic-gke-logging/VERSION` target to fill the RELEASE variable.
ELASTICSEARCH_TAG ?= sha256:077358140de4b64030d37fbd02d5217b5953dff5bc08bf2352dd5ae90b536978
KIBANA_TAG ?= 6.3
FLUENTD_TAG ?= 1.2
METRICS_EXPORTER_TAG ?= v0.5.1

BUILD_ID := $(shell date --utc +%Y%m%d-%H%M%S)
TRACK ?= 6.3
RELEASE ?= 6.3.2-$(BUILD_ID)

$(info ---- TRACK = $(TRACK))
$(info ---- RELEASE = $(RELEASE))

APP_DEPLOYER_IMAGE ?= $(REGISTRY)/$(APP_ID)/deployer:$(RELEASE)
APP_DEPLOYER_IMAGE_TRACK_TAG ?= $(REGISTRY)/$(APP_ID)/deployer:$(TRACK)
APP_GCS_PATH ?= $(GCS_URL)/$(APP_ID)/$(TRACK)

NAME ?= $(APP_ID)-1

ifdef ELASTICSEARCH_REPLICAS
  ELASTICSEARCH_REPLICAS_FIELD = , "elasticsearch.replicas": "$(ELASTICSEARCH_REPLICAS)"
endif

ifdef IMAGE_INIT
  IMAGE_INIT_FIELD = , "initImage": "$(IMAGE_INIT)"
endif

ifdef IMAGE_KIBANA
  IMAGE_KIBANA_FIELD = , "kibana.image": "$(IMAGE_KIBANA)"
endif

ifdef IMAGE_FLUENTD
  IMAGE_FLUENTD_FIELD = , "fluentd.image": "$(IMAGE_FLUENTD)"
endif

ifdef METRICS_EXPORTER_ENABLED
  METRICS_EXPORTER_ENABLED_FIELD = , "metrics.enabled": $(METRICS_EXPORTER_ENABLED)
endif

APP_PARAMETERS ?= { \
  "name": "$(NAME)", \
  "namespace": "$(NAMESPACE)" \
  $(ELASTICSEARCH_REPLICAS_FIELD) \
  $(IMAGE_INIT_FIELD) \
  $(IMAGE_KIBANA_FIELD) \
  $(IMAGE_FLUENTD_FIELD) \
  $(METRICS_EXPORTER_ENABLED_FIELD) \
}

TESTER_IMAGE ?= $(REGISTRY)/$(APP_ID)/tester:$(RELEASE)

# app_v2.Makefile provides the main targets for installing the
# application.
# It requires several APP_* variables defined above, and thus
# must be included after.
include ../app_v2.Makefile

app/build:: .build/elastic-gke-logging/deployer \
            .build/elastic-gke-logging/elasticsearch \
            .build/elastic-gke-logging/kibana \
            .build/elastic-gke-logging/fluentd \
            .build/elastic-gke-logging/ubuntu16_04 \
            .build/elastic-gke-logging/prometheus-to-sd \
            .build/elastic-gke-logging/tester \
            .build/elastic-gke-logging/VERSION


.build/elastic-gke-logging: | .build
	mkdir -p "$@"


.PHONY: .build/elastic-gke-logging/VERSION
.build/elastic-gke-logging/VERSION:
	docker run --rm --entrypoint=printenv marketplace.gcr.io/google/elasticsearch6@$(ELASTICSEARCH_TAG) ELASTICSEARCH_VERSION


.build/elastic-gke-logging/deployer: deployer/* \
                                     chart/elastic-gke-logging/* \
                                     chart/elastic-gke-logging/templates/* \
                                     schema.yaml \
                                     .build/var/APP_DEPLOYER_IMAGE \
                                     .build/var/APP_DEPLOYER_IMAGE_TRACK_TAG \
                                     .build/var/MARKETPLACE_TOOLS_TAG \
                                     .build/var/REGISTRY \
                                     .build/var/TRACK \
                                     .build/var/RELEASE \
                                     | .build/elastic-gke-logging
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


.build/elastic-gke-logging/elasticsearch: .build/var/REGISTRY \
                                          .build/var/TRACK \
                                          .build/var/RELEASE \
                                          | .build/elastic-gke-logging
	docker pull marketplace.gcr.io/google/elasticsearch6@$(ELASTICSEARCH_TAG)
	docker tag marketplace.gcr.io/google/elasticsearch6@$(ELASTICSEARCH_TAG) \
	    "$(REGISTRY)/$(APP_ID):$(TRACK)"
	docker tag "$(REGISTRY)/$(APP_ID):$(TRACK)" \
	    "$(REGISTRY)/$(APP_ID):$(RELEASE)"
	docker push "$(REGISTRY)/$(APP_ID):$(TRACK)"
	docker push "$(REGISTRY)/$(APP_ID):$(RELEASE)"
	@touch "$@"


.build/elastic-gke-logging/kibana: .build/var/REGISTRY \
                                   .build/var/TRACK \
                                   .build/var/RELEASE \
                                   | .build/elastic-gke-logging
	docker pull marketplace.gcr.io/google/kibana6:$(KIBANA_TAG)
	docker tag marketplace.gcr.io/google/kibana6:$(KIBANA_TAG) \
	    "$(REGISTRY)/$(APP_ID)/kibana:$(TRACK)"
	docker tag "$(REGISTRY)/$(APP_ID)/kibana:$(TRACK)" \
	    "$(REGISTRY)/$(APP_ID)/kibana:$(RELEASE)"
	docker push "$(REGISTRY)/$(APP_ID)/kibana:$(TRACK)"
	docker push "$(REGISTRY)/$(APP_ID)/kibana:$(RELEASE)"
	@touch "$@"


.build/elastic-gke-logging/fluentd: .build/var/REGISTRY \
                                    .build/var/TRACK \
                                    .build/var/RELEASE \
                                    | .build/elastic-gke-logging
	docker pull marketplace.gcr.io/google/fluentd1:$(FLUENTD_TAG)
	docker tag marketplace.gcr.io/google/fluentd1:$(FLUENTD_TAG) \
	    "$(REGISTRY)/$(APP_ID)/fluentd:$(TRACK)"
	docker tag "$(REGISTRY)/$(APP_ID)/fluentd:$(TRACK)" \
	    "$(REGISTRY)/$(APP_ID)/fluentd:$(RELEASE)"
	docker push "$(REGISTRY)/$(APP_ID)/fluentd:$(TRACK)"
	docker push "$(REGISTRY)/$(APP_ID)/fluentd:$(RELEASE)"
	@touch "$@"


.build/elastic-gke-logging/ubuntu16_04: .build/var/REGISTRY \
                                        .build/var/TRACK \
                                        .build/var/RELEASE \
                                        | .build/elastic-gke-logging
	docker pull marketplace.gcr.io/google/ubuntu1604:latest
	docker tag marketplace.gcr.io/google/ubuntu1604:latest \
	    "$(REGISTRY)/$(APP_ID)/ubuntu16_04:$(TRACK)"
	docker tag "$(REGISTRY)/$(APP_ID)/ubuntu16_04:$(TRACK)" \
	    "$(REGISTRY)/$(APP_ID)/ubuntu16_04:$(RELEASE)"
	docker push "$(REGISTRY)/$(APP_ID)/ubuntu16_04:$(TRACK)"
	docker push "$(REGISTRY)/$(APP_ID)/ubuntu16_04:$(RELEASE)"
	@touch "$@"


.build/elastic-gke-logging/prometheus-to-sd: .build/var/REGISTRY \
                                             .build/var/TRACK \
                                             .build/var/RELEASE \
                                             | .build/elastic-gke-logging
	docker pull k8s.gcr.io/prometheus-to-sd:$(METRICS_EXPORTER_TAG)
	docker tag k8s.gcr.io/prometheus-to-sd:$(METRICS_EXPORTER_TAG) \
	    "$(REGISTRY)/$(APP_ID)/prometheus-to-sd:$(TRACK)"
	docker tag "$(REGISTRY)/$(APP_ID)/prometheus-to-sd:$(TRACK)" \
	    "$(REGISTRY)/$(APP_ID)/prometheus-to-sd:$(RELEASE)"
	docker push "$(REGISTRY)/$(APP_ID)/prometheus-to-sd:$(TRACK)"
	docker push "$(REGISTRY)/$(APP_ID)/prometheus-to-sd:$(RELEASE)"
	@touch "$@"


.build/elastic-gke-logging/tester: .build/var/TESTER_IMAGE \
                                   $(shell find apptest -type f) \
                                   | .build/elastic-gke-logging
	$(call print_target,$@)
	cd apptest/tester \
	    && docker build --tag "$(TESTER_IMAGE)" .
	docker push "$(TESTER_IMAGE)"
	@touch "$@"

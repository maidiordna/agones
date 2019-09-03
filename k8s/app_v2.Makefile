#
# Used with deployer schema v2.
#

ifndef __APP_V2_MAKEFILE__

__APP_V2_MAKEFILE__ := included


makefile_dir := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
include $(makefile_dir)/common.Makefile
include $(makefile_dir)/var.Makefile

VERIFY_WAIT_TIMEOUT = 600

##### Common variables #####
APP_DEPLOYER_IMAGE ?= $(REGISTRY)/$(APP_ID)/deployer:$(RELEASE)
APP_DEPLOYER_IMAGE_TRACK_TAG ?= $(REGISTRY)/$(APP_ID)/deployer:$(TRACK)
TESTER_IMAGE ?= $(REGISTRY)/$(APP_ID)/tester:$(RELEASE)
APP_GCS_PATH ?= $(GCS_URL)/$(APP_ID)/$(TRACK)

SOURCE_REGISTRY ?= marketplace.gcr.io/google

##### Validations and Information #####

ifndef APP_ID
$(error APP_ID must be defined)
endif

$(info ---- APP_ID = $(APP_ID))

ifndef APP_GCS_PATH
$(error APP_GCS_PATH must be defined)
endif

$(info ---- APP_GCS_PATH = $(APP_GCS_PATH))

ifndef APP_DEPLOYER_IMAGE
$(error APP_DEPLOYER_IMAGE must be defined)
endif

$(info ---- APP_DEPLOYER_IMAGE = $(APP_DEPLOYER_IMAGE))

$(info ---- TRACK = $(TRACK))
$(info ---- RELEASE = $(RELEASE))
$(info ---- APP IMAGE = $(image-$(APP_ID)))


##### Helper functions #####


# Extracts the name property from APP_PARAMETERS.
define name_parameter
$(shell echo '$(APP_PARAMETERS)' \
    | docker run -i --entrypoint=/bin/print_config.py --rm $(APP_DEPLOYER_IMAGE) --values_mode stdin --xtype NAME)
endef


# Extracts the namespace property from APP_PARAMETERS.
define namespace_parameter
$(shell echo '$(APP_PARAMETERS)' \
    | docker run -i --entrypoint=/bin/print_config.py --rm $(APP_DEPLOYER_IMAGE) --values_mode stdin --xtype NAMESPACE)
endef


##### Helper targets #####


.build/app: | .build
	mkdir -p "$@"


# (1) Always update the dev script to make sure it's up to date.
# There isn't currently a way to detect if the dev container has changed.
# (2) The mpdev script is first copied to the / tmp directory and
# then moved to the target path due to the "Text file busy" error.
.PHONY: .build/app/dev
.build/app/dev: .build/var/MARKETPLACE_TOOLS_TAG \
              | .build/app
	@docker run \
	    "gcr.io/cloud-marketplace-tools/k8s/dev:$(MARKETPLACE_TOOLS_TAG)" \
	    cat /scripts/dev > "/tmp/dev"
	@mv "/tmp/dev" "$@"
	@chmod a+x "$@"


app/build:: $(APP_ID) \
            .build/$(APP_ID)/deployer \
            .build/images \
            .build/$(APP_ID)/tester \
            .build/$(APP_ID)/VERSION


.build/images: $(TARGETS)


.build/$(APP_ID): | .build
	mkdir -p "$@"


.build/$(APP_ID)/deployer: deployer/* \
                           chart/$(APP_ID)/* \
                           chart/$(APP_ID)/templates/* \
                           schema.yaml \
                           .build/var/APP_DEPLOYER_IMAGE \
                           .build/var/APP_DEPLOYER_IMAGE_TRACK_TAG \
                           .build/var/MARKETPLACE_TOOLS_TAG \
                           .build/var/REGISTRY \
                           .build/var/TRACK \
                           .build/var/RELEASE \
                           | .build/$(APP_ID)
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


.PHONY: $(APP_ID)
$(APP_ID): .build/var/REGISTRY \
           .build/var/TRACK \
           .build/var/RELEASE \
           | .build/$(APP_ID)
	docker pull $(image-$@)
	docker tag $(image-$@) "$(REGISTRY)/$@:$(TRACK)"
	docker tag $(image-$@) "$(REGISTRY)/$@:$(RELEASE)"
	docker push "$(REGISTRY)/$@:$(TRACK)"
	docker push "$(REGISTRY)/$@:$(RELEASE)"


$(TARGETS): .build/var/REGISTRY \
            .build/var/TRACK \
            .build/var/RELEASE \
            | .build/$(APP_ID)
	docker pull $(image-$@)
	docker tag $(image-$@) "$(REGISTRY)/$(APP_ID)/$@:$(TRACK)"
	docker tag $(image-$@) "$(REGISTRY)/$(APP_ID)/$@:$(RELEASE)"
	docker push "$(REGISTRY)/$(APP_ID)/$@:$(TRACK)"
	docker push "$(REGISTRY)/$(APP_ID)/$@:$(RELEASE)"


.build/$(APP_ID)/tester: .build/var/TESTER_IMAGE \
                              $(shell find apptest -type f) \
                              | .build/$(APP_ID)
	$(call print_target,$@)
	cd apptest/tester \
		&& docker build --tag "$(TESTER_IMAGE)" .
	docker push "$(TESTER_IMAGE)"
	@touch "$@"


########### Main  targets ###########


# Builds the application containers and push them to the registry.
# Including Makefile can extend this target. This target is
# a prerequisite for install.
.PHONY: app/build
app/build:: ;


.PHONY: app/publish
app/publish:: app/build \
              .build/var/APP_DEPLOYER_IMAGE \
              .build/var/APP_GCS_PATH \
              .build/var/MARKETPLACE_TOOLS_TAG \
              | .build/app/dev
	$(call print_target)
	.build/app/dev publish \
	        --deployer_image='$(APP_DEPLOYER_IMAGE)' \
	        --gcs_repo='$(APP_GCS_PATH)'


# Installs the application into target namespace on the cluster.
.PHONY: app/install
app/install:: app/publish \
              .build/var/APP_DEPLOYER_IMAGE \
              .build/var/APP_PARAMETERS \
              .build/var/MARKETPLACE_TOOLS_TAG \
              | .build/app/dev
	$(call print_target)
	.build/app/dev install \
	        --version_meta_file='$(APP_GCS_PATH)/$(RELEASE).yaml' \
	        --parameters='$(APP_PARAMETERS)'

# Installs the application into target namespace on the cluster.
.PHONY: app/install-test
app/install-test:: app/publish \
                   .build/var/APP_DEPLOYER_IMAGE \
                   .build/var/APP_PARAMETERS \
                   .build/var/MARKETPLACE_TOOLS_TAG \
	           | .build/app/dev
	$(call print_target)
	.build/app/dev install \
	        --deployer='$(APP_DEPLOYER_IMAGE)' \
	        --parameters='$(APP_PARAMETERS)' \
	        --entrypoint="/bin/deploy_with_tests.sh"


# Uninstalls the application from the target namespace on the cluster.
.PHONY: app/uninstall
app/uninstall: .build/var/APP_DEPLOYER_IMAGE \
               .build/var/APP_PARAMETERS
	$(call print_target)
	kubectl delete 'application/$(NAME)' \
	    --namespace='$(NAMESPACE)' \
	    --ignore-not-found


# Runs the verification pipeline.
.PHONY: app/verify
app/verify: app/publish \
            .build/var/APP_DEPLOYER_IMAGE \
            .build/var/APP_PARAMETERS \
            .build/var/MARKETPLACE_TOOLS_TAG \
            | .build/app/dev
	$(call print_target)
	.build/app/dev verify \
	          --deployer='$(APP_DEPLOYER_IMAGE)' \
	          --parameters='$(APP_PARAMETERS)' \
	          --wait_timeout="$(VERIFY_WAIT_TIMEOUT)"


# Runs diagnostic tool to make sure your environment is properly setup.
.PHONY: app/doctor
app/doctor: | .build/app/dev
	$(call print_target)
	.build/app/dev doctor


endif

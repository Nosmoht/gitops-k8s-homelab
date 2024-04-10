SOURCE_DIR := source
BASE_DIR   := base

SOURCES := $(wildcard $(SOURCE_DIR)/*/*/kustomization.yaml)
BASE_DIRS := $(patsubst $(SOURCE_DIR)/%,$(BASE_DIR)/%,$(dir $(SOURCES)))

# Cluster API provider versions
# Cluster API bootstrap provider Talos version
CLUSTER_API_BOOTSTRAP_PROVIDER_NAME ?= talos
CLUSTER_API_BOOTSTRAP_PROVIDER_VERSION ?= v0.6.4
# Cluster API control plane provider Talos version
CLUSTER_API_CONTROL_PLANE_PROVIDER_NAME ?= talos
CLUSTER_API_CONTROL_PLANE_PROVIDER_VERSION ?= v0.5.5
# Cluster API infrastructure provider Sidero version
CLUSTER_API_INFRASTRUCTURE_PROVIDER_NAME ?= sidero
CLUSTER_API_INFRASTRUCTURE_PROVIDER_VERSION =? v0.6.3

MANAGEMENT_CLUSTER_MANIFESTS_DIR = overlay/management

.PHONY: all clean base help $(BASE_DIRS)

all: base

base: $(BASE_DIRS)

$(BASE_DIRS):
	@echo "Building target: $@"
	@mkdir -p $@
	@kustomize build $(patsubst $(BASE_DIR)/%,$(SOURCE_DIR)/%,$@) --output $@
	@echo "Initializing kustomize in $@"; cd $@ && (rm kustomization.yaml || true) && kustomize init --autodetect

clean:
	@rm -rf $(BASE_DIR)

# Define pattern rule to handle individual targets
$(BASE_DIR)/%: $(SOURCE_DIR)/%
	@:

# Define pattern rule to handle shorthand targets
%/:
	@make base/$*

# Declare individual targets as phony
$(foreach dir,$(BASE_DIRS),$(eval $(dir)_phony:;@:))
.PHONY: $(foreach dir,$(BASE_DIRS),$(dir)_phony)

# Help target
help:
	@echo "Available targets:"
	@echo "  - all:           Build all targets"
	@echo "  - base:          Build all base directories"
	$(foreach dir,$(BASE_DIRS),echo "  - $(dir):";)
	@echo "  - clean:         Clean up generated base directories"

management-cluster-manifest-dir:
	 mkdir -p $(MANAGEMENT_CLUSTER_MANIFESTS_DIR)

cluster-api-core-manifests:
	clusterctl generate provider --core cluster-api:v1.6.3 --write-to overlay/sidero/cluster-api.yaml
	(cd overlay/sidero && kustomize init --autodetect)

cabpt-manifests: management-cluster-manifest-dir
	mkdir -p $(MANAGEMENT_CLUSTER_MANIFESTS_DIR)/cabpt-system && \
	cd $(MANAGEMENT_CLUSTER_MANIFESTS_DIR)/cabpt-system && \
	clusterctl generate provider \
		--bootstrap $(CLUSTER_API_BOOTSTRAP_PROVIDER_NAME):$(CLUSTER_API_BOOTSTRAP_PROVIDER_VERSION) \
		--write-to $(CLUSTER_API_BOOTSTRAP_PROVIDER_NAME)-$(CLUSTER_API_BOOTSTRAP_PROVIDER_VERSION).yaml && \
	kustomize init --autodetect

cacppt-manifests:
	clusterctl generate provider --control-plane $(CLUSTER_API_CONTROL_PLANE_PROVIDER_NAME):$(CLUSTER_API_CONTROL_PLANE_PROVIDER_VERSION)

sidero-manifests:
	SIDERO_CONTROLLER_MANAGER_AUTO_BMC_SETUP=false \
	SIDERO_CONTROLLER_MANAGER_HOST_NETWORK=true \
	SIDERO_CONTROLLER_MANAGER_DEPLOYMENT_STRATEGY=Recreate \
	SIDERO_CONTROLLER_MANAGER_API_ENDPOINT=192.168.2.60 \
	SIDERO_CONTROLLER_MANAGER_SIDEROLINK_ENDPOINT=192.168.2.60 \
	clusterctl generate provider --infrastructure sidero:$(CAIPS_SIDERO_VERSION)
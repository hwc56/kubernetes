# Copyright 2016 The Kubernetes Authors All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License

# This sets up a Photon Controller with the tenant, project, flavors
# and image that are needed to deploy Kubernetes with kube-up.
#
# This is not meant to be used in production: it creates resource tickets
# (quotas) that are arbitrary and not likely to work in your environment.
# However, it may be a quick way to get your environment set up to try out
# a Kubernetes installation.
#
# It uses the names for the tenant, project, and flavors as specified in the
# config-common.sh file
#
# If you want to do this by hand, this script is equivalent to the following
# Photon Controller commands (assuming you haven't edited config-common.sh
# to change the names)
#
# photon target set https://192.0.2.2
# photon tenant create kube-tenant
# photon tenant set kube-tenant
# photon resource-ticket create --tenant kube-tenant --name kube-resources --limits "vm.memory 1000 GB, vm 1000 COUNT"
# photon project create --tenant kube-tenant --resource-ticket kube-resources --name kube-project --limits "vm.memory 1000 GB, vm 1000 COUNT"
# photon project set kube-project
# photon -n flavor create --name "kube-vm" --kind "vm" --cost "vm 1 COUNT, vm.cpu 1 COUNT, vm.memory 2 GB"
# photon -n flavor create --name "kube-disk" --kind "ephemeral-disk" --cost "ephemeral-disk 1 COUNT"
# photon image create kube.vmdk -n kube-image -i EAGER
#
# Note that the kube.vmdk can be downloaded as specified in the documentation.

KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../..
source ${KUBE_ROOT}/cluster/photon-controller/util.sh

function main {
    verify-cmd-in-path photon
    set-target
    create-tenant
    create-project
    create-vm-flavor "${PHOTON_MASTER_FLAVOR}" "${SETUP_MASTER_FLAVOR_SPEC}"
    if [ "${PHOTON_MASTER_FLAVOR}" != "${PHOTON_NODE_FLAVOR}" ]; then
        create-vm-flavor "${PHOTON_NODE_FLAVOR}" "${SETUP_NODE_FLAVOR_SPEC}"
    fi
    create-disk-flavor
    create-image
}

function parse-cmd-line {
    PHOTON_TARGET=${1:-""}
    PHOTON_VMDK=${2:-""}

    if [ "$PHOTON_TARGET" = "" -o "$PHOTON_VMDK" = "" ]; then
        echo "Usage: setup-prereq <photon target> <path-to-kube-vmdk>"
        echo "Target should be a URL like https://192.0.2.1"
        echo ""
        echo "This will create the following, based on the configuration in config-common.sh"
        echo "    * A tenant named ${PHOTON_TENANT}"
        echo "    * A project named ${PHOTON_PROJECT}"
        echo "    * A VM flavor named ${PHOTON_MASTER_FLAVOR}"
        echo "    * A disk flavor named ${PHOTON_DISK_FLAVOR}"
        echo "It will also upload the Kube VMDK"
        echo ""
        echo "It creates the tenant with a resource ticket (quota) that may"
        echo "be inappropriate for your environment. For a production"
        echo "environment, you should configure these to match your"
        echo "environment."
        exit 1
    fi

    echo "Photon Target: ${PHOTON_TARGET}"
    echo "Photon VMDK: ${PHOTON_VMDK}"
}

function set-target {
    $PHOTON target set ${PHOTON_TARGET} > /dev/null 2>&1
}

function create-tenant {
    local rc=0

    $PHOTON tenant list | grep "\t${PHOTON_TENANT}$" > /dev/null 2>&1 || rc=$?
    if [ $rc -eq 0 ]; then
        echo "Tenant ${PHOTON_TENANT} already made, skipping"
    else
        echo "Making tenant ${PHOTON_TENANT}"
        $PHOTON tenant create ${PHOTON_TENANT} > /dev/null 2>&1
    fi
    $PHOTON tenant set ${PHOTON_TENANT} > /dev/null 2>&1
}

function create-project {
    local rc=0

    $PHOTON project list | grep "\t${PHOTON_PROJECT}\t" > /dev/null 2>&1  || rc=$?
    if [ $rc -eq 0 ]; then
        echo "Project ${PHOTON_PROJECT} already made, skipping"
    else
        echo "Making project ${PHOTON_PROJECT}"
        $PHOTON resource-ticket create --tenant ${PHOTON_TENANT} --name ${PHOTON_TENANT}-resources \
            --limits "${SETUP_TICKET_SPEC}" > /dev/null 2>&1
        $PHOTON project create --tenant ${PHOTON_TENANT} --resource-ticket ${PHOTON_TENANT}-resources \
            --name ${PHOTON_PROJECT} --limits "${SETUP_PROJECT_SPEC}" > /dev/null 2>&1
    fi
    $PHOTON project set ${PHOTON_PROJECT}
}

function create-vm-flavor {
    local flavor_name=$1
    local flavor_spec=$2
    local rc=0

    $PHOTON flavor list | grep "\t${flavor_name}\t" > /dev/null 2>&1 || rc=$?
    if [ $rc -eq 0 ]; then
        echo "Flavor ${flavor_name} already made, skipping"
    else
        echo "Making VM flavor ${flavor_name}"
        $PHOTON -n flavor create --name "${flavor_name}" --kind "vm" --cost "${flavor_spec}" > /dev/null 2>&1
    fi
}

function create-disk-flavor {
    local rc=0

    $PHOTON flavor list | grep "\t${PHOTON_DISK_FLAVOR}\t" > /dev/null 2>&1  || rc=$?
    if [ $rc -eq 0 ]; then
        echo "Flavor ${PHOTON_DISK_FLAVOR} already made, skipping"
    else
        echo "Making disk flavor ${PHOTON_DISK_FLAVOR}"
        $PHOTON -n flavor create --name ${PHOTON_DISK_FLAVOR} --kind "ephemeral-disk" --cost "${SETUP_DISK_FLAVOR_SPEC}" > /dev/null 2>&1
    fi
}

function create-image {
    local rc=0
    local image_id=""

    $PHOTON image list | grep "\tkube-image\t" > /dev/null 2>&1 || rc=$?
    if [ $rc -eq 0 ]; then
        echo "Image ${PHOTON_VMDK} already uploaded, skipping"
    else
        echo "Uploading image ${PHOTON_VMDK}"
        $PHOTON image create $PHOTON_VMDK -n ${PHOTON_IMAGE} -i EAGER > /dev/null 2>&1
    fi
}

parse-cmd-line $@
main

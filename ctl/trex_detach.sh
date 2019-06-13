#!/bin/bash
#MAINTAINER erez@shrewdthings.com

CFG_DIR='/opt/trex/start'
source $CFG_DIR/trex_env.sh
JSON_CFG=$(jq -r '.' $JSON_CFG_FILE)

pkill rex

JQ_EXPR=$(printf '."trex-boxes"[%u].client.devpci' "$TREX_BOX_ID")
DEV_PCI=$(jq -r "$JQ_EXPR" <<< $JSON_CFG)
JQ_EXPR=$(printf '."trex-boxes"[%u].client.devdriver' "$TREX_BOX_ID")
DEV_DRIVER=$(jq -r "$JQ_EXPR" <<< $JSON_CFG)
./dpdk_nic_bind.py -b $DEV_DRIVER $DEV_PCI

JQ_EXPR=$(printf '."trex-boxes"[%u].server.devpci' "$TREX_BOX_ID")
DEV_PCI=$(jq -r "$JQ_EXPR" <<< $JSON_CFG)
JQ_EXPR=$(printf '."trex-boxes"[%u].client.devdriver' "$TREX_BOX_ID")
DEV_DRIVER=$(jq -r "$JQ_EXPR" <<< $JSON_CFG)
./dpdk_nic_bind.py -b $DEV_DRIVER $DEV_PCI

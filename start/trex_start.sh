#!/bin/bash
#MAINTAINER erez@shrewdthings.com

CFG_DIR='/opt/trex/start'
source $CFG_DIR/trex_env.sh
JSON_CFG=$(jq -r '.' $JSON_CFG_FILE)
DEV_PMD='igb_uio'

pkill rex


JQ_EXPR=$(printf '."trex-boxes"[%u].client.devpci' "$TREX_BOX_ID")
DEV_PCI=$(jq -r "$JQ_EXPR" <<< $JSON_CFG)
./dpdk_nic_bind.py -b $DEV_PMD $DEV_PCI

JQ_EXPR=$(printf '."trex-boxes"[%u].server.devpci' "$TREX_BOX_ID")
DEV_PCI=$(jq -r "$JQ_EXPR" <<< $JSON_CFG)
./dpdk_nic_bind.py -b $DEV_PMD $DEV_PCI

./t-rex-64 -i --prom --no-scapy-server --cfg $YAML_CFG_FILE

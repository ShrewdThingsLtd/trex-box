#!/bin/bash
#MAINTAINER erez@shrewdthings.com

ACTION=$1
TREX_BOX_INST=$(hostname)

ROOTDIR=$PWD
CFG_DIR='/opt/trex/cfg'
JSON_CFG_FILE="$CFG_DIR/cfg.json"
YAML_CFG_FILE="$CFG_DIR/${TREX_BOX_INST}-cfg.yaml"

trex_show_status() {

	echo
	echo "$TREX_BOX_INST devices:"
	echo '-------------'
	cd $ROOTDIR
	./dpdk_nic_bind.py -s
	echo
}

trex_dev_bind() {

	local DEV_TYPE=$1
	local DEV_DRIVER=$2
	
	local JQ_EXPR=$(printf '."trex-boxes"[%u].%s.devpci' "$TREX_BOX_ID" "$DEV_TYPE")
	local DEV_PCI=$(jq -r "$JQ_EXPR" <<< $JSON_CFG)
	cd $ROOTDIR
	if [[ -z $DEV_DRIVER ]]
	then
		local JQ_EXPR=$(printf '."trex-boxes"[%u].%s.devdriver' "$TREX_BOX_ID" "$DEV_TYPE")
		local DEV_DRIVER=$(jq -r "$JQ_EXPR" <<< $JSON_CFG)
		./dpdk_nic_bind.py -b $DEV_DRIVER $DEV_PCI	
	else
		./dpdk_nic_bind.py -b $DEV_DRIVER $DEV_PCI	
	fi
}

trex_restart() {

	pkill rex
	trex_dev_bind client igb_uio
	trex_dev_bind server igb_uio
	cd $ROOTDIR
	./t-rex-64 -i --prom --no-scapy-server --cfg $YAML_CFG_FILE
}

trex_stop() {

	pkill rex
	trex_dev_bind client
	trex_dev_bind server
}

if [[ $ACTION == 'show_status' ]]
then
	trex_show_status
	exit
fi

JSON_CFG=$(jq -r '.' $JSON_CFG_FILE)

if [[ $ACTION == 'restart' ]]
then
	trex_restart
elif [[ $ACTION == 'stop' ]]
then
	trex_stop
fi

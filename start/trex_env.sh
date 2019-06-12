#!/bin/bash
#MAINTAINER erez@shrewdthings.com

JSON_CFG_FILE=$CFG_DIR/cfg.json
YAML_CFG_FILE=$CFG_DIR/cfg.yaml

get_dev_env() {

	local DEV_OBJ="$1"
	
	local JQ_EXPR=$(printf '%s.devname' "$DEV_OBJ")
	DEV_NAME=$(jq -r "$JQ_EXPR" <<< $JSON_CFG)
	DEV_DRIVER=$(ethtool -i $DEV_NAME | sed -n 's~^driver\:\s\s*\(..*\)$~\1~p')
	DEV_PCI=$(ethtool -i $DEV_NAME | sed -n 's~^bus-info\:\s\s*\(..*\)$~\1~p')
	DEV_MAC=$(ip -o link show dev $DEV_NAME | awk '{print $(NF-2)}')
}

update_dev_json_cfg() {

	local DEV_OBJ="$1"
	
	JQ_EXPR=$(printf '%s.devdriver |= "%s"' "$DEV_OBJ" "$DEV_DRIVER")
	JSON_CFG=$(jq "$JQ_EXPR" <<< $JSON_CFG)
	JQ_EXPR=$(printf '%s.devpci |= "%s"' "$DEV_OBJ" "$DEV_PCI")
	JSON_CFG=$(jq "$JQ_EXPR" <<< $JSON_CFG)
	JQ_EXPR=$(printf '%s.devmac |= "%s"' "$DEV_OBJ" "$DEV_MAC")
	JSON_CFG=$(jq "$JQ_EXPR" <<< $JSON_CFG)
}

update_dev_yaml_cfg() {

	local DEV_IDX=$1
	local PEER_IDX=$2
	
	yq w -i $YAML_CFG_FILE [0].interfaces[$DEV_IDX] $DEV_PCI
	yq w -i $YAML_CFG_FILE [0].port_info[$DEV_IDX].src_mac $DEV_MAC
	yq w -i $YAML_CFG_FILE [0].port_info[$PEER_IDX].dest_mac $DEV_MAC
}

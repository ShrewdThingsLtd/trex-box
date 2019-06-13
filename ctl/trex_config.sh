#!/bin/bash
#MAINTAINER erez@shrewdthings.com

ACTION=$1
TREX_BOX_INST=$(hostname)

ROOTDIR=$PWD
CTL_DIR='/opt/trex/ctl'
CFG_DIR='/opt/trex/cfg'
TREX_BOX_CFG_CMD="$CFG_DIR/${TREX_BOX_INST}-cfg.sh"
JSON_CFG_FILE="$CFG_DIR/cfg.json"
YAML_CFG_FILE="$CFG_DIR/${TREX_BOX_INST}-cfg.yaml"
cp -f $CTL_DIR/cfg.yaml $YAML_CFG_FILE

if [ ! -f $JSON_CFG_FILE ]
then
	JSON_CFG=$(jq -r '.' $CTL_DIR/cfg.json)
else
	JSON_CFG=$(jq -r '.' $JSON_CFG_FILE)
fi

get_dev_name() {

	local DEV_OBJ="$1"
	
	local JQ_EXPR=$(printf '%s.devname' "$DEV_OBJ")
	DEV_NAME=$(jq -r "$JQ_EXPR" <<< $JSON_CFG)
}

get_dev_env() {

	local DEV_OBJ="$1"

	get_dev_name "$DEV_OBJ"
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

update_dev_cfg() {

	local DEV_TYPE="$1"
	
	local JQ_EXPR=$(printf '."trex-boxes"[%u].%s' "$TREX_BOX_ID" "$DEV_TYPE")
	get_dev_env "$JQ_EXPR"
	update_dev_json_cfg "$JQ_EXPR"
	if [[ $DEV_TYPE == 'client' ]]
	then
		update_dev_yaml_cfg 0 1
	elif [[ $DEV_TYPE == 'server' ]]
	then
		update_dev_yaml_cfg 1 0
	fi
}

write_cfg_cmd() {

local JQ_EXPR=$(printf '."trex-boxes"[%u].client' "$TREX_BOX_ID")
get_dev_name "$JQ_EXPR"
local DEV_NAME_CLIENT=$DEV_NAME
local JQ_EXPR=$(printf '."trex-boxes"[%u].server' "$TREX_BOX_ID")
get_dev_name "$JQ_EXPR"
local DEV_NAME_SERVER=$DEV_NAME

cat > $TREX_BOX_CFG_CMD <<EOF
#!/bin/bash
ACTION=\$1
if [[ \$ACTION == 'detach_devs' ]]
then
ip netns exec $TREX_BOX_INST ip link set dev $DEV_NAME_CLIENT netns 1
ip link set dev $DEV_NAME_CLIENT up
ip netns exec $TREX_BOX_INST ip link set dev $DEV_NAME_SERVER netns 1
ip link set dev $DEV_NAME_SERVER up
elif [[ \$ACTION == 'attach_devs' ]]
then
ip link set dev $DEV_NAME_CLIENT netns $TREX_BOX_INST
ip netns exec $TREX_BOX_INST ip link set dev $DEV_NAME_CLIENT up
ip link set dev $DEV_NAME_SERVER netns $TREX_BOX_INST
ip netns exec $TREX_BOX_INST ip link set dev $DEV_NAME_SERVER up
fi
EOF
chmod +x $TREX_BOX_CFG_CMD
}

rebuild_pmd() {

	cd $ROOTDIR/ko/src
	make clean
	make
	make install
	cd $ROOTDIR
}

if [[ $ACTION == 'preconfig' ]]
then
	rebuild_pmd
	write_cfg_cmd
	exit
fi

update_dev_cfg client
update_dev_cfg server
cat <<< "$(jq -r '.' <<< $JSON_CFG)" > $JSON_CFG_FILE

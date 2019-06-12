#!/bin/bash
#MAINTAINER erez@shrewdthings.com

ROOTDIR=$PWD
CFG_DIR='/opt/trex/start'
source $CFG_DIR/trex_env.sh
JSON_CFG=$(jq -r '.' $JSON_CFG_FILE)

pkill rex

JQ_EXPR=$(printf '."trex-boxes"[%u].client' "$TREX_BOX_ID")
get_dev_env "$JQ_EXPR"
update_dev_json_cfg "$JQ_EXPR"
update_dev_yaml_cfg $YAML_CFG_FILE 0 1

JQ_EXPR=$(printf '."trex-boxes"[%u].server' "$TREX_BOX_ID")
get_dev_env "$JQ_EXPR"
update_dev_json_cfg "$JQ_EXPR"
update_dev_yaml_cfg $YAML_CFG_FILE 1 0

cat <<< "$(jq -r '.' <<< $JSON_CFG)" > $JSON_CFG_FILE

cd $ROOTDIR/ko/src
make clean
make
make install
cd $ROOTDIR

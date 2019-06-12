#!/bin/bash

TREX_BOX_ID=${1:-0}
ACTION=${2:-'start'}
ROOTDIR=$PWD
CFG_DIR=$ROOTDIR/start
source $CFG_DIR/trex_env.sh
JSON_CFG=$(jq -r '.' $JSON_CFG_FILE)
TREX_BOX_WORKDIR='/opt/trex/v2.56'
TREX_BOX_IMG='trex-box-img'
TREX_BOX_INST="trex-box${TREX_BOX_ID}"

show_devices() {

	echo
	echo 'Host devices:'
	echo '-------------'
	ip addr
	echo
	echo "$TREX_BOX_INST devices:"
	echo '-------------'
	docker exec $TREX_BOX_INST ./dpdk_nic_bind.py -s
	echo
}

docker_cleanup() {

	docker volume rm $(docker volume ls -qf dangling=true)
	#docker network rm $(docker network ls | grep "bridge" | awk '/ / { print $1 }')
	docker rmi $(docker images --filter "dangling=true" -q --no-trunc)
	docker rmi $(docker images | grep "none" | awk '/ / { print $3 }')
	docker rm $(docker ps -qa --no-trunc --filter "status=exited")
	sleep 1
}

docker_detach_dev() {

	local DEV_OBJ="$1"
	
	local JQ_EXPR=$(printf '%s.devname' "$DEV_OBJ")
	local DEV_NAME=$(jq -r "$JQ_EXPR" <<< $JSON_CFG)
	ip netns exec $TREX_BOX_INST ip link set dev $DEV_NAME netns 1
	ip link set dev $DEV_NAME up
}

docker_reset() {

	docker exec $TREX_BOX_INST sv stop trexd
	docker exec $TREX_BOX_INST /opt/trex/start/trex_detach.sh
	
	local JQ_EXPR=$(printf '."trex-boxes"[%u].client' "$TREX_BOX_ID")
	docker_detach_dev "$JQ_EXPR"

	local JQ_EXPR=$(printf '."trex-boxes"[%u].server' "$TREX_BOX_ID")
	docker_detach_dev "$JQ_EXPR"
	
	show_devices $TREX_BOX_INST
	docker kill $TREX_BOX_INST
	docker_cleanup
}

docker_start() {

	docker run \
		--name $TREX_BOX_INST \
		-td \
		--rm \
		--privileged \
		--cap-add=ALL \
		--net=none \
		-v /dev:/dev \
		-v /usr/src:/usr/src:ro \
		-v /lib/modules:/lib/modules \
		-v $ROOTDIR/trex/ko/$(uname -r):$TREX_BOX_WORKDIR/ko/$(uname -r) \
		-v $ROOTDIR/trex/cfg:/etc/trex/cfg \
		$TREX_BOX_IMG
		
	sleep 1
	docker exec $TREX_BOX_INST sv stop trexd
	modprobe uio
	rmmod igb_uio
	docker exec $TREX_BOX_INST /opt/trex/start/trex_config.sh
	insmod $ROOTDIR/trex/ko/$(uname -r)/igb_uio.ko
	docker exec $TREX_BOX_INST sv start trexd
	show_devices $DOCKER_INST
}


docker_reset

if [[ $ACTION == 'stop' ]]
then
	exit
fi

docker build -t $TREX_BOX_IMG ./
docker_cleanup

if [[ $ACTION == 'build' ]]
then
	exit
fi

docker_start

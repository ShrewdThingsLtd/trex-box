#!/bin/bash

ACTION=$1
TREX_BOX_ID=$2

ROOTDIR=$PWD
CFG_DIR=$ROOTDIR/cfg
TREX_BOX_WORKDIR='/opt/trex/v2.56'
TREX_BOX_IMG='trex-box-img'
TREX_BOX_INST="trex-box${TREX_BOX_ID}"
TREX_BOX_CFG_CMD="$CFG_DIR/${TREX_BOX_INST}-cfg.sh"
TREX_CTL_CMD="/opt/trex/ctl/trex_ctl.sh"

docker_cleanup() {

	docker volume rm $(docker volume ls -qf dangling=true)
	#docker network rm $(docker network ls | grep "bridge" | awk '/ / { print $1 }')
	docker rmi $(docker images --filter "dangling=true" -q --no-trunc)
	docker rmi $(docker images | grep "none" | awk '/ / { print $3 }')
	docker rm $(docker ps -qa --no-trunc --filter "status=exited")
	sleep 1
}

docker_run_inst() {

	local CMD=$1
	
	docker run \
		--hostname=$TREX_BOX_INST \
		--name=$TREX_BOX_INST \
		--env TREX_BOX_ID=$TREX_BOX_ID \
		-td \
		--rm \
		--privileged \
		--cap-add=ALL \
		--net=none \
		-v /dev:/dev \
		-v /usr/src:/usr/src:ro \
		-v /lib/modules:/lib/modules \
		-v $ROOTDIR/ko/$(uname -r):$TREX_BOX_WORKDIR/ko/$(uname -r) \
		-v $CFG_DIR:/opt/trex/cfg \
		$TREX_BOX_IMG $CMD
	sleep 1
}

docker_exec_inst() {

	docker exec $TREX_BOX_INST /bin/bash -c "$@"
}

show_status() {

	echo
	echo 'Host devices:'
	echo '-------------'
	ip addr
	docker_exec_inst $TREX_CTL_CMD show_status
	docker_exec_inst sv status trexd
}

docker_stop() {

	docker_exec_inst sv stop trexd
	docker_exec_inst $TREX_CTL_CMD stop
	show_status
}

docker_restart() {

	docker_exec_inst $TREX_CTL_CMD stop
	docker_exec_inst sv start trexd
	show_status
}

docker_kill() {

	docker_exec_inst $TREX_CTL_CMD stop
	$TREX_BOX_CFG_CMD detach_devs
	show_status
	docker kill $TREX_BOX_INST
	docker_cleanup
}

docker_run() {

	docker_run_inst
	docker_exec_inst $TREX_CTL_CMD stop
	local TREX_BOX_INST_PID="$(docker inspect -f '{{.State.Pid}}' $TREX_BOX_INST)"
	mkdir -p /var/run/netns
	ln -sf /proc/$TREX_BOX_INST_PID/ns/net "/var/run/netns/$TREX_BOX_INST"
	$TREX_BOX_CFG_CMD attach_devs
	docker_exec_inst $TREX_CTL_CMD restart
	show_status
}

docker_config() {

	docker build -t $TREX_BOX_IMG ./
	docker_cleanup
	docker_run_inst $TREX_CTL_CMD config
	if [[ "mod_$(lsmod | grep -o '^igb_uio')" == 'mod_igb_uio' ]]
	then
		modprobe uio
		rmmod igb_uio
		insmod $ROOTDIR/ko/$(uname -r)/igb_uio.ko
	fi
	lsmod | grep 'uio'
	echo
	echo "$CFG_DIR/${TREX_BOX_INST}-cfg.yaml"
	cat "$CFG_DIR/${TREX_BOX_INST}-cfg.yaml"
	echo
	echo "$CFG_DIR/cfg.json"
	cat "$CFG_DIR/cfg.json"
	echo
}

exit_usage() {

	echo "USAGE: $0 <config|run|stop|restart|kill> <trex-box-id>"
	echo "EXAMPLE: $0 run 1"
}

ID_REGEX='^([0-9]|[1-9][0-9]*)$'
if ! [[ $TREX_BOX_ID =~ $ID_REGEX ]]
then
	exit_usage
elif [[ $ACTION == 'config' ]]
then
	docker_kill
	docker_config
elif [[ $ACTION == 'run' ]]
then
	docker_run
elif [[ $ACTION == 'stop' ]]
then
	docker_stop
elif [[ $ACTION == 'restart' ]]
then
	docker_restart
elif [[ $ACTION == 'kill' ]]
then
	docker_kill
fi

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

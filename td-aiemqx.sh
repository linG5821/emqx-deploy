#!/bin/bash
#参数
show_usage="[-a] [--action]"
GETOPT_ARGS=$(getopt -o a: -al action: -- "$@")
eval set -- "$GETOPT_ARGS"
opt_action=''
opt_number=1
opt_skip=0
opt_name=td-emqx
ip=172.17.3.108
opt_image_id='7725d81b1866'
while [ -n "$1" ]; do
  case "$1" in
  -a | --action)
    opt_action=$2
    shift 2
    ;;
  --) break ;;
  *)
    echo opt_action,$2,$show_usage
    break
    ;;
  esac
done

if [ -z $opt_action ]; then
  echo $show_usage
  echo "-a is required"
  exit 0
fi

if [ $opt_action == "start" ]; then
  docker ps -a -f name=$opt_name* -q | xargs docker start
elif [ $opt_action == "restart" ]; then
  docker ps -a -f name=$opt_name* -q | xargs docker restart
elif [ $opt_action == "stop" ]; then
  docker ps -a -f name=$opt_name* -q | xargs docker stop
elif [ $opt_action == "deploy" ]; then
  port=1883
  ssl_port=8883
  dash_port=18083
  interal_port=11883

  image_name=$(docker image ls | grep "$opt_image_id" | awk {'print $1'})
  echo "current image $image_name"


  for ((i=$opt_skip; i<$opt_number; i++)); do
    name="$opt_name-$i"
    node="$opt_name@$ip"
    container_id=$(sudo docker run -it --restart=always --name $name -p "$port:1883" -p "$ssl_port:8883" -p "$dash_port:18083" -p "$interal_port:11883" -e EMQX_NAME=$opt_name -e EMQX_LISTENER__TCP__EXTERNAL=1883 -d $opt_image_id)
    echo $node
    docker cp acl.conf "$container_id":/opt/emqx/etc
    cp emqx.conf emqx.temp.conf
    chmod 777 emqx.temp.conf
    echo "node.name = $node" >>emqx.temp.conf
    docker cp emqx.temp.conf "$container_id":/opt/emqx/etc/emqx.conf
    docker cp loaded_plugins "$container_id":/opt/emqx/data/loaded_plugins
    docker cp emqx_dashboard.conf "$container_id":/opt/emqx/etc/plugins/emqx_dashboard.conf
    rm -rf emqx.temp.conf
  done
elif [ $opt_action == "destroy" ]; then
  docker ps -a -f name=$opt_name* -q | xargs docker stop | xargs docker rm
else
  echo "please input sure params"
fi

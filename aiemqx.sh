#!/bin/sh
#参数
show_usage="[-a, -n, -name, -i, -h, -s, -net] [--action, --number, --name, --image, --host, --skip, --network]"
GETOPT_ARGS=$(getopt -o a:n:name:i:h:s:net -al action:,number:,name:,image:,host:,skip:,network: -- "$@")
eval set -- "$GETOPT_ARGS"
opt_action=''
opt_number=1
opt_name=emqx
opt_image_id=''
opt_host="192.168.1"
opt_skip=1
opt_network=emq_net
while [ -n "$1" ]; do
  case "$1" in
  -a | --action)
    opt_action=$2
    shift 2
    ;;
  -n | --number)
    opt_number=$2
    shift 2
    ;;
  -name | --name)
    opt_name=$2
    shift 2
    ;;
  -i | --image)
    opt_image_id=$2
    shift 2
    ;;
  -h | --host)
    opt_host=$2
    shift 2
    ;;
  -s | --skip)
    opt_skip=$2
    shift 2
    ;;
  -net | --network)
    opt_network=$2
    shift 2
    ;;
  --) break ;;
  *)
    echo opt_action,$2,$show_usage
    break
    ;;
  esac
done

if [[ -z $opt_action ]]; then
  echo $show_usage
  echo "-a is required"
  exit 0
fi

if [ $opt_action == "start" ]; then
  if [[ -z $opt_name ]]; then
    echo $show_usage
    echo "--name is required"
    exit 0
  fi
  docker ps -a -f name=$opt_name* -q | xargs docker start
elif [ $opt_action == "restart" ]; then
  if [[ -z $opt_name ]]; then
    echo $show_usage
    echo "--name is required"
    exit 0
  fi
  docker ps -a -f name=$opt_name* -q | xargs docker restart
elif [ $opt_action == "stop" ]; then
  if [[ -z $opt_name ]]; then
    echo $show_usage
    echo "--name is required"
    exit 0
  fi
  docker ps -a -f name=$opt_name* -q | xargs docker stop
elif [ $opt_action == "deploy" ]; then
  port=1883
  ssl_port=8883
  dash_port=18083
  interal_port=11883

  image_name=$(docker image ls | grep "$opt_image_id" | awk {'print $1'})
  echo "current image $image_name"
  image_version=$(docker image ls | grep "$opt_image_id" | awk {'print $2'} | cut -c 1-2)
  echo "current image version $image_version"

  static_seed="cluster.static.seeds = "
  for ((i = 1; i <= 14; i++)); do
    ip="$opt_host.$(expr $i + 1)"
    node="$opt_name@$ip"
    if [ $i == 14 ]; then
      static_seed="$static_seed$node"
    else
      static_seed="$static_seed$node,"
    fi
  done
  echo "static seed $static_seed"

  for ((i = $opt_skip; i <= $opt_number; i++)); do
    name="$opt_name-$i"
    ip="$opt_host.$(expr $i + 1)"
    node="$opt_name@$ip"
    container_id=$(sudo docker run -it --restart=always --ip $ip --network $opt_network --name $name -e EMQX_NAME=$opt_name -e EMQX_LISTENER__TCP__EXTERNAL=1883 -d $opt_image_id)
    echo $node
    docker cp acl.conf "$container_id":/opt/emqx/etc
    if [ $image_version == "v3" ]; then
      cp emqx-v3.conf emqx.temp.conf
    elif [ $image_version == "v4" ]; then
      cp emqx-v4.conf emqx.temp.conf
    else
      echo "emqx $image_version not found"
      exit 0
    fi

    cp loaded_plugins loaded_plugins.temp
    chmod 777 emqx.temp.conf
    echo "node.name = $node" >>emqx.temp.conf
    echo "$static_seed" >>emqx.temp.conf
    if [ $image_name == "emqx/emqx-ee" ]; then
      docker cp emqx.key "$container_id":/opt/emqx/etc
      docker cp emqx.lic "$container_id":/opt/emqx/etc
      echo "{emqx_schema_registry, true}." >> loaded_plugins.temp
      echo "license.file = etc/emqx.lic" >> emqx.temp.conf
    fi
    docker cp emqx.temp.conf "$container_id":/opt/emqx/etc/emqx.conf
    docker cp loaded_plugins.temp "$container_id":/opt/emqx/data/loaded_plugins
    docker cp emqx_dashboard.conf "$container_id":/opt/emqx/etc/plugins/emqx_dashboard.conf
    rm -rf emqx.temp.conf
    rm -rf loaded_plugins.temp
  done
  if [ $opt_skip -le 1 ]; then
    docker pull haproxy:2.1.0
    image_id2=$(docker image ls | grep 'haproxy' | grep "2.1.0" | awk {'print $3'})
    echo "haproxy $image_id2 pull success"
    docker run -it --restart=always --network $opt_network --ip $opt_host.254 -p 1883:1883 -p 11883:11883 -p 18083:18083 -p 18084:8080 --name $opt_name-haproxy -d -v /etc/haproxy:/usr/local/etc/haproxy:ro $image_id2
  fi
elif [ $opt_action == "destroy" ]; then
  if [[ -z $opt_name ]]; then
    echo $show_usage
    echo "--name is required"
    exit 0
  fi
  docker ps -a -f name=$opt_name* -q | xargs docker stop | xargs docker rm
else
  echo "please input sure params"
fi

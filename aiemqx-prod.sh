#!/bin/sh
#参数
echo "./aiemqx.sh -a deploy -n 4 -name aidong-prod -i cf2e9945b366 -h 172.17.0"
show_usage="[-a, -n, -name, -i, -h, -s, -net] [--action, --number, --name, --image, --host, --skip, --network]"
GETOPT_ARGS=$(getopt -o a:n:name:i:h:s:net -al action:,number:,name:,image:,host:,skip:,network: -- "$@")
eval set -- "$GETOPT_ARGS"
opt_action=''
opt_number=1
opt_name=emqx
opt_image_id=''
opt_host="172.17.0"
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

    if [ $i == $opt_skip ]
      then
      container_id=$(docker run -it --restart=always --name $name -p $port:1883 -p $ssl_port:8883 -p $interal_port:11883 -p 4369:4369 -p $dash_port:18083 -p 5369:5369 -p 6000-6100:6000-6100 -p 8083-8084:8083-8084 -p 9090:8080  -e EMQX_NAME=$opt_name -e EMQX_LISTENER__TCP__EXTERNAL=1883  -d $opt_image_id)
    else
      temp_port=$(expr $port + $i - 1)
      temp_ssl=$(expr $ssl_port + $i - 1)
      temp_inter=$(expr $interal_port + $i - 1)
      container_id=$(docker run -it --restart=always --name $name -p $temp_port:1883 -p $temp_ssl:8883 -p $temp_inter:11883 -e EMQX_NAME=$opt_name -e EMQX_LISTENER__TCP__EXTERNAL=1883 -d $opt_image_id)
    fi

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
elif [ $opt_action == "destroy" ]; then
  docker ps -a -f name=$opt_name* -q | xargs docker stop | xargs docker rm
else
  echo "please input sure params"
fi

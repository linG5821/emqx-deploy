## 使用说明
1. 启动
   ```
    aiemqx.sh -a start -name ${name} //用于启动已经被停止的节点
   ```
2. 停止
   ```
    aiemqx.sh -a stop -name ${name} //用于停止运行中的节点
   ```
3. 重启
   ```
    aiemqx.sh -a restart -name ${name} //用于重启运行中的节点
   ```
4. 部署
   ```
   # 创建 overlay 网络
   docker network create --attachable -d overlay emq_net --subnet=10.10.3.0/24
   aiemqx.sh -a deploy -name emq-test -n 2 -i 455e00e3eeac -h 10.10.3 -net emq_net
   # -a/--action 动作 例如 deploy
   # -n/--number 数量
   # -name/--name 名字
   # -i/--image 镜像名称或者id
   # -h/--host 创建的overlay网络ip 前三位10.10.3
   # -s/--skip 调过节点数执行调过操作后不会再执行负载均衡的部署 主要用于多宿主机部署 
   ```
5. 销毁
   ./aiemqx.sh -a destroy --name {name} //用于销毁节点
6. prod版本用于正式环境EMQ部署
7. MQTT Service 重启 supervisorctl restart mqtt-service:
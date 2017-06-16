###############
# This bash is to run a new php-dev docker container and inject a nginx `proxy_pass` configuration in host's nginx if exists
# prepared yourself:
# 1. docker network create --gateway 172.50.0.1 --subnet 172.50.0.0/16 php_dev
###############
#!/bin/bash

#set -eo pipefail

#check nginx
NGINX_SITE_ENABLE_DIR='/etc/nginx/sites-enabled'

if [ ! -d "$NGINX_SITE_ENABLE_DIR" ]; then  
    echo >&2 "Error: $NGINX_SITE_ENABLE_DIR does not exsit, please check if the host has nginx installed or you can change the dir in this source code"
    exit 1
fi  

service nginx status
if [ $? -ne 0 ]; then
    echo >&2 'Error: service nginx status execute error, please check if the host has nginx installed' 
    exit 1
fi

#input parameters
read -p "input domain:" DOMAIN

if [ -z "$DOMAIN" ]; then
    echo >&2 'Error: please input a domain'
    exit 1
fi

read -p "input php version (support 5.3 or 5.5):" VERSION

if [ -z "$VERSION" ]; then
  echo >&2 'Error: please input php version'
  exit 1
fi

#hardcode a network name
NETWORK='php_dev'

get_random_ip_int(){
    local ip_int=`expr $RANDOM % 254`
    while [ $ip_int -eq 0 ]; do
        ip_int=`expr $RANDOM % 254`
    done
    echo $ip_int
}

get_random_ip(){
    local arr=(${1//./ })
    local ip=${1}
    for s in ${arr[@]}; do
        if [ $s = 'x' ]; then
            ip=${ip/x/$(get_random_ip_int)}
        fi
    done
    echo $ip
}

get_gateway_segment(){
    local arr=(${1//./ })
    echo ${arr[0]}.${arr[1]}
}

is_network_exist=`docker network ls |grep ${NETWORK}`
if [ -z "$is_network_exist" ]; then
    for i in {50..0}; do
        gateway=$(get_random_ip 172.x.0.1)
        subnet=$(get_random_ip 172.x.0.0)
        # todo check if gateway exsit
        docker network create --gateway ${gateway} --subnet ${subnet}/16 php_dev
    done
else
    gateway=`docker network inspect ${NETWORK} |grep -e Gateway |awk -F '\"' '{print $4}'`
fi

is_ip_exist=1
while [ -n "$is_ip_exist" ]; do
    ip=$(get_random_ip $(get_gateway_segment $gateway).x.x)
    is_ip_exist=`docker network inspect ${NETWORK} |grep ${ip}`
done

#docker run
mysql_dir=/var/mysql/${DOMAIN}
if [ -d "$mysql_dir" ]; then
    cp -R ${mysql_dir} ${mysql_dir}_backup`date +%Y%m%d%H%I%M`
fi
www_dir=/var/www/${DOMAIN}
if [ ! -d "$www_dir" ]; then
    mkdir -p ${www_dir}
fi
mkdir -p ${mysql_dir} && \
rm -rf ${mysql_dir}/* && \
docker run --restart=always --name ${DOMAIN} -tid \
        -v ${mysql_dir}:/var/lib/mysql \
        -v ${www_dir}:/var/www/${DOMAIN} \
        --network ${NETWORK} \
        --ip ${ip} \
        -e DOMAIN="${DOMAIN}" \
        -e IP="${ip}" \
        cfansimon/docker-php-dev:${VERSION}

#inject nginx config
host='$host'
remote_addr='$remote_addr'

cat > ${NGINX_SITE_ENABLE_DIR}/${DOMAIN} <<-EOF 
server {
     listen 80;
     server_name ${DOMAIN};
     access_log off;
     location /
     {
          proxy_set_header Host $host;
          proxy_set_header X-Real-Ip $remote_addr;
          proxy_set_header X-Forwarded-For $remote_addr;
          proxy_buffer_size  128k;
          proxy_buffers   32 32k;
          proxy_busy_buffers_size 128k;
          proxy_pass http://${ip}:80/;
     }
}
EOF

#add /etc/hosts map
echo "${ip} ${DOMAIN}.local" >> /etc/hosts

echo '****************** login info***********************'
echo "1. mysql login: mysql -h ${DOMAIN}.local -uroot -proot"
echo "2. docker exec -ti ${DOMAIN} bash"
echo '****************** storage info***********************'
echo "1. mysql_data: ${mysql_dir}"
echo "2. www_data: ${www_dir}"

echo 'nginx reloading'
echo '*tip: if reloading failed, please execute "nginx -s reload" yourself'
nginx -s reload

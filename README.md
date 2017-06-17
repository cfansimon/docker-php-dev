# 一键生成php开发测试环境

## 基本说明

* 最佳实践是每个容器只跑一个项目.
* debian/ubuntu上已经测试.

## 重要提示

容器正常运行后最好不要进入容器内部去操作，比如查询mysql数据、npm编译等.

## 使用方法

### 先看几行Dockerfile中的注释

```
# 想要用php53开启这行
# FROM ubuntu:12.04.5

# 想要用php55开启这行
# FROM ubuntu:14.04.5
```

### 前期准备：在物理机上安装docker
```
Ubuntu: https://docs.docker.com/engine/installation/linux/ubuntu/#install-docker
Mac: https://docs.docker.com/docker-for-mac/install/
```

### 前期准备：在物理机上安装nginx
```
Ubuntu: apt-get install nginx
Mac: brew install nginx
```

>在物理机上安装nginx是为了多个docker容器能共享物理机80端口

### 初次使用请先编译镜像

```bash
#若由于网络不给力，请自行配合docker加速器
docker build -t cfansimon/docker-php-dev:7.1 .
```

### ubuntu用户，至此可以借助脚本直接运行新容器了

```bash
mv docker-create-php-dev.sh /usr/bin/
chmod +x /usr/bin/docker-create-php-dev.sh
docker-create-php-dev.sh

输入域名
输入php版本
```
>以后每次需要新建一个开发测试站，只要运行docker-create-php-dev.sh
即可

### 容器内管理php/mysql/php-fpm

```bash
supervisorctl restart nginx
supervisorctl restart mysql
supervisorctl restart php5-fpm
#mysql root密码默认为空
mysql
```

### 从物理机连接到docker的mysql

```bash
mysql -h 域名.local -uroot -proot
#注意：这是用docker-create-php-dev.sh脚本生成的docker才能用此方式进mysql
```

## 手动配置说明

### 先创建一个网络，以便固定住容器的ip

```bash
docker network create --gateway 172.20.0.1 --subnet 172.20.0.0/16 php_dev
docker network inspect php_dev
```

参数说明

* `--gateway 172.20.0.1`: 为新网络指定一个网关地址
* `--subnet 172.20.0.0/16`: 设置子网掩码
* `php_dev`: 新网络的名称

> ***注意: 网络一般常见一次就够了，多个容器都挂到这个网络下即可***

### 运行新容器

```bash
mkdir -p /var/www/your_domain && \
mkdir -p /var/mysql/your_domain && \
rm -rf /var/mysql/your_domain/* && \
docker run --restart=always --name your_domain -tid \
        -v /var/mysql/your_domain:/var/lib/mysql \
        -v /var/www/your_domain:/var/www/your_domain \
        --network php_dev \
        --ip 172.20.0.2 \
        -e DOMAIN="your_domain" \
        -e MYSQL_DATABASE="your_domain" \
        -e IP="172.20.0.2" \
        cfansimon/docker-php-dev:5.3
```

参数说明

* `-v /var/mysql/your_domain:/var/lib/mysql`: 把一个本机目录映射到容器中的mysql数据目录，以便保证数据库数据不会丢失
* `-v /var/www/your_domain:/var/www/your_domain`: 映射代码目录，以便在本机用sublime做开发，文件是软连接形式映射
* `--name your_domain`: 指定域名为容器的名字，便于管理
* `--network php_dev`: 指定在前一步你创建好的网络名称
* `--ip 172.20.0.2`: 为新容器分配一个固定IP，以便在本机做80端口转发
* `-e DOMAIN="your_domain"`: 指定域名
* `-e IP="172.20.0.2"`: 再次指定一下新容器的IP

### 在物理机的nginx里添加一个vhost

```
server {
     listen 80;
     server_name your_domain;
     access_log off;
     location /
     {
          proxy_set_header Host $host;
          proxy_set_header X-Real-Ip $remote_addr;
          proxy_set_header X-Forwarded-For $remote_addr;
          proxy_buffer_size 128k;
          proxy_buffers 32 32k;
          proxy_busy_buffers_size 128k;
          proxy_pass http://172.20.0.2:80/;
     }
}
```

>坑：Windows和Mac下，无法用物理机ping通172.20.0.2，解决办法：
>在docker run的时候添加一个 -p 18080:80，然后nginx的proxy_pass改成http://127.0.0.1:18080/

## 测试

```
访问 http://your_domain 一切正常的话会显示"File not found"，接下来只要在物理机的/var/www/your_domain目录部署代码即可
```
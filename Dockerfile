FROM ubuntu:16.04

MAINTAINER Simon Wood <i@wuqian.me>

ENV TIMEZONE            Asia/Shanghai
ENV PHP_MEMORY_LIMIT    1024M
ENV PHP_MAX_UPLOAD      1024M
ENV PHP_MAX_POST        1024M

#COPY ubuntu/16.04-sources.list /etc/apt/sources.list
RUN apt-get update \
    && apt-get install -y language-pack-en-base \
    && export LC_ALL=en_US.UTF-8 \
    && export LANG=en_US.UTF-8 \
    && apt-get install -y software-properties-common && DEBIAN_FRONTEND=noninteractive add-apt-repository ppa:ondrej/php \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata \
    && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && echo "${TIMEZONE}" > /etc/timezone \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y nginx \
    && lineNum=`sed -n -e '/sendfile/=' /etc/nginx/nginx.conf`; sed -i $((lineNum+1))'i client_max_body_size 1024M;' /etc/nginx/nginx.conf \
    && sed -i '1i daemon off;' /etc/nginx/nginx.conf \
    && sed -i "s/;*worker_processes\s*\w*/worker_processes 4/g" /etc/nginx/nginx.conf \
    && apt-get install -y php7.1 php7.1-cli php7.1-curl php7.1-fpm php7.1-intl php7.1-mcrypt php7.1-mysqlnd php7.1-gd php7.1-dom \
    && sed -i "s/;*post_max_size\s*=\s*\w*/post_max_size = ${PHP_MAX_POST}/g" /etc/php/7.1/fpm/php.ini \
    && sed -i "s/;*memory_limit\s*=\s*\w*/memory_limit = ${PHP_MEMORY_LIMIT}/g" /etc/php/7.1/fpm/php.ini \
    && sed -i "s/;*upload_max_filesize\s*=\s*\w*/upload_max_filesize = ${PHP_MAX_UPLOAD}/g" /etc/php/7.1/fpm/php.ini \
    && sed -i "s/;*display_errors\s*=\s*\w*/display_errors = On/g" /etc/php/7.1/fpm/php.ini \
    && sed -i "s/;*listen.owner\s*=\s*www-data/listen.owner = www-data/g" /etc/php/7.1/fpm/pool.d/www.conf \
    && sed -i "s/;*listen.group\s*=\s*www-data/listen.group = www-data/g" /etc/php/7.1/fpm/pool.d/www.conf \
    && sed -i "s/;*listen.mode\s*=\s*0660/listen.mode = 0660/g" /etc/php/7.1/fpm/pool.d/www.conf \
    && sed -i "s/;*listen\s*=\s*\S*/listen = 127.0.0.1:9000/g" /etc/php/7.1/fpm/pool.d/www.conf \
    && sed -i "s/;*daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.1/fpm/php-fpm.conf \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server \
    && sed -i "s/;*max_allowed_packet\s*=\s*\w*/max_allowed_packet = 1024M/g" /etc/mysql/my.cnf \
    && apt-get install -y supervisor \
    && apt-get install -y vim \
    && apt-get remove -y software-properties-common \
    && apt-get -y autoremove \
    && apt-get -y clean \
    && apt-get -y autoclean

COPY nginx/domain.conf /etc/nginx/sites-enabled
COPY supervisor/php_dev.conf /etc/supervisor/conf.d
COPY entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh

EXPOSE 80
CMD ["entrypoint.sh"]
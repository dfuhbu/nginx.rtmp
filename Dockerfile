FROM debian:buster-slim

ENV TZ=UTC
ARG NGINX_VERSION=1.21.0
ARG OPENSSL_VERSION=1.1.1k
ARG PRCE_VERSION=8.45
ARG RTMP_VERSION=v1.2.2

COPY files/*.sh /

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && chmod a+x /*.sh \
    #
    && DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && DEV_APP="wget apt-transport-https lsb-release ca-certificates zlib1g-dev cmake build-essential vim libboost-all-dev git zip" \
    && apt-get --no-install-recommends -qq -y install curl vim zlib1g $DEV_APP \
    && mkdir /soft/ \
    # PRCE
    && cd /soft/ \
    && wget ftp://ftp.pcre.org/pub/pcre/pcre-$PRCE_VERSION.tar.gz \
    && tar -zxf pcre-$PRCE_VERSION.tar.gz \
    && cd pcre-$PRCE_VERSION \
    && ./configure \
    && make -j64  \
    && make install -j64  \
    # OpenSSL
    && cd /soft/ \
    && wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz \
    && tar -zxf openssl-${OPENSSL_VERSION}.tar.gz \
    && cd openssl-${OPENSSL_VERSION} \
    && ./config --prefix=/usr \
    && make -j64 \
    && make install -j64 \
    # Nginx rtmp
    && cd /soft/ \
    && git clone --depth 1 --branch $RTMP_VERSION https://github.com/arut/nginx-rtmp-module.git \
    # Nginx
    && cd /soft/ \
    && useradd --no-create-home nginx \
    && wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
    && tar -zxf nginx-${NGINX_VERSION}.tar.gz \
    && cd nginx-${NGINX_VERSION} \
    && ./configure \
			--with-cc-opt="-O3" \
            --sbin-path=/usr/sbin/nginx \
            --conf-path=/etc/nginx/nginx.conf \
            --pid-path=/var/run/nginx.pid \
            --error-log-path=/dev/stdout \
            --http-log-path=/dev/stdout  \
            --with-http_ssl_module \
            --with-openssl=/soft/openssl-${OPENSSL_VERSION}/ \
			--with-http_secure_link_module \
            --with-http_addition_module \
            --with-http_realip_module \
            --with-http_v2_module \
            --with-threads \
            --with-http_slice_module \
            --with-file-aio \
            --with-stream \
            --with-stream_ssl_module \
            --add-module=../nginx-rtmp-module \
            --with-http_dav_module \
    && make -j64 \
    && make install -j64 \
    && export LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH} \
    #
    && groupmod -g 1008 nginx \
    && usermod -u 1008 nginx \
    #
    && apt-get -y remove $DEV_APP \
    && apt-get -y autoremove \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /soft/

COPY files/nginx.conf /etc/nginx/nginx.conf

CMD ["nginx", "-g", "daemon off;"]

HEALTHCHECK --interval=2m --timeout=3s CMD curl -f http://localhost:86/ping || exit 1

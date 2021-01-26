ARG EMQX_VERSION
FROM emqx/emqx:${EMQX_VERSION}

RUN sudo sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/' /etc/apk/repositories && \
    sudo apk update  && \
    sudo apk add openjdk8
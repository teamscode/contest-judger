FROM mirror.gcr.io/library/debian:11 AS judger-build-env

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y software-properties-common git libtool cmake libseccomp-dev curl

RUN cd /tmp && git clone -b main --depth 1 https://github.com/teamscode/contest-sandbox.git && cd        contest-sandbox && \
    mkdir build && cd build && cmake .. && make

FROM mirror.gcr.io/library/debian:11

COPY build/java_policy /etc

ENV DEBIAN_FRONTEND=noninteractive

COPY --from=judger-build-env /tmp/contest-sandbox /tmp/contest-sandbox

RUN apt update && apt install -y python2 python3 cmake python-pkg-resources python3-pip python3-pkg-resources openjdk-11-jdk g++ python3-setuptools && \
    pip3 install -I --no-cache-dir psutil gunicorn flask requests idna && \
    cd /tmp/contest-sandbox/build && \
    make install && pip3 install ../bindings/Python && \
    apt purge -y --auto-remove python3-pip cmake && apt clean && rm -rf /var/lib/apt/lists/*
    
RUN mkdir -p /code && \
    useradd -u 12001 compiler && useradd -u 12002 code && useradd -u 12003 spj && usermod -a -G code spj

HEALTHCHECK --interval=5s --retries=3 CMD python3 /code/service.py

ADD server /code
WORKDIR /code
RUN gcc -shared -fPIC -o unbuffer.so unbuffer.c

EXPOSE 8080
ENTRYPOINT /code/entrypoint.sh

#!/bin/bash
set -euxo pipefail
cd "$(dirname "$0")"

COMMAND=$1
TIME=$(date "+%H:%M:%S")
SLACKCAT="slackcat --channel isucon12"

# change here
PRJ_ROOT=${HOME}/webapp/go
APP_NAME=isupipe
SERVICE_NAME=isu-go.service
CONFDIR=${PRJ_ROOT}/config
BUILDDIR=${PRJ_ROOT}
NGX_CONF=/etc/nginx/nginx.conf
MYSQLD_CNF=/etc/mysql/mysql.conf.d/mysqld.cnf

NGX_LOG=/var/log/nginx/access.log
MYSQL_LOG=/var/log/mysql/mysql-slow.log

# setup runs only once
if [ ${COMMAND} = "setup" ]; then
    cd ${PRJ_ROOT}
    mkdir config
    sudo apt install -y percona-toolkit git tiptop
    git config --global user.email "28010438+takaku2166@users.noreply.github.com"
    git config --global user.name "takak2166"
    git init
    git add . && git commit -m "initital commit"
    wget https://github.com/tkuchiki/alp/releases/download/v1.0.10/alp_linux_amd64.tar.gz
    tar -xzvf alp_linux_amd64.tar.gz
    sudo install alp /usr/local/bin/alp
    rm alp*
    curl -Lo slackcat https://github.com/bcicen/slackcat/releases/download/1.7.2/slackcat-1.7.2-$(uname -s)-amd64
    sudo mv slackcat /usr/local/bin/
    sudo chmod +x /usr/local/bin/slackcat
    sudo cp ${NGX_CONF} ${NGX_CONF}.initial
    sudo mv ${NGX_CONF} ${CONFDIR}
    sudo ln -s ${CONFDIR}/nginx.conf ${NGX_CONF}
    sudo cp ${MYSQLD_CNF} ${MYSQLD_CNF}.initital
    sudo mv ${MYSQLD_CNF} ${CONFDIR}
    sudo ln ${CONFDIR}/mysqld.cnf ${MYSQLD_CNF}
fi

if [ ${COMMAND} = "prebench" ]; then
    cd ${PRJ_ROOT}
    git add . && git commit --allow-empty -m "bench at ${TIME}"
    mkdir -p ./logs/${TIME}
    if [ -f ${NGX_LOG} ]; then
        sudo mv ${NGX_LOG} ./logs/${TIME}/
    fi
    if [ -f ${MYSQL_LOG} ]; then
        sudo mv ${MYSQL_LOG} ./logs/${TIME}/
    fi
    cd ${BUILDDIR}
    go build -o ${APP_NAME}
    sudo systemctl restart ${SERVICE_NAME}
fi

function alp_to_slack() {
    sudo cat ${NGX_LOG} | alp ltsv --sort avg -r | ${SLACKCAT} --filename alp_${TIME}
}

function query_to_slack() {
    sudo pt-query-digest ${MYSQL_LOG} | ${SLACKCAT} --filename query_${TIME}
}

if [ ${COMMAND} = "postbench" ]; then
    alp_to_slack
    query_to_slack
fi

if [ ${COMMAND} = "alp" ]; then
    alp_to_slack
fi

if [ ${COMMAND} = "query" ]; then
    query_to_slack
fi

# if [ COMMAND = "bench" ]; then
#     prebench
#     # TODO: write benchmark function
#     postbench
# fi

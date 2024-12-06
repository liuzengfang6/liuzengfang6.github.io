#!/bin/bash

# discription:
#       A docker tool. intall docker and docker-compose, config proxy, mirror, balabala
# author: lzf
# feature: 
#       1. docker and docker-compose auto install(support centos,ubuntu,debian,kali)
#       2. proxy registry-mirrors insecure-registries auto config, via jq

help(){
    echo "$0 install/i | proxy/p url | mirror/m url | mirror-addtrust/mt url | add-trust/at url | rm-stoped/rs | compose"
    echo -e "\t install \t\t install docker"
    echo -e "\t proxy url \t\t add proxy"
    echo -e "\t mirror url \t\t add registry-mirrors"
    echo -e "\t add-trust url \t\t add insecure-registries"
    echo -e "\t mirror-addtrust url \t add registry-mirrors and insecure-registries"
    echo -e "\t compose \t\t install docker-compose"
    exit 0
}

init(){
    source /etc/os-release
    if command -v jq >/dev/null 2>&1 ;then
        jq_exist=1
    fi
    case $ID in
        centos | ubuntu | debian | kali | arch)
            ;;
        #arch)
        #    echo "正在编写代码，暂不支持$ID"
        #    #exit 1
        #    ;;
        *)
            echo "Error: $ID is not supported."
            exit 1
    esac
    # 整个配置文件
    CONFIG_PATH=.docker_tools.conf
    if [ -f $CONFIG_PATH ]; then
        source $CONFIG_PATH
    fi
}

# 检测依赖软件包
check_depen(){
    local depen=("jq")
    for c in ${depen[@]}; do
        has_cmd $c || {
            echo "Error: $c is not installed."
            exit 1
        }
    done
}

has_cmd () {
    command -v $1 >/dev/null 2>&1 
}

install(){
    case $ID in
        ubuntu | debian | kali)
            # 添加公钥
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg
            # 参加仓库
            if "$(. /etc/os-release && echo "$VERSION_CODENAME")" = 'kali-rolling' ; then
                echo \
                  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian \
                  buster stable" | \
                  tee /etc/apt/sources.list.d/docker.list > /dev/null
            else
                echo \
                  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian \
                  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
                  tee /etc/apt/sources.list.d/docker.list > /dev/null
            fi
            # 安装
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        centos)
            yum install -y yum-utils device-mapper-persistent-data lvm2
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            # 这里我们换成清华的源
            sed -i 's+https://download.docker.com+https://mirrors.tuna.tsinghua.edu.cn/docker-ce+' /etc/yum.repos.d/docker-ce.repo
            yum makecache
            yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        arch)
            # pacman -S docker
            ;;
    esac
}

install_docker_compose(){
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
}

docker_config_init(){
    #config_file="/etc/docker/daemon.json"
    config_file="./daemon.json"
    [ -f "$config_file" ] || echo "{}" > "$config_file"
}

modify_config(){
    jq "$1" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
}

proxy(){
    modify_config ".proxies.\"http-proxy\" = \"$1\"" \
        && echo "http代理配置成功:$1" \
        || echo "ttp代理配置失败"
    modify_config ".proxies.\"https-proxy\" = \"$1\"" \
        && echo "https代理配置成功:$1" \
        || echo "https代理配置失败"
    # todo 校验
    restart_docker
}

mirror(){
    modify_config  ".[\"registry-mirrors\"] |= if index(\"$1\") == null then . + [\"$1\"] else . end" \
        && echo "mirror配置成功:$1" \
        || echo "mirror配置失败"
    # todo 校验
    restart_docker
}

mirror_trust(){
    if [[ $1 =~ http://* ]]; then
        trust=${1:7:${#1}}
        echo $trust
        modify_config "if .\"insecure-registries\" | index(\"$trust\") | not then .\"insecure-registries\" += [\"$trust\"] else . end" \
            && echo "mirror_trust配置成功:$trust" \
            || echo "mirror_trust配置失败"
        # todo 校验
        restart_docker
    else
        echo "mirror is not http, not change mirror_trust"
    fi
}

enable_doceker(){
    systemctl enable --now docker
}



restart_docker(){
    systemctl daemon-reload
    systemctl restart docker
}

rm_stoped(){
    docker ps -a -f "status=exited" -q | xargs docker rm
}

main(){
    init
    docker_config_init
    if [ $# -eq 0 ]; then
        install
        install_docker_compose
        enable_doceker
    else
        case $1 in 
            install | i)
                install
                ;;
            proxy | p)
                # todo 校验输入的参数
                [ -z "$2" ] && [ -z "$config_proxy" ] && exit 1
                proxy ${2:-$config_proxy}
                ;;
            mirror | m)
                [ -z "$2" ] && [ -z "$config_mirror" ] && exit 1
                mirror ${2:-$config_mirror}
                ;;
            mirror-addtrust | mt)
                [ -z "$2" ] && [ -z "$config_mirror_trust" ] && exit 1
                mirror_trust ${2:-$config_mirror_trust}
                [ -z "$2" ] && [ -z "$config_mirror" ] && exit 1
                mirror ${2:-$config_mirror}
                ;;
            add-trust | at)
                [ -z "$2" ] && [ -z "$config_mirror_trust" ] && exit 1
                 mirror_trust ${2:-$config_mirror_trust}
                ;;
            rm-stoped | rs)
                rm_stoped
                ;;
            compose)
                install_docker_compose
                ;;
            *)
                help 
                ;;
        esac
    fi
}

main $@

#!/bin/bash

# author: lzf
# feature:
#     1. suport ubuntu,debinen,centos,kali
#     2. backup and restore
# todo: 
#     1. yum源更新，仅支持了centos7
#     1. apt源更新，遗漏了部分源

# 帮助
help(){
    echo "$0 update | backup | restore [file_real_path] | list-backup"
}

# 初始化
init(){
    check_depen
    get_os_info
    case $ID in
        ubuntu)
            ;;
        debian)
            ;;
        centos)
            if [ $VERSION_ID != '7' ]; then
                echo "Error, Only support centos7."
                exit 1
            fi
            ;;
        kali)
            ;;
        arch)
            ;;
        *)
            echo "Error: $ID is not supported."
            exit 1
            ;;
    esac
}


# 获取系统源路径(用于获取备份文件)
get_os_source_path(){
    file_list=()
    case $ID in
        arch)
            file_list+=("/etc/pacman.d/mirrorlist")
            ;;
        centos)
            for f in /etc/yum.repos.d/*.repo; do
                file_list+=("$f")
            done
            ;;
        *)
            file_list+=("/etc/apt/sources.list")
            for f in /etc/apt/sources.list.d/*; do 
                if [[ "$f" != *back ]]; then
                    file_list+=("$f")
                fi
            done
            ;;
    esac
    if [ -z $1 ]; then
        echo ${file_list[@]}
    elif [ $1 = "backup" ]; then
        new_list=()
        for f in ${file_list[@]};do
            # 如果文件存在则放入新的数组
            if [ -f $f ]; then
                new_list+=("$f.back")
            fi
        done
        echo ${new_list[@]}
    fi
}

# 检测依赖软件包
check_depen(){
    local depen=("ls" "declare")
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

# 获取当前系统信息
get_os_info(){
    if [ -f /etc/os-release ]; then
        source /etc/os-release
    else
        echo "Error: /etc/os-release not found."
        exit 1
    fi
}

# 备份镜像源(单个文件)
backup_source(){
    if [ -f $1 ]; then
        cp $1 $1.back \
            && echo "$1 Backup success.Backup file is $1.back" \
            || echo "$1 Backup failed."
    fi
}


# 恢复备份源(单个文件)
restore_source(){
    backup_file_path=$1
    if [ -f $backup_file_path ]; then
        file_postfix=${backup_file_path:(${#backup_file_path}-4):${#backup_file_path}}
        origin_file_path=${backup_file_path:0:(${#backup_file_path}-5)}
        echo $file_postfix
        echo $origin_file_path
        if [ ${backup_file_path:(${#backup_file_path}-4):${#backup_file_path}} = 'back' ]; then
            if [ -f $origin_file_path ]; then
                rm $origin_file_path
            fi
            cp $backup_file_path $origin_file_path \
                && echo "$backup_file_path Restore success.Restore file is $origin_file_path" \
                || echo "$backup_file_path Restore failed."
        fi
    fi
}

# 列出所有备份文件
list_backup_source(){
    files=`get_os_source_path back`
    if [ -z $files ];then
        return 0
    else
        for file in $files; do
            echo backup_file: `realpath $file`
        done
    fi
}

# 备份源
backup(){
    case $ID in
        centos)
            p=`get_os_source_path backup`
            echo $p
            for f in ls $p ; do
                backup_source $f
            done
            ;;
        arch)
            echo "正在编写代码，暂时不支持$ID"
            exit 1
            ;;
        *)
            echo `get_os_source_path`
            for f in `get_os_source_path`; do
                backup_source $f
            done
            ;;
    esac
}


# 对源文件进行sed操作
sed_list(){
    for f in `get_os_source_path`; do
        echo "正在为${f}进行sed操作..."
        sed -i "$1" $f
    done
}

# apt更新
update_apt(){
    apt update \
        && echo "Update success." \
        || echo "Update failed."
}

# 换源
change_source(){
    case $ID in
        ubuntu)
            sed_list "s@//.*archive.ubuntu.com@//mirrors.aliyun.com@g"
            update_apt
            ;;
        debian)
            sed_list "s@http://\(deb.debian.org\|archive.debian.org\)@https://mirrors.aliyun.com@g"
            update_apt
            ;;
        centos)
            if [ $VERSION_ID -eq '7' ] ;then
                # todo
                curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
                curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
                sed -i 's/http:\/\/mirrors.cloud.aliyuncs.com/url_tmp/g'  /etc/yum.repos.d/CentOS-Base.repo &&  sed -i 's/http:\/\/mirrors.aliyun.com/http:\/\/mirrors.cloud.aliyuncs.com/g' /etc/yum.repos.d/CentOS-Base.repo && sed -i 's/url_tmp/http:\/\/mirrors.aliyun.com/g' /etc/yum.repos.d/CentOS-Base.repo
                yum clean all && yum makecache \
                    && echo "Update success." \
                    || echo "Update failed."
            fi
            ;;
        kali)
            sed_list "s@http://http.kali.org@https://mirrors.aliyun.com@g"
            update_apt
            ;;
        arch)
            echo "正在编写代码，暂时不支持$ID"
            exit 1
            ;;
    esac
}


main(){
    init
    #ID="centos"
    if [ $# -eq 0 ]; then
        backup
        change_source
    else
        case $1 in
            "update") 
                backup
                change_source
                ;;
            "backup") 
                backup 
                ;;
            "restore")
                if [ -f $2 ]; then
                    restore_source $2
                else
                    echo "Error: $2 not found."
                fi
                ;;
            "list-backup")
                list_backup_source
                ;;
            *)
                help
                ;;
        esac
    fi
}



main $@

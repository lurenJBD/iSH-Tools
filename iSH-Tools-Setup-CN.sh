#!/bin/sh
# Moded by lurenJBD 2023.05.19
# iSH-Tools by lurenJBD 2020.10.17

########### Variable ###########
github_url="https://github.com"
inite_repo="wget ncurses openrc bash"
HOST="baidu.com"
NAMESERVER="223.5.5.5"
# 终端颜色
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
PLAIN='\033[0m'
echo_INFO="echo -e "${CYAN}INFO${PLAIN}""
echo_WARNING="echo -e "${YELLOW}WARNING${PLAIN}""
echo_ERROR="echo -e "${RED}ERROR${PLAIN}""
########### Function ###########
check_connection() {
    ping_host() {
        ping -4 -c 1 -w 1 -A $HOST &>/dev/null
    }
    $echo_INFO 正在检查网络状况...
    if ! ping_host; then
        $echo_WARNING 网络连接异常，尝试更改DNS重新测试
        cp /etc/resolv.conf /etc/resolv.conf.bak
        echo "nameserver ${NAMESERVER}" > /etc/resolv.conf
        if ! ping_host; then
            mv /etc/resolv.conf.bak /etc/resolv.conf
            No_Network=1
        fi
    fi
} # 检查网络状况
check_location() {
    location=$(wget -qO- https://cf-ns.com/cdn-cgi/trace | awk -F'=' '/^loc=/{print $2}')
    if [[ "$location" == "CN" ]]; then
        $echo_INFO "根据当前网络环境，自动更换 APK 镜像源并使用 GitHub 镜像站"
        github_url="https://ghproxy.com/https://github.com"
        rm -rf /etc/apk/repositories /ish
        echo "http://mirrors.aliyun.com/alpine/$alpine_version/main" >>/etc/apk/repositories
        echo "http://mirrors.aliyun.com/alpine/$alpine_version/community" >>/etc/apk/repositories
    fi
} # 检查所属地区，决定是否使用镜像站
run_main() {
    # 获取运行环境信息
    if grep -q "SUPER AWESOME" /proc/version; then
        ish_ver="$(cat /proc/ish/version | awk '{print $2}')"
    else
        ish_ver="$(sed 's/.* iSH \([0-9]\.[0-9]\.[0-9]\) (\([0-9]\{1,\}\)) \(.*\)/\1 (\2)/' /proc/version)"
    fi
    if ! [[ "$ish_ver" =~ ^[0-9]+\.[0-9]+\.[0-9] ]]; then
        $echo_ERROR 未知的iSH版本，脚本尚未支持 && exit 1
    fi
    alpine_version=$(awk -F. '{if ($1 == 3) print "v3."$2}' /etc/alpine-release)
    check_connection
    # 第一次初始化脚本
    if [ -e /opt/iSH-VNC/VNC_installed ]; then
        sed -i 's/^installed_DE=\(.*\)/installed_DE="\1"/' /opt/iSH-VNC/VNC_installed
        source /opt/iSH-VNC/VNC_installed && echo installed_apk_repo=\"$installed_DE\" > /etc/iSH-Tools/VNC_installed
        source /opt/iSH-VNC/VNC_installed_name && echo installed_apk_name=$installed_DE_name >> /etc/iSH-Tools/VNC_installed
        rm -rf /opt/iSH-VNC
    fi
    if [ "$No_Network" = 1 ]; then
        $echo_ERROR 获取新版本信息失败 && lastest_version=$inited_version
    else
        lastest_version=$(wget -qO- ${github_url}/lurenJBD/iSH-Tools/raw/main/lastest_version | awk -F'=' '/^lastest_version=/{print $2}')
    fi
    if [ ! -e /etc/iSH-Tools/tools_inited ];then
        mkdir -p /etc/iSH-Tools
        $echo_INFO 正在安装需要的软件包...
        [ "$No_Network" = 1 ] && $echo_ERROR 无网络连接，无法安装，脚本自动退出 && exit 1
        check_location
        timeout 30s apk add -q ${inite_repo}
        have_been_timeout=$?
        if [ "$have_been_timeout" = 143 ]; then
            $echo_WARNING 超过30s未完成安装，可能是源下载太慢，进行镜像源替换
            rm -rf /etc/apk/repositories /ish
            echo "http://mirrors.aliyun.com/alpine/$alpine_version/main" >>/etc/apk/repositories
            echo "http://mirrors.aliyun.com/alpine/$alpine_version/community" >>/etc/apk/repositories
            $echo_INFO 再次尝试安装所需的软件包...
            apk update &>/dev/null
            apk add -q ${inite_repo}
            have_been_timeout=$?
        fi
        if [ "$have_been_timeout" = 0 ]; then
            sed -i "s#::sysinit:/sbin/openrc sysinit#::sysinit:/sbin/openrc#g" /etc/inittab
            echo inited_version=$lastest_version >>/etc/iSH-Tools/tools_inited
            echo inited_repo=\"$inite_repo\" >>/etc/iSH-Tools/tools_inited
        fi
    else
        source /etc/iSH-Tools/tools_inited
        if [ "$lastest_version" != "$inited_version" ]; then
            $echo_WARNING 检查到新版本，自动更新中...
            rm -f /etc/iSH-Tools/tools_inited /usr/local/bin/iSH-Tools
            apk add -q ${inite_repo}
            echo inited_version=$lastest_version >>/etc/iSH-Tools/tools_inited
            echo inited_repo=\"$inite_repo\" >>/etc/iSH-Tools/tools_inited
        fi
    fi
    if [ ! -e /usr/local/bin/iSH-Tools ];then
        wget -T15 -qO /usr/local/bin/iSH-Tools ${github_url}/lurenJBD/iSH-Tools/raw/main/iSH-Tools-CN.sh
        if [ $? = 0 ]; then
            $echo_INFO "iSH-Tools ${lastest_version}已经成功安装，输入iSH-Tools开始使用"
            chmod +x /usr/local/bin/iSH-Tools
        else
            $echo_ERROR "下载 iSH-Tools 失败，请检查网络"
        fi
    else
        $echo_INFO "已经安装 iSH-Tools ${lastest_version}，输入iSH-Tools开始使用"
    fi
} # 初始化并安装最新版iSH-Tools

########### Main ###########
run_main
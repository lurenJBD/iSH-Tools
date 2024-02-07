#!/bin/sh
# Moded by lurenJBD 2024.02.07
# iSH-Tools by lurenJBD 2020.10.17

########### Variable ###########
tools_setup_version="3.0"
github_url="https://github.com"
inite_repo="wget ncurses openrc bash"
HOST="baidu.com"
NAMESERVER="223.5.5.5"

RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
PLAIN='\033[0m'
echo_INFO="echo -e "${CYAN}INFO${PLAIN}""
echo_WARNING="echo -e "${YELLOW}WARNING${PLAIN}""
echo_ERROR="echo -e "${RED}ERROR${PLAIN}""

########### Function ###########
# 检查网络状况
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
}

# 检查所属地区，决定是否使用镜像站
check_location() {
    location=$(wget -qO- https://cf-ns.com/cdn-cgi/trace | awk -F'=' '/^loc=/{print $2}')
    if [[ "$location" == "CN" ]]; then
        $echo_INFO "根据当前网络环境，建议临时更换镜像源并使用GitHub镜像站"
        read -p "[*] 是否要使用镜像源? [Y/N]" user_choice
        case $user_choice in
        [yY])
            github_url="https://mirror.ghproxy.com/https://github.com"
            rm -rf /etc/apk/repositories
            echo "http://mirrors.tuna.tsinghua.edu.cn/alpine/$alpine_version/main" >>/etc/apk/repositories
            echo "http://mirrors.tuna.tsinghua.edu.cn/alpine/$alpine_version/community" >>/etc/apk/repositories
            ;;
        [nN]|*)
            $echo_INFO 已选择不使用镜像源，如果遇到访问缓慢可以再次运行本工具修改
            ;;
        esac
    fi
}

# 计时器
run_timer() {
    sleep 0.5 
    local command_name=$1
    local command_pid=$(ps | grep "$command_name" | grep -v grep | awk '{print $1}')
    local timeout=$2
    local timeout_tip=$3
    local execution_time=0
    
    wait $command_pid 2>/dev/null

    while kill -0 $command_pid 2>/dev/null; do
        sleep 1
        let execution_time+=1 
        if [ "$execution_time" -gt "$timeout" ]; then
            $echo_WARNING "超过${timeout}s未完成安装，${timeout_tip}"
            break
        fi
    done
}

# 初始化并安装最新版iSH-Tools
run_main() {
    # 获取运行环境信息
    ish_type=$(cat /proc/ish/version 2>/dev/null | awk '{print $1}')
    ish_ver=$(cat /proc/ish/version 2>/dev/null | awk '{print $2 " " $3}')
    if [[ -z "$ish_ver" ]]; then	
        ish_ver=$(sed 's/.* iSH \([0-9]\.[0-9]\.[0-9]\) (\([0-9]\{1,\}\)) \(.*\)/\1 (\2)/' /proc/version)
    fi
    if ! [[ "$ish_type" =~ "iSH" ]]; then
        $echo_ERROR 未知的iSH版本，脚本尚未支持 && exit 1
    fi
    alpine_version=$(awk -F. '{if ($1 == 3) print "v3."$2}' /etc/alpine-release)
    if [[ -z "$alpine_version" ]]; then
        $echo_ERROR 非alpine系统，脚本不支持运行 && exit 1
    fi
    # 2.X版本的旧配置文件清理
    if [ -e /opt/iSH-VNC/VNC_installed ]; then
        sed -i 's/^installed_DE=\(.*\)/installed_DE="\1"/' /opt/iSH-VNC/VNC_installed
        source /opt/iSH-VNC/VNC_installed && echo installed_apk_repo=\"$installed_DE\" > /etc/iSH-Tools/VNC_installed
        source /opt/iSH-VNC/VNC_installed_name && echo installed_apk_name=$installed_DE_name >> /etc/iSH-Tools/VNC_installed
        rm -rf /opt/iSH-VNC
    fi
    # 进行网络连接检查
    check_connection
    if [ "$No_Network" = 1 ]; then
        $echo_ERROR 无网络链接，无法安装/更新 iSH-Tools && exit 1
    else
        check_location
        lastest_version=$(wget -T10 -qO- ${github_url}/lurenJBD/iSH-Tools/raw/main/lastest_version 2>/dev/null | awk -F'=' '/^lastest_version=/{print $2}')
        installed_tip="已经安装最新版本"
        if [[ -z "$lastest_version" ]]; then
            $echo_WARNING "获取 iSH-Tools 最新版本号失败，将使用安装工具的版本号代替"
            lastest_version=$tools_setup_version
        fi
    fi
    # 安装基础依赖包
    if [ ! -e /etc/iSH-Tools/tools_inited ];then
        mkdir -p /etc/iSH-Tools
        $echo_INFO 正在安装需要的软件包...
        run_timer "apk add" 30 "可能是源下载太慢，建议使用镜像源" &
        apk add -q ${inite_repo}
        exit_code=$?
        if [ $exit_code = 0 ]; then
            sed -i "s#::sysinit:/sbin/openrc sysinit#::sysinit:/sbin/openrc#g" /etc/inittab
            echo inited_repo=\"$inite_repo\" >>/etc/iSH-Tools/tools_inited
        else
            $echo_ERROR "安装软件包失败，请检查网络并重试" && exit 1
        fi
    else
        source /etc/iSH-Tools/tools_inited
        if [ "$lastest_version" != "$inited_version" ]; then
            $echo_INFO 检查到新版本，自动更新中...
            installed_tip="已经更新为"
            rm -f /etc/iSH-Tools/tools_inited /usr/local/bin/iSH-Tools
            apk add -q ${inite_repo}
            echo inited_repo=\"$inite_repo\" >>/etc/iSH-Tools/tools_inited
        fi
    fi
    # 下载 iSH-Tools
    if [ ! -e /usr/local/bin/iSH-Tools ];then
        wget -T15 -qO /usr/local/bin/iSH-Tools ${github_url}/lurenJBD/iSH-Tools/raw/main/iSH-Tools-CN.sh
        if [ $? = 0 ]; then
            echo inited_version=$lastest_version >>/etc/iSH-Tools/tools_inited
            chmod +x /usr/local/bin/iSH-Tools
        else
            rm -f /usr/local/bin/iSH-Tools
            $echo_ERROR "下载 iSH-Tools 失败，请检查网络并重试" && exit 1
        fi
    fi
    $echo_INFO "${installed_tip} iSH-Tools ${lastest_version}，输入 iSH-Tools 开始使用"
}

########### Main ###########
run_main
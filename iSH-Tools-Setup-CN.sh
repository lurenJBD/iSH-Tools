#!/bin/sh
# Moded by lurenJBD 2024.07.09
# iSH-Tools by lurenJBD 2020.10.17

########### Variable ###########
HOST="${HOST:="www.baidu.com"}"
NAMESERVER="${NAMESERVER:="223.5.5.5"}"
Github_Url="${Github_Url:="https://github.com"}"
Mirror_Url="${Mirror_Url:="https://mirror.ghproxy.com/https://github.com"}"
Mirror_Repo="${Mirror_Repo:="http://mirrors.tuna.tsinghua.edu.cn"}" # 默认替换的镜像源链接
Bypass_Check="${Bypass_Check:=0}" # 1：跳过网络&地区检查 Net：只跳过网络检查 Loc：只跳过地区检查

inite_repo="wget ncurses openrc bash"
RED='\033[0;31m'
GREEN='\033[32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
PLAIN='\033[0m'

echo_ERROR="echo -e "${RED}ERROR${PLAIN}""
echo_OK="echo -e "${GREEN}OK${PLAIN}""

########### Function ###########
# 提示打印函数
printf_tips() {
    local level=$1 context=$2 end_line=$3 
    case $level in
        info) printf "${CYAN}%-7s${PLAIN} %-8s $end_line" "INFO" "$context";;
        warning) printf "${YELLOW}%-7s${PLAIN} %-8s $end_line" "WARNING" "$context";;
        error) printf "${RED}%-7s${PLAIN} %-8s $end_line" "ERROR" "$context";;
    esac
}

# 检查网络状况
check_connection() {
    [[ $enable_check_connection -eq 0 ]] && return 0
    ping_host() {
        ping -4 -c 1 -w 1 -A $1 &>/dev/null && ping_success=true
    }
    nslookup_addr() {
        ipv4_addresses=$(nslookup $1 $2 2>/dev/null | awk '/^Address: / { split($2, parts, ":"); if (parts[1] ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) print parts[1] }')
    }
    DNSADDR=$(grep '^nameserver' /etc/resolv.conf 2>/dev/null | head -n 1 | awk '{print $2}')
    if [ ! -n "$DNSADDR" ]; then
        printf_tips warning "未设置DNS地址，自动指定DNS为${NAMESERVER}" "\n"
        echo "nameserver ${NAMESERVER}" > /etc/resolv.conf
        DNSADDR=$NAMESERVER
    fi
    printf_tips info "正在检查网络状况..."
    ping_success=false
    if which nslookup >/dev/null 2>&1 ; then
        nslookup_addr $HOST $DNSADDR
        if [ ! -n "$ipv4_addresses" ]; then
            printf_tips warning "DNS解析失败，修改DNS为${NAMESERVER}再次尝试" "\n"
            nslookup_addr $HOST $NAMESERVER
            echo "nameserver ${NAMESERVER}" > /etc/resolv.conf
        fi
        for ip in $ipv4_addresses; do
            ping_host $ip 
            [ "$ping_success" = "true" ] && break
        done
    else
        ping_host $HOST
    fi
    [ "$ping_success" = "false" ] && $echo_ERROR && return 1
    $echo_OK
}

# 检查所属地区，决定是否使用镜像站
check_location() {
    [[ $enable_check_location -eq 0 ]] && return 0
    location=$(wget -T10 -qO- https://cf-ns.com/cdn-cgi/trace 2>/dev/null | awk -F'=' '/^loc=/{print $2}')
    if [ -z "$location" ]; then
        location=$(wget -T10 -qO- https://myip.ipip.net/ 2>/dev/null | awk -F '：' '{print $3}' | awk -F ' ' '{print $1}')
    fi
    if [[ "$location" == "CN" || "$location" == "中国" ]]; then
        printf_tips info "根据当前网络环境，建议临时更换镜像源并使用GitHub镜像站" "\n"
        read -p "[*]  是否要使用镜像源? [Y/N]" user_choice && printf '\033[A' && printf '\r\033[K'
        case $user_choice in
        [yY])
            Github_Url=$Mirror_Url
            mv /etc/apk/repositories /etc/apk/repositories-tmp.bak
            echo "${Mirror_Repo}/alpine/${alpine_version}/main" >> /etc/apk/repositories
            echo "${Mirror_Repo}/alpine/${alpine_version}/community" >> /etc/apk/repositories
            ;;
        [nN]|*)
            printf_tips warning "已选择不使用镜像源，如果访问缓慢可以再次运行本工具修改" "\n"
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
            printf "\n${YELLOW}%-7s${PLAIN} %-8s" "WARNING" "超过${timeout}s未完成安装，${timeout_tip}"
            break
        fi
    done
}

# 安装&检查软件包
set_apk_repo() {
    run_timer "apk add" 30 "可能是源下载太慢，建议使用镜像源" &
    apk add -q ${inite_repo}
    printf '\r\033[A' && printf_tips info "正在安装需要的软件包..."
    if [ $? = 0 ]; then
        sed -i "s#::sysinit:/sbin/openrc sysinit#::sysinit:/sbin/openrc#g" /etc/inittab
        echo inited_repo=\"$inite_repo\" >>/etc/iSH-Tools/tools_inited 
        $echo_OK
    else
        $echo_ERROR
        printf_tips error "安装软件包失败，请检查网络并重试" "\n" && exit 1
    fi
}

# 脚本退出前执行
shutdown() {
    printf '\r\033[K'
    if [ -e /etc/apk/repositories-tmp.bak ]; then
        mv /etc/apk/repositories-tmp.bak /etc/apk/repositories
    fi
}
trap shutdown EXIT

# 初始化并安装最新版iSH-Tools
run_main() {
    # 获取运行环境信息
    ish_type=$(cat /proc/ish/version 2>/dev/null | awk '{print $1}')
    ish_ver=$(cat /proc/ish/version 2>/dev/null | awk '{print $2 " " $3}')
    if [[ -z "$ish_ver" ]]; then	
        ish_ver=$(sed 's/.* iSH \([0-9]\.[0-9]\.[0-9]\) (\([0-9]\{1,\}\)) \(.*\)/\1 (\2)/' /proc/version)
    fi
    if ! [[ "$ish_type" =~ "iSH" ]]; then
        printf_tips error "未知的iSH版本，脚本尚未支持" "\n" && exit 1
    fi
    alpine_version=$(awk -F. '{if ($1 == 3) print "v3."$2}' /etc/alpine-release)
    if [[ -z "$alpine_version" ]]; then
        printf_tips error "非alpine系统，脚本不支持运行" "\n" && exit 1
    fi
    # 2.X版本的旧配置文件清理
    if [ -e /opt/iSH-VNC/VNC_installed ]; then
        sed -i 's/^installed_DE=\(.*\)/installed_DE="\1"/' /opt/iSH-VNC/VNC_installed
        source /opt/iSH-VNC/VNC_installed && echo installed_apk_repo=\"$installed_DE\" > /etc/iSH-Tools/VNC_installed
        source /opt/iSH-VNC/VNC_installed_name && echo installed_apk_name=$installed_DE_name >> /etc/iSH-Tools/VNC_installed
        rm -rf /opt/iSH-VNC
    fi
    enable_check_connection=1; enable_check_location=1; 
    case $Bypass_Check in
        All|true|1) enable_check_connection=0; enable_check_location=0 ;;
        Net|network) enable_check_connection=0 ;;
        Loc|location) enable_check_location=0 ;;
        None|false|0) ;; # Defaults
        *) unset Bypass_Check ;;
    esac
    # 进行网络连接检查
    check_connection || { printf_tips error "无网络，无法安装/更新 iSH-Tools" "\n" && exit 1; }
    check_location
    printf_tips info "正在获取 iSH-Tools 最新版本号..."
    lastest_version=$(wget -T10 -qO- ${Github_Url}/lurenJBD/iSH-Tools/raw/main/lastest_version 2>/dev/null | awk -F'=' '/^lastest_version=/{print $2}')
    installed_tip="安装"
    if [[ -z "$lastest_version" ]]; then
        $echo_ERROR && printf_tips error "获取 iSH-Tools 最新版本号失败，请检查网络并重试" "\n" && exit 1
    else
        $echo_OK
    fi
    # 安装基础依赖包
    if [ ! -e /etc/iSH-Tools/tools_inited ];then
        mkdir -p /etc/iSH-Tools
        printf_tips info "正在安装需要的软件包..." "\n"
        set_apk_repo
    else
        source /etc/iSH-Tools/tools_inited
        if [[ -n "$inited_version" ]]; then
            printf_tips info "检测到已安装 iSH-Tools $inited_version 版本" "\n"
            if [ $(echo "$lastest_version > $inited_version" | bc) -eq 1 ]; then
                printf_tips info "检查到新版本 ${lastest_version}" "\n"
                rm -f /usr/local/bin/iSH-Tools && sed -i '/inited_version/d' /etc/iSH-Tools/tools_inited
                installed_tip="更新"
                for word in $inite_repo; do
                    if ! echo "$inited_repo" | grep -q "$word"; then
                        need_inite_repo=1
                        break
                    fi
                done
                if [ "$need_inite_repo" = 1 ]; then
                    rm -f /etc/iSH-Tools/tools_inited
                    set_apk_repo
                fi
            fi
            if [ $(echo "$lastest_version < $inited_version" | bc) -eq 1 ]; then
                printf_tips info "远端最新版本为${lastest_version}, 低于已安装版本, 疑似数据错乱, 脚本自动退出" "\n"
                return 1
            fi
        fi
    fi
    # 下载 工具文件
    if [ ! -f "/etc/iSH-Tools/get_local_ip" ]; then
        printf_tips info "正在下载 iSH-Tools 工具文件..."
        wget -T15 -qO /etc/iSH-Tools/get_local_ip ${Github_Url}/lurenJBD/iSH-Tools/releases/download/Tools/get_local_ip
        if [ $? = 0 ]; then
            chmod +x /etc/iSH-Tools/get_local_ip
            $echo_OK
        else
            rm -f /etc/iSH-Tools/get_local_ip
            $echo_ERROR
        fi 
    fi
    # 下载 iSH-Tools
    if [ ! -e /usr/local/bin/iSH-Tools ];then
        printf_tips info "正在${installed_tip} iSH-Tools ..."
        wget -T15 -qO /usr/local/bin/iSH-Tools ${Github_Url}/lurenJBD/iSH-Tools/raw/main/iSH-Tools-CN.sh
        if [ $? = 0 ]; then
            echo inited_version=$lastest_version >>/etc/iSH-Tools/tools_inited
            chmod +x /usr/local/bin/iSH-Tools
            $echo_OK
        else
            rm -f /usr/local/bin/iSH-Tools
            $echo_ERROR
            printf_tips error "下载 iSH-Tools 失败，请检查网络并重试" "\n" && exit 1
        fi
    fi
    printf_tips info "${installed_tip} iSH-Tools ${lastest_version} 成功，输入 iSH-Tools 开始使用" "\n"
}

########### Main ###########
run_main
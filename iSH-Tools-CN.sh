#!/bin/bash
# 镜像测速部分代码来自：https://github.com/lework/script/blob/master/shell/test/os_repo_speed_test.sh
# Os repo mirror site speed test. lework copyright
# coremark https://github.com/eembc/coremark
# cpuid2cpuflags https://github.com/projg2/cpuid2cpuflags
# coremark参考成绩来自：https://www.bilibili.com/read/cv21181867
# Moded by lurenJBD 2024.07.15
# iSH-Tools by lurenJBD 2020.10.17

########### Variable ###########
tools_version="3.4"
inite_repo="wget ncurses openrc bash"
error_times=0

HOST="${HOST:="www.baidu.com"}" # 网络检测 ping 的域名
NAMESERVER="${NAMESERVER:="223.5.5.5"}" # 当遇到域名解析故障时替换的DNS服务器
Github_Url="${Github_Url:="https://github.com"}"
Mirror_Url="${Mirror_Url:="https://mirror.ghproxy.com/https://github.com"}" # 默认使用的Github镜像
Mirror_Repo="${Mirror_Repo:="http://mirrors.tuna.tsinghua.edu.cn"}" # 默认替换的镜像源链接
Bypass_Check="${Bypass_Check:=0}" # 1：跳过网络&地区检查 Net：只跳过网络检查 Loc：只跳过地区检查
Dev_Mode="${Dev_Mode:=0}" # 允许运行在非iSH下的Alpine

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
PLAIN='\033[0m'

echo_ERROR="echo -e "${RED}ERROR${PLAIN}""
echo_OK="echo -e "${GREEN}OK${PLAIN}""

########### Function ###########

# 初始化脚本
init_run() {
    # 获取运行环境信息
    ish_type=$(awk '{print $1}' /proc/ish/version 2>/dev/null)
    ish_ver=$(awk '{print $2 " " $3}' /proc/ish/version 2>/dev/null)
    if [[ -z "$ish_ver" ]]; then	
        ish_ver=$(sed 's/.* iSH \([0-9]\.[0-9]\.[0-9]\) (\([0-9]\{1,\}\)) \(.*\)/\1 (\2)/' /proc/version)
    fi
    if ! [[ "$ish_type" =~ "iSH" ]]; then
        printf_tips error "未知的iSH版本，脚本尚未支持" "\n" 
        [[ $Dev_Mode -eq 1 ]] || exit 1 # 进入开发者模式，不退出脚本
        ish_type=unkown
    fi
    alpine_version=$(awk -F. '{if ($1 == 3) print "v3."$2}' /etc/alpine-release)
    if [[ -z "$alpine_version" ]]; then
        printf_tips error "非alpine系统，脚本不支持运行" "\n" && exit 1
    fi
    [[ $Quick -eq 1 ]] && Network_OK=1 && return 0 # 参数模式跳过
    enable_check_connection=1; enable_check_location=1; 
    case $Bypass_Check in
        All|true|1) enable_check_connection=0; enable_check_location=0 ;;
        Net|network) enable_check_connection=0 ;;
        Loc|location) enable_check_location=0 ;;
        None|false|0) ;; # Defaults
        *) unset Bypass_Check ;;
    esac
    # 判断网络环境和状态
    check_connection
    [[ $Network_OK -eq 1 ]] && check_location
    # 检查是否已经初始化
    if [ ! -e /etc/iSH-Tools/tools_inited ]; then
        keep_init_run_tips=1
        mkdir -p /etc/iSH-Tools
        printf_tips info "检测到第一次运行脚本，正在初始化..." 
        [[ $Network_OK -eq 0 ]] && $echo_ERROR && printf_tips error "无网络连接，初始化失败，脚本自动退出" "\n" && exit 1
        echo && timeout 30s apk add -q ${inite_repo}
        Timeout_or_not=$?
        if [ "$Timeout_or_not" = 143 ]; then
            printf_tips warning "超过30s未完成安装，可能是源访问太慢，尝试使用镜像源安装" && 
            rm -rf /etc/apk/repositories
            echo "${Mirror_Repo}/alpine/${alpine_version}/main" >> /etc/apk/repositories
            echo "${Mirror_Repo}/alpine/${alpine_version}/community" >> /etc/apk/repositories
            apk update &>/dev/null
            echo && apk add -q ${inite_repo}
            Timeout_or_not=$?
            printf "\r\033[K\033[A" && printf_tips info "检测到第一次运行脚本，正在初始化..."
        fi
        if [ "$Timeout_or_not" = 0 ]; then
            # 当进入开发者模式不应该修改 openrc启动项，会导致正常的Alpine无法启动
            [[ $Dev_Mode -eq 0 ]] && sed -i "s#::sysinit:/sbin/openrc sysinit#::sysinit:/sbin/openrc#g" /etc/inittab
            echo inited_version=\"$tools_version\" >>/etc/iSH-Tools/tools_inited
            echo inited_repo=\"$inite_repo\" >>/etc/iSH-Tools/tools_inited
            $echo_OK
        else
            $echo_ERROR
            printf_tips error "安装软件包失败，请检查网络并重试" "\n" && exit 1
        fi
    fi
}

# 检查网络状况
check_connection() {
    [[ $enable_check_connection -eq 0 ]] && Network_OK=1 && return 0
    ping_host() {
        ping -4 -c 1 -w 1 -A $1 &>/dev/null && Network_OK=1
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
    Network_OK=0
    if which nslookup >/dev/null 2>&1 ; then
        nslookup_addr $HOST $DNSADDR
        if [ ! -n "$ipv4_addresses" ]; then
            nslookup_addr $HOST $NAMESERVER
            printf_tips warning "DNS解析失败，修改DNS为${NAMESERVER}再次尝试" "\n"
            echo "nameserver ${NAMESERVER}" > /etc/resolv.conf
        fi
        for ip in $ipv4_addresses; do
            ping_host $ip 
            [ "$Network_OK" = 1 ] && break
        done
    else
        ping_host $HOST
    fi
    [ "$Network_OK" = 0 ] && $echo_ERROR && keep_init_run_tips=1 && return 1
    $echo_OK;
}

# 检查所属地区，决定是否使用镜像站
check_location() {
    [[ $enable_check_location -eq 0 ]] && return 0
    source /etc/iSH-Tools/tools_inited
    [ "$use_china_mirror" = "true" ] && return 0 # 默认使用国内镜像
    location=$(wget -T10 -qO- https://cf-ns.com/cdn-cgi/trace 2>/dev/null | awk -F'=' '/^loc=/{print $2}')
    if [ -z "$location" ]; then
        location=$(wget -T10 -qO- https://myip.ipip.net/ 2>/dev/null | awk -F '：' '{print $3}' | awk -F ' ' '{print $1}')
    fi
    if [[ "$location" == "CN" || "$location" == "中国" ]]; then
        keep_init_run_tips=1
        printf_tips info "根据当前网络环境，建议更换镜像源并使用GitHub镜像站" "\n"
        read -p "[*] 是否要使用镜像源?输入A将默认使用镜像站,不再询问 [Y/N/A]" user_choice && printf '\033[A\r\033[K'  # 清除用户输入行
        case $user_choice in
            [yY])
                Github_Url=$Mirror_Url
                export REMOTE="${Github_Url}/ohmyzsh/ohmyzsh.git"
                ;;
            [aA])
                echo "Github_Url=$Mirror_Url" >> /etc/iSH-Tools/tools_inited
                echo "export REMOTE=${Github_Url}/ohmyzsh/ohmyzsh.git" >> /etc/iSH-Tools/tools_inited
                echo "use_china_mirror=true" >> /etc/iSH-Tools/tools_inited
                ;;
            *)
                printf_tips warning "已选择不使用镜像源，如果访问缓慢可以再次运行本工具修改" "\n"
                ;;
        esac
        if [ "$user_choice" = "y" ] || [ "$user_choice" = "a" ]; then
            rm -rf /etc/apk/repositories 
            [ "$user_choice" = "a" ] && rm -rf /ish # 不让iSH自动恢复为原本的源
            echo "# Generated by iSH-Tools, choose to use the 默认源" >>/etc/apk/repositories
            echo "${Mirror_Repo}/alpine/${alpine_version}/main" >> /etc/apk/repositories
            echo "${Mirror_Repo}/alpine/${alpine_version}/community" >> /etc/apk/repositories
        fi
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

# 提示打印函数
printf_tips() {
    local level=$1 context=$2 end_line=$3 
    case $level in
        info) printf "${CYAN}%-7s${PLAIN} %-8s $end_line" "INFO" "$context";;
        warning) printf "${YELLOW}%-7s${PLAIN} %-8s $end_line" "WARNING" "$context";;
        error) printf "${RED}%-7s${PLAIN} %-8s $end_line" "ERROR" "$context";;
    esac
}

# 使用说明
usage() {
    cat <<-EOF
	iSH-Tools $tools_version

	Usage: 
	    -cs , --change_sources | 一键更换镜像源
	    -iv , --install_vnc    | 一键安装VNC服务
	    -is , --install_sshd   | 一键安装SSH服务
	    -h  , --help           | 显示帮助信息
	    
	EOF

    exit 1
}

# 函数入口
ish_main() {
    case "$1" in
    -h | --help)
        usage ;;
    -cs | --change_sources)
        Quick=1; init_run && repo_mirrors_manager 1 ;;
    -iv | --install_vnc)
        Quick=1 do_type=vnc services=VNC services_port=5900 services_name=x11vnc; init_run && config_services 1;;
    -is | --install_sshd)
        Quick=1 do_type=ssh services=SSH services_port=8022 services_name=sshd apk_name=openssh; init_run && config_services 1;;
    *)
        init_run && [[ $keep_init_run_tips -ne 1 ]] && clear
        main_menu
        ;;
    esac
}

# 镜像源管理
repo_mirrors_manager() {
    local repos_bak="repositories.bak"
	local file_path="/alpine/v3.14/releases/x86/"
	local file_name="alpine-minirootfs-3.14.0-x86.tar.gz"
	local speed_test_log="/tmp/speed_test.log"
    unset user_choice
    # 镜像源列表
    declare -A mirrors=(
        [1]="官方源:http://dl-cdn.alpinelinux.org"
        [2]="交大源:https://mirrors.sjtug.sjtu.edu.cn"
        [3]="中科源:http://mirrors.ustc.edu.cn"
        [4]="兰大源:https://mirror.lzu.edu.cn"
        [5]="南大源:http://mirrors.nju.edu.cn"
        [6]="北外源:https://mirrors.bfsu.edu.cn"
        [7]="东软源:http://mirrors.neusoft.edu.cn"
        [8]="清华源:http://mirrors.tuna.tsinghua.edu.cn"
        [9]="华为源:http://repo.huaweicloud.com"
        [10]="腾讯源:http://mirrors.cloud.tencent.com"
        [11]="阿里源:http://mirrors.aliyun.com"
    )
	# 镜像源测速
    mirrors_speedtest() {
        # 旋转动画
		mirrors_speedtest_spin() {
            local LC_CTYPE=C spin='-\|/' i=0
            mirrors_speedtest_wget "$@" &
            tput civis
            while kill -0 $! 2>/dev/null; do
                i=$(((i + 1) % ${#spin}))
                printf "\r%s" "${spin:$i:1}"
                echo -en "\033[1D"
                sleep .1
            done
            tput cnorm
            wait $!
        } 
        # 测速功能
		mirrors_speedtest_wget() {
            local output=$(LANG=C wget -4O /dev/null -T30 "$1" 2>&1)
            local speed=$(printf '%s' "$output" | awk '/\/dev\/null/ {speed=$3 $4} END {gsub(/\(|\)/,"",speed); print speed}')
            local ipaddress=$(printf '%s' "$output" | awk -F'|' '/Connecting to .*\|([^\|]+)\|/ {print $2}' | tail -1)
            local time=$(printf '%s' "$output" | awk -F= '/100% / {print $2}')
            local size=$(printf '%s' "$output" | awk '/Length:/ {s=$3} END {gsub(/\(|\)/,"",s); print s}')
            [ -z "$speed" ] && speed=0KB/s
            [ -z "$ipaddress" ] && ipaddress=null time=null size=null
            printf "${YELLOW}%-12s${GREEN}%-19s${CYAN}%-12s${PLAIN}%-11s${RED}%-10s${PLAIN}\n" "$2" "${ipaddress}" "${size}" "${time}" "${speed}"
            speed=$(echo "$speed" | awk '{if ($0 ~ /MB\/s/) printf "%.0fKB/s", $1*1024; else print}')
            echo "$2 ${mirrors[$key]#*:} $speed" >>$speed_test_log
        } 
        clear && check_connection
        [[ $Network_OK -eq 0 ]] && printf_tips error "无网络连接，无法进行优选" "\n" && return 1
        printf_tips info "正在进行镜像源优选，会需要一些时间" "\n"
        echo -e "\n[测试信息]"
        echo -e "系统信息: ${YELLOW}Alpine ${alpine_version}${PLAIN}"
        echo -e "下载文件: ${YELLOW}${file_name}${PLAIN}"
        echo
        rm -f $speed_test_log
        printf "%-13s%-21s%-16s%-15s%-10s\n" "镜像站点" "IPv4地址" "文件大小" "下载用时" "下载速度"
        for key in $(seq 1 11); do
            mirrors_speedtest_spin "${mirrors[$key]#*:}${file_path}${file_name}" "${mirrors[$key]%:h*}"
        done
        sort -k 3 -n -r -o $speed_test_log $speed_test_log
        mirror_link=$(head -n 1 $speed_test_log | cut -d ' ' -f2)
        mirror_name=$(head -n 1 $speed_test_log | cut -d ' ' -f1)
    }
	# 备份源文件
    backup_sources() {
        if [ ! -e /etc/apk/${repos_bak} ]; then
            printf_tips info "创建 ${repos_bak} 备份" "\n"
            cp /etc/apk/repositories /etc/apk/${repos_bak}
        else
            [[ $Need_Confirm -eq 1 ]] || return 0
            printf_tips info "检测到 ${repos_bak} 备份，是否要覆盖? [y/n]" "\n"
            read -n 1 user_choice
            case $user_choice in
            [yY])
                rm -f /etc/apk/${repos_bak}
                cp /etc/apk/repositories /etc/apk/${repos_bak};;
            [nN]|*)
                printf_tips info "不覆盖 ${repos_bak} 备份" "\n" ;;
            esac
        fi
    }
	# 恢复源文件
    restore_sources(){
        if [ ! -e /etc/apk/${repos_bak} ]; then
            printf_tips warning "没找到 ${repos_bak} 备份文件，需要先备份才能恢复" "\n"
        else
            mv /etc/apk/${repos_bak} /etc/apk/repositories
            sed -i '/use_china_mirror=true/d' /etc/iSH-Tools/tools_inited
            printf_tips info "已恢复源信息, ${repos_bak} 备份文件已删除" "\n"
        fi
    }
    # 恢复iSH内置源
    restore_ish_sources(){
        [[ $Dev_Mode -eq 1 ]] && printf_tips warning "处于开发者模式，不支持该功能!" "\n" && return 0
        if [ ! -e /ish/apk-version ]; then 
            version=$(awk '{print $3}' /proc/ish/version 2>/dev/null | sed 's/[()]//g')
            mkdir /ish 2>/dev/null
            echo $version >/ish/apk-version
            echo $version >/ish/version
            if [ "$alpine_version" = "v3.19" ]; then
                echo 31900 >/ish/apk-version # TF 版 iSH 运行ALpine v3.19
            fi
        fi
        printf_tips info "已恢复iSH源锁定功能，重启App后生效" "\n"
    }
	# 更换源文件
    change_sources() {
        if [ -z "$user_choice" ]; then
            printf "${CYAN}%-8s${PLAIN}%-9s ${YELLOW}%-9s${PLAIN} %-9s \n" "INFO" "是否将" "$2" "作为镜像源使用? [y/n]"
            read -n 1 user_choice
        fi
        case $user_choice in
        [yY])
            backup_sources
            rm -rf /etc/apk/repositories /ish
            echo "# Generated by iSH-Tools, choose to use the $2" >>/etc/apk/repositories
            echo "$1/alpine/$alpine_version/main" >>/etc/apk/repositories
            echo "$1/alpine/$alpine_version/community" >>/etc/apk/repositories
            echo "use_china_mirror=true" >> /etc/iSH-Tools/tools_inited
            printf_tips info "正在更新源缓存" "\n"
            apk update -q
            printf_tips info "源信息修改完成" "\n" ;;
        [nN]|*)
            clear && printf_tips info "源信息未做更改" "\n" && sleep 0.5;;
        esac
    }
	# 选择镜像源
    select_sources() {
        while :; do
            sleep 0.1
            echo -e "\n[镜像站点]"
            for key in $(seq 1 11); do
                printf "%0s.${PLAIN}%-2s: ${GREEN}%-3s${PLAIN}\n" ${key} "${mirrors[$key]%:h*}" "${mirrors[$key]#*:}"
            done
            read -p "请输入编号[0-11]:(输入 0 进行优选, q 返回上层)" mirror
            if [ "$mirror" = "q" ]; then
                clear && return 0
            elif [[ ! $mirror =~ ^[0-9]+$ ]]; then
                clear && $echo_ERROR "请输入正确的数字!"
            elif [ "$mirror" = 0 ]; then
                [[ $Network_OK -eq 0 ]] && return 1
                mirrors_speedtest
                break
            elif [[ ! -v mirrors[$mirror] ]]; then
                clear && $echo_ERROR "输入的数字不在选项中，请重新输入！" && sleep 0.5
            else
                mirror_name="${mirrors[$mirror]%:h*}"
                mirror_link="${mirrors[$mirror]#*:}"
                user_choice="y"
                break
            fi
        done
        change_sources $mirror_link $mirror_name
    }
    
    case $1 in
    1) select_sources;;
    2) Need_Confirm=1; backup_sources;;
    3) restore_sources;;
    4) restore_ish_sources;;
    esac
}

# 错误提醒与终止
error_tips() {
    case $1 in
        1) $echo_ERROR "只能输入 [Y/N]";;
        2) $echo_ERROR "输入内容有误?";;
        3) clear && $echo_ERROR 无效的选项，请重新选择;;
    esac
    error_times=$((error_times + 1))
    [ $error_times -ge 10 ] && $echo_ERROR "已累计出现${error_times}次错误，脚本已退出" && exit 1
} 

# X-org配置初始化
xinit_vnc() {
    [ ! -e /etc/X11/xorg.conf.d ] && mkdir -p /etc/X11/xorg.conf.d
    if [ ! -e /etc/X11/xorg.conf.d/10-headless.conf ]; then
        cat >/etc/X11/xorg.conf.d/10-headless.conf  <<-EOF
		Section "Monitor"
		        Identifier "dummy_monitor"
		        HorizSync 28.0-80.0
		        VertRefresh 48.0-75.0
		        DisplaySize  250 174
		EndSection

		Section "Device"
		        Identifier "dummy_card"
		        VideoRam 256000
		        Driver "dummy"
		EndSection

		Section "Screen"
		        Identifier "dummy_screen"
		        Device "dummy_card"
		        Monitor "dummy_monitor"
		        SubSection "Display"
		           depth 24
		           Modes $VL
		        EndSubSection
		EndSection
		EOF
    fi
    if [ ! -e /root/.xinitrc ]; then
        cat > /root/.xinitrc <<-EOF
		xrdb -merge ~/.Xresources
		EOF
    fi
    if [ "$CMD" = "exec i3" ]; then
		echo "xterm -geometry 80x50+494+51 &" >>/root/.xinitrc
		echo "xterm -geometry 80x20+494-0 &" >>/root/.xinitrc
    fi
    echo "${CMD}" >>/root/.xinitrc
    if [ ! -e /root/.Xresources ]; then
        cat >/root/.Xresources <<-EOF
		Xft.dpi: 264
		xterm*VT100.Translations: #override \
		    Ctrl <Key> minus: smaller-vt-font() \n\
		    Ctrl <Key> plus: larger-vt-font() \n\
		    Ctrl <Key> 0: set-vt-font(d)
		EOF
    fi
}

# 创建服务启动文件
create_service() {
    if [ ! -e /etc/init.d/x11vnc ]; then
        cat >/etc/init.d/x11vnc <<-EOF
		#!/sbin/openrc-run
		name="x11vnc"
		description="x11vnc is a Virtual Network Computing server program to access X Windows desktop session"

		start_pre() {
		        if ! pidof xinit >/dev/null; then
		            rc-service xinit start
		            sleep 3
		        fi
		}

		start() {
		        ebegin "Starting x11vnc"
		        start-stop-daemon -Sbmp /run/x11vnc.pid --exec x11vnc -- -xkb -noxrecord -noxfixes -noxdamage -display :0 -noshm -nopw -forever
		        eend $?
		}

		stop() {
		        ebegin "Stopping x11vnc"
		        start-stop-daemon -Kqp /run/x11vnc.pid
		        eend $?
		        rc-service xinit stop
		} 
		EOF
        chmod +x /etc/init.d/x11vnc
    fi
    if [ ! -e /etc/init.d/xinit ]; then
        cat >/etc/init.d/xinit <<-EOF
		#!/sbin/openrc-run
		name="xinit"
		description="xinit is a tool to starts the X Window System server"

		start() {
		        ebegin "Starting xinit"
		        start-stop-daemon -Sbmp /run/xinit.pid --exec xinit -- X :0
		        eend $?
		}

		stop() {
		        ebegin "Stopping xinit"
		        start-stop-daemon -Kqp /run/xinit.pid
		        eend $?
		}
		EOF
        chmod +x /etc/init.d/xinit
    fi
    # 3.4版本之前的服务名称命名不规范，这里作修正处理
    if [ -e /etc/init.d/get_location ]; then
        status=$(rc-service get_location status 2>&1)
        rc-service get_location stop 2>/dev/null
        rc-update del get_location 2>/dev/null
        sed -i 's/get_location/get-location/g' /etc/init.d/get_location
        mv /etc/init.d/get_location /etc/init.d/get-location
        chmod +x /etc/init.d/get-location
        if echo "$status" | grep -q "started\|crashed"; then
            rc-service get-location start
            rc-update add get-location
        fi
    fi
    if [ ! -e /etc/init.d/get-location ]; then
        cat >/etc/init.d/get-location <<-EOF
		#!/sbin/openrc-run
		name="get-location"
		description="get location to keep iSH running in the background"

		start() {
		        ebegin "Starting get-location"
		        start-stop-daemon -Sb -m -p /run/get-location.pid --exec cat -- /dev/location >/dev/null
		        eend $?
		}

		stop() {
		        ebegin "Stopping get-location"
		        start-stop-daemon -Kqp /run/get-location.pid
		        eend $?
		}
		EOF
        chmod +x /etc/init.d/get-location  
    fi
}

# 获取位置权限，用于保持后台运行
background_running() {
    if pgrep -f "cat /dev/location" >/dev/null; then
        printf_tips info "iSH已经保持后台运行了" "\n"
        read -p "[*] 是否要取消保持后台运行? [Y/N]" user_choice
        case $user_choice in
            [yY])
                killall -TERM cat
                rc-service get-location stop 2>/dev/null
                rc-update del get-location 2>/dev/null ;;
            *) printf_tips info "iSH会继续保持后台运行" "\n";;
        esac
    else
        local i=0
        cat /dev/location >/tmp/location.log &
        printf_tips info "申请位置权限仅用于保持iSH后台运行" "\n"  
        printf_tips info "请在iOS授权界面上点击 '使用App时允许'" "\n"
        while ((i < 15)); do
            if [ -s /tmp/location.log ]; then
                printf_tips info "已赋予位置权限" "\n"
                killall -TERM cat && rm /tmp/location.log
                create_service
                rc-update add get-location 2>/dev/null
                rc-service get-location start 2>/dev/null
                if [ $? != 0 ]; then
                    cat /dev/location >/dev/null &
                fi
                break
            else
                sleep 1
                ((i++))
            fi
        done
        if [ $i -gt 16 ]; then
            $echo_ERROR "超时15秒，无法获取位置权限，iSH无法保持后台运行"
            killall -TERM cat && rm /tmp/location.log
        fi
    fi
} 

# 更新脚本
update_script() {
    clear
    printf_tips info "正在更新iSH-Tools..." "\n"
    sh -c "$(wget -T15 -qO- ${Github_Url}/lurenJBD/iSH-Tools/raw/main/iSH-Tools-Setup-CN.sh)"
}

# 获取服务的安装和运行状态
get_services_status() {
    for service in SSH VNC; do
        if [ -e /etc/iSH-Tools/${service}_installed ]; then
            eval ${service}_install="已安装"
            eval ${service}_color="\$GREEN"
        else
            eval ${service}_install="未安装"
            eval ${service}_color="\$RED"
        fi
    done

    for services_name in sshd x11vnc; do
        if rc-service ${services_name} status 2>/dev/null | grep -qi "started"; then
            eval ${services_name}_status="已启动"
            eval ${services_name}_color="\$GREEN"
        else
            eval ${services_name}_status="未启动"
            eval ${services_name}_color="\$RED"
        fi
    done
}

# 判断使用什么源
get_repo_status() {
    if grep apk.ish.app /etc/apk/repositories >/dev/null 2>&1; then
        repo_name="iSH源"
    else
        repo_name=$(grep "iSH-Tools" /etc/apk/repositories | awk '{print $9}')
    fi
    if [ -z "$repo_name" ]; then
        repo_color="$RED"
        repo_name="未知源"
    else
        repo_color="$GREEN"
    fi
}

# 运行各种工具
run_tools() {
    # 下载各种工具
    download_tools() {
        if [[ "$tool" = "coremark" ]]; then
            tool_file="coremark_pthread.tar.gz"
        else
            tool_file=$tool
        fi
        
        if [ ! -e "$tools_dir/$tool_file" ]; then
            printf_tips warning "缺少 ${tool} 文件，从网络下载..." "\n"
            check_connection
            [[ $Network_OK -eq 0 ]] && $echo_ERROR "无网络连接，无法下载${tool}" && return 1
            wget -T15 -qO ${tools_dir}/${tool_file} ${Github_Url}/lurenJBD/iSH-Tools/releases/download/Tools/${tool_file}
            if [ $? = 0 ]; then
                chmod +x ${tools_dir}/${tool_file}
                # ln -s ${tools_dir}/${tool_file} /usr/local/bin/${tool}
            else
                $echo_ERROR "下载 ${tool} 文件失败，请检查网络并重试" && return 1
            fi
        fi
        if [[ ! -d "$tools_dir/coremark" && "$tool" = "coremark" ]]; then
            printf_tips info "解压 $tool_file 中..." "\n"
            mkdir -p "$tools_dir/coremark/logs" 
            tar -zxf ${tools_dir}/${tool_file} -C ${tools_dir}/coremark
        fi
    }

    local tools_dir="/etc/iSH-Tools/other_tools" cpu_count=$(nproc) tool=$1
    mkdir -p "$tools_dir"
    download_tools || return 1

    case $tool in
    cpuid2cpuflags)
        ${tools_dir}/cpuid2cpuflags | sed -n 's/^CPU_FLAGS_X86: //p' | awk '{printf "支持的指令集："; for(i=1;i<=NF;i++) printf "%s ", $i; printf "\n"}'
        ;;
    coremark)
        pthread_nums=(1 2 4 6 8)
        printf_tips info "${ish_type} 有 ${cpu_count} 个线程" "\n"
        if [ "$cpu_count" -ge 9 ]; then
            printf_tips warning "预编译的CoreMark只支持到 8 线程，如要支持更多线程，建议手动编译" "\n"
        fi
        for num in "${pthread_nums[@]}"; do
            if [ "$num" -le "$cpu_count" ]; then
                file="coremark_pthread_$num"
                case $num in
                    1) name="单";;
                    2) name="双";;
                    4) name="四";;
                    6) name="六";;
                    8) name="八";;
                esac
                printf "${CYAN}%-7s${PLAIN} %-8s ${YELLOW}%-9s${PLAIN} %-10s \n" "INFO" "正在进行 coremark" "${name}线程" "性能测试，请稍等..."
                chmod +x "${tools_dir}/coremark/$file"
                "${tools_dir}/coremark/$file" 0x0 0x0 0x66 0 7 1 2000 > "${tools_dir}/coremark/logs/$file.log"
                score=$(cat "${tools_dir}/coremark/logs/$file.log" | grep "CoreMark 1.0" | awk '{print $4}')
                formatted_score=$(printf "%.1f" "$score")
                printf '\033[A\r\033[K' # 光标回到上一行，并清除该行内容
                printf "${CYAN}%-7s${PLAIN} ${YELLOW}%-8s${PLAIN} %-9s \n" "INFO" "${name}线程" "得分：$formatted_score"
                # 倒计时显示效果器
                if [ "$num" -lt 8 ]; then
                wait_time=(5 + 1)
                start_time=$(date +%s)
                c=$wait_time
                tput civis
                while [[ $(($(date +%s) - start_time)) -lt $wait_time ]]; do
                    printf '设备散热中，等待 %s 秒\r' "$(( --c ))"
                    sleep 1
                done
                printf '\r\033[K' # 清除该行的内容
                tput cnorm
                fi
            fi
        done
        echo -e "参考成绩\nJ1900(x86)   4核  34060\nMT7621(MIPS) 2核  4547\nN1盒子(ARM)  4核  18404"
        ;;
    esac
    sleep 0.5 && echo
}

# 修改Root账户密码
change_root_password() {
    printf_tips info "正在修改root账户密码，Ctrl + C 取消修改" "\n"
    printf_tips info "输入的密码是看不见的，需要输入两次" "\n"
    passwd root
    if [ $? = 0 ]; then
        printf_tips info "修改root账户密码成功" "\n"
    else
        printf_tips error "修改root账户密码失败" "\n"
    fi
}

# 配置服务(选择安装、删除或更改)
config_services() {
    local do_what=$1
    local ask_info apk_repo CMD
    case $do_what in
        1) ask_info="安装";;
        2) ask_info="删除";;
        3) ask_info="更改";;
        4) do_something_command;;
    esac
    if [[ "$do_type" == "vnc" && "$do_what" != "2" ]]; then
        clear
        declare -A options=(
        [1]="awesome桌面:awesome"
        [2]="i3wm桌面:i3wm"
        [3]="fluxbox桌面:fluxbox"
        )
        print_menu 1 3 返回上层 选择桌面环境
        while :; do
            read -p "[*]  请选择想${ask_info}的桌面环境[1-3]:" chosen_option
            case $chosen_option in
                q)  unset do_what; break;;
            [1-3])  apk_name=${options[$chosen_option]#*:}; break ;;
                *)  error_tips 2 ;;
            esac
        done
    fi
    case "$apk_name" in
        awesome)
            # 在v3.19中没有adwaita-gtk2-theme，在v3.14里没有font-dejavu
            if [ "$alpine_version" = "v3.19" ]; then
                apk_repo='awesome feh lua font-dejavu' 
            else
                apk_repo='awesome feh lua adwaita-gtk2-theme adwaita-icon-theme'
            fi  
            CMD='exec awesome'
            ;;
        i3wm)
            apk_repo='i3wm i3wm-doc i3status i3status-doc i3lock i3lock-doc ttf-dejavu'
            CMD='exec i3'
            ;;
        fluxbox)
            apk_repo='fluxbox'
            CMD='exec fluxbox'
            ;;
        openssh) apk_repo='openssh' ;;
        ohmyzsh) apk_repo='zsh git' ;;
    esac
    clear
    do_something_command $do_what
}

# 执行动作(安装、删除或更改)
do_something_command() {
    [ -e /etc/iSH-Tools/${services}_installed ] && source /etc/iSH-Tools/${services}_installed
    ask_keepruning() {
        status=$(rc-service get-location status 2>&1)
        if ! echo "$status" | grep -q "started\|crashed"; then
            read -p "[*] 是否让iSH保持后台运行?建议iPhone用户启用 [Y/N]" user_choice
            case $user_choice in
            [yY])
                background_running ;;
            [nN]|*)
                printf_tips info "已选择不让iSH保持后台运行，如需更改请从'其他工具'里查看" "\n" ;;
            esac
        fi
    }
    chance_vnc_resolution() {
        [ ! -e /etc/X11/xorg.conf.d/10-headless.conf ] && $echo_ERROR "没找到VNC服务配置文件，无法修改" && config_vnc_menu
        config_vnc_resolution
        sed -i "s#^           Modes.*#           Modes "$VL"#g" /etc/X11/xorg.conf.d/10-headless.conf
        clear && printf_tips info "VNC分辨率已修改为$VL,重启VNC服务后生效" "\n" && config_vnc_menu
    }
    do_change() {
        if [ "$apk_name" = "$installed_apk_name" ]; then
            printf_tips info "${apk_name}桌面环境已经安装，无需更换" "\n"
        elif [ ! -e "/etc/iSH-Tools/${services}_installed" ]; then
            printf_tips warning "未安装${services}服务" "\n"
        else
            change_apk=$apk_name
            do_del
            do_install
            unset change_apk
        fi
    }
    do_del() {
        if [ ! -e "/etc/iSH-Tools/${services}_installed" ]; then
            printf_tips warning "未安装${services}服务" "\n"
            return 0
        fi
        if [ -z "$apk_name" ]; then
            apk_name=$installed_apk_name
        fi
        if [ -z "$change_apk" ]; then
            read -p "[*]  确认删除${apk_name}软件包[Y/N]:" var
            case $var in
                [yY]) printf '\033[A\r\033[K';;
                [nN]|*) return 0;;
            esac
        fi
        [ ! -z "$change_apk" ] && apk_name=$installed_apk_name
        printf_tips info "正在删除${apk_name}软件包" "\n"
        apk del -q ${installed_apk_repo}
        rm -rf ${rm_file} /etc/iSH-Tools/${services}_installed
        if [ "$do_type" = zsh ]; then
            sh ~/.oh-my-zsh/tools/uninstall.sh
            sed -i 's/\/bin\/zsh/\/bin\/ash/g' /etc/passwd
            printf_tips info "已恢复默认终端为ash，重启iSH App以查看效果" "\n"
        else
            if [ -z "$change_apk" ]; then
                rc-update del ${services_name} 2>/dev/null
                sed -i "/^\$echo_INFO.*${services}/d" /root/.profile 2>/dev/null
                rm -f /etc/init.d/${services_name}
            fi
        fi
        printf_tips info "已删除${apk_name}及配置文件" "\n"
        [ ! -z "$change_apk" ] && unset installed_apk_name && apk_name=$change_apk
    }
    do_install() {
        if [ -e "/etc/iSH-Tools/${services}_installed" ] || [ "$apk_name" = "$installed_apk_name" ]; then
            printf_tips info "${services}服务已安装，无需重复安装" "\n"
        else
            check_connection
            [[ $Network_OK -eq 0 ]] && $echo_ERROR "无网络连接，无法安装${services}服务" && return 1
            if [ "$do_type" = vnc ]; then
                [ ! -e /etc/X11/xorg.conf.d/10-headless.conf ] && config_vnc_resolution && clear
                xinit_vnc
                create_service
                vnc_de='xvfb x11vnc x11vnc-doc xorg-server xdpyinfo xdpyinfo-doc xf86-video-dummy xterm' rm_file='/root/.xinitrc'
            fi
            printf_tips info "正在安装${services}服务和${apk_name}" "\n"
            apk update &>/dev/null
            run_timer "apk add" 120 "可能是源访问太慢，建议使用镜像源" &
            apk add -q ${apk_repo} ${vnc_de}
            Timeout_or_not=$?
            if [ "$do_type" = ssh ]; then
                [ ! -e /etc/ssh/ssh_host_ed25519_key ] && printf_tips info "正在生成SSH安全密匙" "\n" && ssh-keygen -A
                rm_file='/etc/ssh/sshd_config'
                echo 'root:alpine' | chpasswd
                sed -i "s/^#Port.*/Port 8022/g" /etc/ssh/sshd_config
                sed -i "s/^#PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config
                sed -i "s/^#ListenAddress.*/ListenAddress 0.0.0.0/g" /etc/ssh/sshd_config
                sed -i "s/^#PasswordAuthentication.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config
                printf_tips info "[*] SSH登入信息 用户名/密码: root/alpine" "\n"
            fi
            if [ "$do_type" = zsh ]; then
                BRANCH=master rm_file='/etc/iSH-Tools/ohmyzsh/tools/install.sh'
                if [ ! -e /etc/iSH-Tools/ohmyzsh/install.sh ]; then
                    git config --global http.postBuffer 524288000
                    git config --global pack.threads 1
                    mkdir -p /etc/iSH-Tools/ohmyzsh/
                    wget -T15 -qO /etc/iSH-Tools/ohmyzsh/install.sh ${Github_Url}/ohmyzsh/ohmyzsh/raw/master/tools/install.sh
                fi
                sh /etc/iSH-Tools/ohmyzsh/install.sh --unattended
                if [ "$Timeout_or_not" = 0 ]; then
                    sed -i 's/\/bin\/ash/\/bin\/zsh/g' /etc/passwd
                    printf_tips info "已修改默认终端为zsh，重启iSH App以查看效果" "\n"
                fi
            fi
            if [ "$Timeout_or_not" = 0 ]; then
                echo installed_apk_name=\"$apk_name\" > "/etc/iSH-Tools/${services}_installed"
                echo installed_apk_repo=\"$apk_repo $vnc_de\" >> "/etc/iSH-Tools/${services}_installed"
                echo rm_file=\"$rm_file\" >> "/etc/iSH-Tools/${services}_installed"
                printf_tips info "${services}服务安装成功" "\n"
                ask_keepruning
            else
                printf_tips error "${services}服务安装失败" "\n"
            fi
        fi
    }
    case "$do_what" in
        1) do_install ;;
        2) do_del ;;
        3) do_change ;;
        4) chance_vnc_resolution ;;
    esac
    unset apk_repo apk_name
}

# 配置VNC分辨率
config_vnc_resolution() {
    local resolution vnc_resolution
    custom_vnc_resolution() {
        echo "请输入分辨率长度和高度，用'x'分隔(只取前4位数字):"
        read resolution
        if [[ $resolution =~ ^[0-9]{3,4}x[0-9]{3,4}$ ]]; then
            printf_tips info "输入的分辨率为 $resolution,确认修改 [Y/N]" "\n"
            read var
            case $var in
                [yY]) VL="\"$resolution\"";;
                [nN]|*) 
                    printf_tips info "重新选择VNC分辨率" "\n"
                    sleep 1 && config_vnc_resolution;;
            esac
        else
            printf_tips warning "无效值,请重新输入!" "\n" && custom_vnc_resolution
        fi 
    }
    declare -A options=(
    [1]="1280x720  推荐iPhone使用"
    [2]="1024x768  推荐iPad使用"
    [3]="1280x1024 推荐iPad Pro使用"
    [4]="自定义分辨率"
    )
    clear; print_menu 1 4 返回上层 配置VNC分辨率
    read -p "[*] 请选择分辨率 [1/2/3]:" var
    case $var in
        q) clear && config_vnc_menu;;
        1) VL='"1280x720"';;
        2) VL='"1024x768"';;
        3) VL='"1280x1024"';;
        4) custom_vnc_resolution;;
        *) error_tips 3 && config_vnc_resolution;;
    esac 
}

# 配置服务启动
config_services_boot() {
    local_ip=$(/etc/iSH-Tools/get_local_ip 2>/dev/null) || local_ip='<设备IP>'
    local notes="${services}服务已经启动，请用${services}客户端访问 \${local_ip}:${services_port}"
    enable_color=(0 1 1)
    menu_color=("1"); menu_action=("1"); do_service=("1"); pnum=24
    
    status=$(rc-service ${services_name} status 2>&1)
    if echo "$status" | grep -q "started\|crashed"; then 
        menu_action+=("停止") menu_color+=($RED) do_service+=("stop")
    else
        menu_action+=("启动") menu_color+=($GREEN) do_service+=("start")
    fi
    rc_status=$( rc-update show -v | grep ${services_name})
    if echo "$rc_status" | grep -q "default"; then
        menu_action+=("取消") menu_color+=($RED) do_service+=("del")
    else
        menu_action+=("开启") menu_color+=($GREEN) do_service+=("add")
    fi
    declare -A options=(
    [1]=" ${services}服务"
    [2]=" ${services}服务自启动"
    )
    print_menu 1 2 返回上层 ${services}服务管理菜单
    case $chosen_option in
        [1-2]) do=${do_service[$chosen_option]};;
        q) clear && config_${do_type}_menu ;;
        *) error_tips 3 ;;
    esac
    case $do in
        start) clear
            rc-service ${services_name} start 2>/dev/null
            if [ $? = 0 ]; then
                printf_tips info "${services}服务已启动,请用${services}客户端连接 ${local_ip}:${services_port} 以访问" "\n"
            else
                printf_tips error "${services}服务启动失败" "\n"
                printf_tips info "因iSH存在BUG，首次安装${services}服务后需要重启iSH App才能正常启动" "\n"
            fi ;;
        stop) clear
            rc-service ${services_name} stop
            if [ $? = 0 ]; then
                printf_tips info "${services}服务已停止" "\n"
            else
                printf_tips error "${services}服务停止失败" "\n"
                printf_tips info "因iSH存在BUG，首次安装${services}服务后需要重启iSH App才能正常停止" "\n"
            fi ;;
        add) clear
            rc-update add ${services_name} default 2>/dev/null
            if [ $? = 0 ]; then
                # 在 3.4 版本中支持即时读取当前设备IP，不再修改/etc/motd
                grep -q '^INFO' /etc/motd && sed -i '/^INFO/d' /etc/motd
                if [ ! -e /root/.profile ]; then
                cat >/root/.profile <<-EOF
				export PS1="\u@\h:\w\# "
				echo_INFO="echo -e \033[0;36mINFO\033[0m"
				local_ip=\$(/etc/iSH-Tools/get_local_ip 2>/dev/null) || local_ip='<设备IP>'
				EOF
                source /root/.profile
                fi
                if ! grep -q "^\$echo_INFO.*${services}" /root/.profile; then
                    echo "\$echo_INFO $notes" >> /root/.profile
                fi
                printf_tips info "已经将${services}服务设置为自动启动" "\n"
            fi ;;
        del) clear
            rc-update del ${services_name}
            if [ $? = 0 ]; then
                sed -i "/^\$echo_INFO.*${services}/d" /root/.profile
                printf_tips info "已取消${services}服务自动启动" "\n"
            else
                printf_tips info "${services}服务尚未设置自动启动" "\n"
            fi ;;
    esac
    unset do && config_services_boot
}

########### Menu ###########
# 其他工具菜单
other_tools_menu() {
    local do_type=zsh services=ZSH apk_name=ohmyzsh
    enable_color=(0 0 0 0 1)
    menu_color=(0 0 0 0); menu_action=(0 0 0 0); do_service=("1"); pnum=18
    if [ -e "/etc/iSH-Tools/${services}_installed" ]; then
        menu_action+=("删除") menu_color+=($RED) do_service+=(2)
    else
        menu_action+=("安装") menu_color+=($GREEN) do_service+=(1)
    fi
    declare -A options=(
    [1]="CoreMark跑分:run_tools coremark"
    [2]="查询CPU指令集:run_tools cpuid2cpuflags"
    [3]="让iSH保持后台运行:background_running"
    [4]="ZSH和ohmyzsh:config_services ${do_service[1]}"
    )
    print_menu 1 4 返回主菜单 其他工具菜单
    case $chosen_option in
        q) clear && main_menu;;
    [1-4]) clear && ${options[$chosen_option]#*:};;
        *) error_tips 3;;
    esac
    other_tools_menu
}

# 管理镜像源菜单
manage_mirror_menu() {
    declare -A options=(
    [1]="更改镜像源:repo_mirrors_manager 1"
    [2]="备份源信息:repo_mirrors_manager 2"
    [3]="还原源信息:repo_mirrors_manager 3"
    [4]="恢复为iSH源:repo_mirrors_manager 4"
    )
    get_repo_status
    print_menu 2 4 返回主菜单 管理镜像源菜单
    case $chosen_option in
        q) clear && main_menu;;
    [1-4]) clear && ${options[$chosen_option]#*:};;
        *) error_tips 3 ;;
    esac
    manage_mirror_menu
}

# SSH配置菜单
config_ssh_menu() {
    local do_type=ssh services=SSH services_port=8022 services_name=sshd apk_name=openssh
    enable_color=(0 1 0 0)
    menu_color=(0); menu_action=(0); do_service=("1"); pnum=18
    if [ -e "/etc/iSH-Tools/${services}_installed" ]; then
        menu_action+=("删除") menu_color+=($RED) do_service+=(2) pmnum=3
    else
        menu_action+=("安装") menu_color+=($GREEN) do_service+=(1) pmnum=1
    fi
    declare -A options=(
    [1]="SSH服务:config_services ${do_service[1]}"
    [2]="更改root账户密码:change_root_password"
    [3]="管理SSH服务启动状态:config_services_boot"
    )
    print_menu 1 $pmnum 返回主菜单 SSH配置菜单
    [[ "$chosen_option" =~ ^[0-9]+$ ]] && [ "$chosen_option" -gt "$pmnum" ] && chosen_option=0
    case $chosen_option in
        q) unset apk_name; clear && main_menu;;
    [1-3]) clear && ${options[$chosen_option]#*:};;
        *) error_tips 3 ;;
    esac
    config_ssh_menu
}

# VNC配置菜单
config_vnc_menu() {
    local do_type=vnc services=VNC services_port=5900 services_name=x11vnc
    enable_color=(0 1 0 0)
    menu_color=(0); menu_action=(0); do_service=("1"); pnum=18
    if [ -e "/etc/iSH-Tools/${services}_installed" ]; then
        menu_action+=("删除") menu_color+=($RED) do_service+=(2) pmnum=4
    else
        menu_action+=("安装") menu_color+=($GREEN) do_service+=(1) pmnum=1
    fi
    declare -A options=(
    [1]="VNC服务和桌面环境:config_services ${do_service[1]}"
    [2]="更改使用的DE桌面环境:config_services 3"
    [3]="更改VNC分辨率:config_services 4"
    [4]="管理VNC服务启动状态:config_services_boot"
    )
    print_menu 1 $pmnum 返回主菜单 VNC配置菜单
    [[ "$chosen_option" =~ ^[0-9]+$ ]] && [ "$chosen_option" -gt "$pmnum" ] && chosen_option=0
    case $chosen_option in
        q) clear && main_menu ;;
    [1-4]) clear && ${options[$chosen_option]#*:} ;;
        *) error_tips 3 ;;
    esac
    config_vnc_menu 
}

# 主菜单
main_menu() {
    declare -A options=(
    [1]="配置VNC服务:config_vnc_menu"
    [2]="配置SSH服务:config_ssh_menu"
    [3]="管理镜像源:manage_mirror_menu"
    [4]="其他工具:other_tools_menu"
    [5]="更新脚本:update_script"
    )
    get_services_status
    print_menu 3 5 退出脚本 主菜单
	case $chosen_option in
        q) exit 0;;
    [1-5]) clear && ${options[$chosen_option]#*:};;
        *) error_tips 3 ;;
    esac
    main_menu
}

# 菜单循环打印显示函数
print_menu() {
    sleep 0.1
    local a1=$1 b1=$2
    printf "     %-15s ${YELLOW}%1s\t${PLAIN}\n" "iSH-Tools $tools_version" "$4"
    echo " ================================"
    if [[ $4 == "主菜单" ]]; then
        printf "| %-1d:${CYAN}%-16s   ${VNC_color}%-3s${PLAIN}/${x11vnc_color}%-3s${PLAIN} |\n" "1" "${options[1]%:*}" "${VNC_install}" "${x11vnc_status}"
        printf "| %-1d:${CYAN}%-16s   ${SSH_color}%-3s${PLAIN}/${sshd_color}%-3s${PLAIN} |\n" "2" "${options[2]%:*}" "${SSH_install}" "${sshd_status}"
        a1=1 b1=5
    fi
    if [[ $4 == "管理镜像源菜单" ]]; then
        case $repo_name in # 手动对齐菜单
            iSH源) pnum=19;; # 英文字符短一点
            *) pnum=18;; # 常见3字中文，如：未知源,清华源,默认源
        esac
        printf "| %-1d:${CYAN}%-${pnum}s当前使用:${repo_color}%-1s${PLAIN} |\n" "1" "${options[1]%:*}" "${repo_name}"
        a1=1 b1=4
        unset pnum
    fi

    for i in $(seq $1 $2); do
        case ${enable_color[$i]} in
            1) printf "| %-1d:${menu_color[$i]}%-1s${CYAN}%-${pnum}s\t${PLAIN} |\n" $i "${menu_action[$i]}" "${options[$i]%:*}" ;;
            *) printf "| %-1d:${CYAN}%-28s\t${PLAIN} |\n" $i "${options[$i]%:*}" ;;
        esac
    done
    unset enable_color chosen_option

    printf "| q:${PURPLE}%-28s\t${PLAIN} |\n" "$3"
    echo " ================================"
    printf '%-30s\n' "${ish_type}版本:${ish_ver}"
    if [[ "$ish_type" == "iSH-AOK" ]]; then
        printf_tips warning "检测为iSH-AOK版本，脚本尚未测试，请谨慎使用" "\n"
    elif [[ "$ish_type" == "unkown" ]]; then
        printf_tips warning "处于开发者模式，兼容运行在非iSH的Alpine环境下，请谨慎使用" "\n"
    fi
    [[ $4 == *"菜单"* ]] && read -p "[*]  请选择需要的功能 [$a1-$b1]:" chosen_option
}

########### Main ###########
ish_main $@

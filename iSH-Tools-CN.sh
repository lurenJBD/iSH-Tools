#!/bin/bash
# 镜像测速部分代码来自：https://github.com/lework/script/blob/master/shell/test/os_repo_speed_test.sh
# Os repo mirror site speed test. lework copyright
# coremark https://github.com/eembc/coremark
# cpuid2cpuflags https://github.com/projg2/cpuid2cpuflags
# coremark参考成绩来自：https://www.bilibili.com/read/cv21181867
# Moded by lurenJBD 2024.01.17
# iSH-Tools by lurenJBD 2020-10-17

########### Variable ###########
tools_version="3.3"
inite_repo="wget ncurses openrc bash"
HOST="baidu.com"
NAMESERVER="223.5.5.5"
github_url="https://github.com"
error_times=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
PLAIN='\033[0m'
echo_INFO="echo -e "${CYAN}INFO${PLAIN}""
echo_WARNING="echo -e "${YELLOW}WARNING${PLAIN}""
echo_ERROR="echo -e "${RED}ERROR${PLAIN}""

########### Function ###########

# 初始化脚本
init_run() {
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
    local init_check=1 && check_connection
    [[ $No_Network -eq 1 ]] && check_location
    # 第一次初始化脚本
    if [ ! -e /etc/iSH-Tools/tools_inited ];then
        mkdir -p /etc/iSH-Tools
        $echo_INFO 检测到第一次运行脚本，正在初始化
        [[ $No_Network -eq 1 ]] && $echo_ERROR 无网络连接，初始化失败，脚本自动退出 && exit 1
        timeout 30s apk add -q ${inite_repo}
        Timeout_or_not=$?
        if [ "$Timeout_or_not" = 143 ]; then
            $echo_WARNING 超过30s未完成安装，可能是源访问太慢，尝试使用镜像源安装 && init_run_WARNING=1
            rm -rf /etc/apk/repositories # 这里临时换源,不用删除/ish
            echo "http://mirrors.tuna.tsinghua.edu.cn/alpine/$alpine_version/main" >>/etc/apk/repositories
            echo "http://mirrors.tuna.tsinghua.edu.cn/alpine/$alpine_version/community" >>/etc/apk/repositories
            $echo_INFO 再次尝试安装所需的软件包
            apk update &>/dev/null
            apk add -q ${inite_repo}
            Timeout_or_not=$?
        fi
        if [ "$Timeout_or_not" = 0 ]; then
            sed -i "s#::sysinit:/sbin/openrc sysinit#::sysinit:/sbin/openrc#g" /etc/inittab
            echo inited_version=\"$tools_version\" >>/etc/iSH-Tools/tools_inited
            echo inited_repo=\"$inite_repo\" >>/etc/iSH-Tools/tools_inited
        fi
    fi
}

# 检查网络状况
check_connection() {
    ping -4 -c 1 -w 1 -A $HOST &>/dev/null &
    ping_pid=$!
    $echo_INFO 正在检查网络状况...
    wait $ping_pid
    if [ $? -ne 0 ]; then
        No_Network=1
        if [ "$init_check" = 1 ];then
            $echo_WARNING 网络连接异常，尝试更改DNS重新测试
            cp /etc/resolv.conf /etc/resolv.conf.bak
            echo "nameserver ${NAMESERVER}" > /etc/resolv.conf
            if ! ping_host; then
                mv /etc/resolv.conf.bak /etc/resolv.conf
                $echo_WARNING 网络连接异常，只能执行部分脚本功能
            else
                unset $No_Network
            fi
            init_run_WARNING=1
        fi
    fi
} 

# 检查所属地区，决定是否使用镜像站
check_location() {
    location_cf=$(wget -qO- https://cf-ns.com/cdn-cgi/trace | awk -F'=' '/^loc=/{print $2}')
	location_ipip=$(wget -qO- https://myip.ipip.net/ | awk -F '：' '{print $3}' | awk -F ' ' '{print $1}')
    if [[ "$location_cf" == "CN" || "$location_ipip" == "中国" ]]; then
        $echo_INFO "根据当前网络环境，建议更换镜像源并使用GitHub镜像站"
        read -p "[*] 是否要使用镜像源? [Y/N]" user_choice
        case $user_choice in
        [yY])
            github_url="https://ghproxy.com/https://github.com"
            REMOTE="https://ghproxy.com/https://github.com/ohmyzsh/ohmyzsh.git"
            rm -rf /etc/apk/repositories /ish
            echo "http://mirrors.tuna.tsinghua.edu.cn/alpine/$alpine_version/main" >>/etc/apk/repositories
            echo "http://mirrors.tuna.tsinghua.edu.cn/alpine/$alpine_version/community" >>/etc/apk/repositories
            ;;
        [nN]|*)
            $echo_INFO 已选择不使用镜像源，如果遇到访问缓慢可以使用脚本工具来更改
            ;;
        esac
    fi
}

# 使用说明
usage() {
    cat <<-EOF
	iSH-Tools $tools_version

	Usage: 
	    -cs , --change_sources | 一键镜像源测速&更换
	    -iv , --install_vnc    | 一键安装VNC服务和awesome桌面环境
	    -is , --install_sshd   | 一键安装SSH服务并设为自启动
	    -ot , --other_tools    | 其他工具
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
        mirrors_manager 1 ;;
    -iv | --install_vnc)
        quick=1 do_type=vnc services=VNC services_port=5900 services_name=x11vnc DE=1 && config_services 1;;
    -is  | --install_sshd)
        quick=1 do_type=ssh services=SSH services_port=22 services_name=sshd DE=3 && config_services 1;;
    *)
        while :; do
            main_menu
        done
        ;;
    esac
}

# 镜像源管理
mirrors_manager() {
    local repos_c="${YELLOW}repositories.bk${PLAIN}"
	local file_path="/alpine/v3.14/releases/x86/"
	local file_name="alpine-minirootfs-3.14.0-x86.tar.gz"
	local speed_test_log="/tmp/speed_test.log"
    # 镜像源列表
    declare -A mirrors=(
        [1]="官方源:http://dl-cdn.alpinelinux.org"
        [2]="交大源:https://mirrors.sjtug.sjtu.edu.cn"
        [3]="中科源:http://mirrors.ustc.edu.cn"
        [4]="兰大源:http://mirror.lzu.edu.cn"
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
        clear
        check_connection
        [[ $No_Network -eq 1 ]] && $echo_ERROR 无网络连接，无法进行优选 && return
        $echo_INFO "正在进行镜像源优选，会需要一些时间"
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
        mirror_url=$(head -n 1 $speed_test_log | cut -d ' ' -f2)
        mirror_name=$(head -n 1 $speed_test_log | cut -d ' ' -f1)
    }
	# 备份源文件
    backup_sources() {
        if [ ! -e /etc/apk/repositories.bk ]; then
            $echo_INFO "创建 ${repos_c} 备份"
            cp /etc/apk/repositories /etc/apk/repositories.bk
        else
            $echo_INFO "检测到 ${repos_c} 备份，是否要覆盖? [y/n]"
            read -n 1 user_choice
            case $user_choice in
            [yY])
                rm -f /etc/apk/repositories.bk
                cp /etc/apk/repositories /etc/apk/repositories.bk;;
            [nN]|*)
                $echo_INFO "不覆盖 ${repos_c} 备份";;
            esac
        fi
    }
	# 恢复源文件
    restore_sources(){
        if [ ! -e /etc/apk/repositories.bk ]; then
            $echo_INFO "没找到 ${repos_c} 备份文件，需要先备份才能恢复"
        else
            mv /etc/apk/repositories.bk /etc/apk/repositories
            $echo_INFO 已恢复源信息
        fi
    }
	# 更换源文件
    change_sources() {
        $echo_INFO "是否将 ${YELLOW}$2${PLAIN} 作为镜像源使用? [y/n]"
        read -n 1 user_choice
        case $user_choice in
        [yY])
            backup_sources
            rm -rf /etc/apk/repositories /ish
            echo "$1/alpine/$alpine_version/main" >>/etc/apk/repositories
            echo "$1/alpine/$alpine_version/community" >>/etc/apk/repositories
            $echo_INFO "正在更新源缓存"
            apk update -q
            $echo_INFO "源信息修改完成";;
        [nN]|*)
            clear && $echo_INFO "源信息未做更改\n" && sleep 0.5;;
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
            read  -p "请输入编号[0-11]:(输入 0 进行优选, q 返回上层)" mirror
            if [ "$mirror" = "q" ]; then
                return  
            elif [[ ! $mirror =~ ^[0-9]+$ ]]; then
                clear && $echo_ERROR "请输入正确的数字!"
            elif [ "$mirror" = 0 ]; then
                mirrors_speedtest
                [[ $No_Network -eq 1 ]] && return
                break
            elif [[ ! -v mirrors[$mirror] ]]; then
                clear && $echo_ERROR "输入的数字不在选项中，请重新输入！" && sleep 0.5
            else
                mirror_name="${mirrors[$mirror]%:h*}"
                mirror_url="${mirrors[$mirror]#*:}"
                break
            fi
        done
        change_sources $mirror_url $mirror_name
    }

    case $1 in
    1) select_sources;;
    2) restore_sources;;
    3) backup_sources;;
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
    if [ ! -e /etc/init.d/get_location ]; then
        cat >/etc/init.d/get_location <<-EOF
		#!/sbin/openrc-run
		name="get_location"
		description="get location to keep iSH running in the background"

		start() {
		        ebegin "Starting get_location"
		        start-stop-daemon -Sb -m -p /run/get_location.pid --exec cat -- /dev/location >/dev/null
		        eend $?
		}

		stop() {
		        ebegin "Stopping get_location"
		        start-stop-daemon -Kqp /run/get_location.pid
		        eend $?
		}
		EOF
        chmod +x /etc/init.d/get_location  
    fi
}

# 获取位置权限，用于保持后台运行
background_running() {
    if pgrep -f "cat /dev/location" >/dev/null; then
        $echo_INFO "iSH已经可以保持后台运行了"
        read -p "[*] 是否要取消保持后台运行? [Y/N]" user_choice
        case $user_choice in
            [yY])
                killall -TERM cat
                rc-service get_location stop 2>/dev/null
                rc-update del get_location 2>/dev/null ;;
            *) $echo_INFO "iSH会继续保持后台运行" ;;
        esac
    else
        local i=0
        cat /dev/location >/tmp/location.log &
        $echo_INFO "申请位置权限仅用于保持iSH后台运行"        
        $echo_INFO "请在iOS授权界面上点击 '使用App时允许'"
        while ((i < 15)); do
            if [ -s /tmp/location.log ]; then
                $echo_INFO "已赋予位置权限"
                killall -TERM cat && rm /tmp/location.log
                create_service
                rc-update add get_location 2>/dev/null
                rc-service get_location start 2>/dev/null
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
    $echo_INFO "正在更新iSH-Tools..."
    check_connection
    sh -c "$(wget -T15 -qO- ${github_url}/lurenJBD/iSH-Tools/raw/main/iSH-Tools-Setup-CN.sh)"
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

# 运行各种工具
run_tools() {
    local tools_dir="/etc/iSH-Tools/other_tools" tool=$1
    mkdir -p "$tools_dir"
    if [ ! -e "$tools_dir/$tool" ]; then
        $echo_WARNING "缺少"$tool"文件，从Github下载"
        check_connection
        [[ $No_Network -eq 1 ]] && $echo_ERROR "无网络连接，无法下载"$tool"" && return
        wget -T15 -qO ${tools_dir}/${tool} ${github_url}/lurenJBD/iSH-Tools/releases/download/Tools/${tool}
        chmod +x ${tools_dir}/${tool}
        ln -s ${tools_dir}/${tool} /usr/local/bin/${tool}
    fi
    case $tool in
    cpuid2cpuflags)
        cpuid2cpuflags | sed -n 's/^CPU_FLAGS_X86: //p' | awk '{printf "支持的指令集："; for(i=1;i<=NF;i++) printf "%s ", $i; printf "\n"}'
        ;;
    coremark)
        $echo_INFO "正在进行 coremark 性能测试，请稍等..."
        coremark | grep "CoreMark 1.0" | awk '{print strftime("%Y-%m-%d %H:%M:%S"), $4}' >> "$tools_dir/coreark_results.log"
        echo "本次成绩为: $(tail -n 1 "$tools_dir/coreark_results.log" | awk '{print $NF}')"
        echo -e "参考成绩\nJ1900(x86)   4核  34060\nMT7621(MIPS) 2核  4547\nN1(ARM)      4核  18404"
        $echo_INFO "历史成绩保存在$tools_dir/coreark_results.log"
        ;;
    esac
    sleep 0.5 && echo
}

# 修改Root账户密码
change_root_password() {
    $echo_INFO "正在修改root账户密码，Ctrl + C 取消修改"
    $echo_INFO "输入的密码是看不见的，需要输入两次"
    passwd root
    if [ $? = 0 ]; then
        $echo_INFO "修改root账户密码成功"
    else
        $echo_INFO "修改root账户密码失败"
    fi
}

# 配置服务(安装、删除或更改)
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
        [1]="awesome桌面"
        [2]="i3wm桌面"
        )
        print_menu 1 2 返回上层 选择桌面环境
        while :; do
            read -p "[*]  请选择想${ask_info}的桌面环境[1-2]:" apk_name
            if [[ $apk_name == 1 || $apk_name == 2 ]]; then
                break
            elif [[ $apk_name == "q" ]]; then
                break
            else
                error_tips 2
            fi
        done
        
    fi
    case "$apk_name" in
        1)
            apk_repo='awesome feh lua adwaita-gtk2-theme adwaita-icon-theme'
            apk_name='awesome'
            CMD='exec awesome'
            ;;
        2)
            apk_repo='i3wm i3wm-doc i3status i3status-doc i3lock i3lock-doc ttf-dejavu'
            apk_name='i3wm'
            CMD='exec i3'
            ;;
        openssh)
            apk_repo='openssh'
            ;;
        ohmyzsh)
            apk_repo='zsh git'
            ;;
        q) 
            clear
            config_vnc_menu
            ;;
    esac
    clear
    do_something_command $do_what
}

# 执行动作(安装、删除或更改)
do_something_command() {
    [ -e /etc/iSH-Tools/${services}_installed ] && source /etc/iSH-Tools/${services}_installed
    do_chance() {
        if [ "$apk_name" = "$installed_apk_name" ]; then
            $echo_WARNING "${apk_name}桌面环境已经安装，无需更换"
        elif [ ! -e /etc/iSH-Tools/${services}_installed ] ; then
            $echo_WARNING "未安装过${services}服务，请先安装"
        else
            do_del
            do_install
        fi
    }
    chance_vnc_resolution() {
        [ ! -e /etc/X11/xorg.conf.d/10-headless.conf ] && $echo_ERROR "没找到VNC服务配置文件，无法修改" && config_vnc_menu
        config_vnc_resolution
        sed -i "s#^           Modes.*#           Modes "$VL"#g" /etc/X11/xorg.conf.d/10-headless.conf
        $echo_INFO "VNC分辨率已修改为$VL" && config_vnc_menu
    }
    do_del() {
        if [ ! -e "/etc/iSH-Tools/${services}_installed" ] || [ "$apk_name" != "$installed_apk_name" ]; then
            $echo_WARNING "未安装过${services}服务" 
        else
            apk del -q ${installed_apk_repo}
            rm -rf ${rm_file} /etc/iSH-Tools/${services}_installed
            if [ "$do_type" = zsh ]; then
                sh ~/.oh-my-zsh/tools/uninstall.sh
                sed -i 's/\/bin\/zsh/\/bin\/ash/g' /etc/passwd
                $echo_INFO "已修改默认终端为ash，重启iSH App以查看效果"
            else
                rc-update del ${services_name}
                local notes="INFO ${services}服务已经启动，请用${services}客户端访问 <设备IP>:${services_port}"
                sed -i "/${notes}/d" /etc/motd
            fi
            $echo_INFO "已删除${apk_name}及配置文件"
        fi
    }
    do_install() {
        if [ -e "/etc/iSH-Tools/${services}_installed" ] || [ "$apk_name" = "$installed_apk_name" ]; then
            $echo_INFO "${services}服务已安装，无需重复安装"
        else
            check_connection
            [[ $No_Network -eq 1 ]] && $echo_ERROR "无网络连接，无法安装${services}服务" && return
            if [ "$do_type" = vnc ]; then
                [ ! -e /etc/X11/xorg.conf.d/10-headless.conf ] && config_vnc_resolution && clear
                xinit_vnc
                create_service
                vnc_de='xvfb x11vnc x11vnc-doc xorg-server xdpyinfo xdpyinfo-doc xf86-video-dummy xterm' rm_file='/root/.xinitrc'
            fi
            $echo_INFO "正在安装${services}服务和${apk_name}"
            apk update &>/dev/null
            timeout 150s apk add -q ${apk_repo} ${vnc_de}
            Timeout_or_not=$?
            if [ "$Timeout_or_not" = 143 ]; then
                $echo_WARNING 超过150s未完成安装，可能是源访问太慢，建议使用镜像源
                rm -rf /etc/apk/repositories # 这里临时换源,不用删除/ish
                echo "http://mirrors.tuna.tsinghua.edu.cn/alpine/$alpine_version/main" >>/etc/apk/repositories
                echo "http://mirrors.tuna.tsinghua.edu.cn/alpine/$alpine_version/community" >>/etc/apk/repositories
                $echo_INFO "再次尝试安装${services}服务和${apk_name}"
                apk update &>/dev/null
				apk add -q ${apk_repo} ${vnc_de}
                Timeout_or_not=$?
            fi
            if [ "$do_type" = ssh ]; then
                [ ! -e /etc/ssh/ssh_host_ed25519_key ] && $echo_INFO "正在生成SSH安全密匙" && ssh-keygen -A
                rm_file='/etc/ssh/sshd_config'
                echo 'root:alpine' | chpasswd
                sed -i "s/^#Port.*/Port 8022/g" /etc/ssh/sshd_config
                sed -i "s/^#PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config
                sed -i "s/^#ListenAddress.*/ListenAddress 0.0.0.0/g" /etc/ssh/sshd_config
                sed -i "s/^#PasswordAuthentication.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config
                read -p "[*] 是否需要让iSH保持后台运行?iPhone用户建议使用 [Y/N]" user_choice
                case $user_choice in
                [yY])
                    background_running ;;
                [nN]|*)
                    $echo_INFO 已选择不让iSH保持后台运行，如需更改请从'其他工具'里查看 ;;
                esac
                $echo_INFO "SSH登入信息:\n用户名: root\n密码: alpine"
            fi
            if [ "$do_type" = zsh ]; then
                BRANCH=master rm_file='/etc/iSH-Tools/ohmyzsh/tools/install.sh'
                if [ ! -e /etc/iSH-Tools/ohmyzsh/install.sh ]; then
                    git config --global http.postBuffer 524288000
                    git config --global pack.threads 1
                    mkdir -p /etc/iSH-Tools/ohmyzsh/
                    wget -T15 -qO /etc/iSH-Tools/ohmyzsh/install.sh ${github_url}/ohmyzsh/ohmyzsh/raw/master/tools/install.sh
                fi
                sh /etc/iSH-Tools/ohmyzsh/install.sh --unattended
                sed -i 's/\/bin\/ash/\/bin\/zsh/g' /etc/passwd
                $echo_INFO "已修改默认终端为zsh，重启iSH App以查看效果"
            fi
            if [ "$Timeout_or_not" = 0 ]; then
                echo installed_apk_name=\"$apk_name\" > "/etc/iSH-Tools/${services}_installed"
                echo installed_apk_repo=\"$apk_repo $vnc_de\" >> "/etc/iSH-Tools/${services}_installed"
                echo rm_file=\"$rm_file\" >> "/etc/iSH-Tools/${services}_installed"
                $echo_INFO "${services}服务安装成功"
            else
                $echo_ERROR "${services}服务安装失败"
            fi
        fi
    }
    case "$do_what" in
        1) do_install ;;
        2) do_del ;;
        3) do_chance ;;
        4) chance_vnc_resolution ;;
    esac
}

# 配置VNC分辨率
config_vnc_resolution() {
    local resolution vnc_resolution
    custom_vnc_resolution() {
        echo "请输入分辨率长度和高度，用'x'分隔(只取前4位数字):"
        read resolution
        if [[ $resolution =~ ^[0-9]{3,4}x[0-9]{3,4}$ ]]; then
            $echo_INFO "输入的分辨率为 $resolution,确认修改 [Y/N]"
            read var
            case $var in
                [yY]) VL="\"$resolution\"";;
                [nN]|*) 
                    $echo_INFO "重新选择VNC分辨率"
                    sleep 1 && config_vnc_resolution;;
            esac
        else
            $echo_WARNING "无效值，请重新输入！" && custom_vnc_resolution
        fi 
    }
    declare -A options=(
    [1]="1280x720  推荐iPhone使用"
    [2]="1024x768  推荐iPad使用"
    [3]="1280x1024 推荐iPad Pro使用"
    [4]="自定义分辨率"
    )
    clear
    print_menu 1 4 返回上层 配置VNC分辨率
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
    local notes="INFO ${services}服务已经启动，请用${services}客户端访问 <设备IP>:${services_port}"
    declare -A options=(
    [1]="立刻运行${services}服务"
    [2]="停止运行${services}服务"
    [3]="将${services}服务设为自启动"
    [4]="取消${services}服务的自启动"
    )
    print_menu 1 4 返回上层 ${services}服务管理菜单
    case $chosen_option in
        1) 
            clear
            rc-service ${services_name} start 2>/dev/null
            if [ $? = 0 ]; then
                $echo_INFO "${services}服务已启动\n请用${services}客户端连接 <设备IP>:${services_port} 以访问"
            else
                $echo_WARNING "${services}服务启动失败"
                $echo_INFO "因iSH存在BUG，首次安装${services}服务后需要重启iSH App才能正常启动"
            fi ;;
        2)  clear
            rc-service ${services_name} stop
            if [ $? = 0 ]; then
                $echo_INFO "${services}服务已停止"
            else
                $echo_WARNING "${services}服务停止失败"
                $echo_INFO "因iSH存在BUG，首次安装${services}服务后需要重启iSH App才能正常停止"
            fi ;;
        3)
            clear
            rc-update add ${services_name} default 2>/dev/null
            if [ $? = 0 ]; then
                if ! grep -q "$notes" /etc/motd; then
                    echo "$notes" >> /etc/motd
                fi
                $echo_INFO "已经将${services}服务设置为自动启动"
            fi ;;
        4)
            clear
            rc-update del ${services_name}
            if [ $? = 0 ]; then
                sed -i "/${notes}/d" /etc/motd
                $echo_INFO "已取消${services}服务自动启动"
            else
                $echo_INFO "${services}服务尚未设置自动启动"
            fi ;;
        q) clear && config_${do_type}_menu ;;
    esac
    config_services_boot
}

########### Menu ###########
# 其他工具菜单
other_tools_menu() {
    local do_type=zsh services=ZSH apk_name=ohmyzsh
    declare -A options=(
    [1]="CoreMark跑分:run_tools coremark"
    [2]="查询CPU指令集:run_tools cpuid2cpuflags"
    [3]="让iSH保持后台运行:background_running"
    [4]="安装ohmyzsh:config_services 1"
    [5]="删除ohmyzsh:config_services 2"
    )
    print_menu 1 5 返回主菜单 其他工具菜单
    case $chosen_option in
    q)
        clear && main_menu;;
    [1-5])
        clear && ${options[$chosen_option]#*:};;
    *) error_tips 3;;
    esac
    other_tools_menu
}

# 管理镜像源菜单
manage_mirror_menu() {
    declare -A options=(
    [1]="更改镜像源:mirrors_manager 1"
    [2]="备份镜像源信息:mirrors_manager 3"
    [3]="还原镜像源信息:mirrors_manager 2"
    )
    print_menu 1 3 返回主菜单 管理镜像源菜单
    case $chosen_option in
    q)
        clear && main_menu;;
    [1-3])
        clear && ${options[$chosen_option]#*:};;
    *) error_tips 3 ;;
    esac
    manage_mirror_menu
}

# SSH配置菜单
config_ssh_menu() {
    local do_type=ssh services=SSH services_port=8022 services_name=sshd apk_name=openssh
    declare -A options=(
    [1]="安装SSH服务:config_services 1"
    [2]="删除SSH服务:config_services 2"
    [3]="更改root账户密码:change_root_password"
    [4]="管理SSH服务启动状态:config_services_boot"
    )
    print_menu 1 4 返回主菜单 SSH配置菜单
    case $chosen_option in
        q) clear && main_menu;;
    [1-4])
            clear && ${options[$chosen_option]#*:};;
        *) error_tips 3 ;;
    esac
    config_ssh_menu
}

# VNC配置菜单
config_vnc_menu() {
    local do_type=vnc services=VNC services_port=5900 services_name=x11vnc
    declare -A options=(
    [1]="安装VNC服务和桌面环境:config_services 1"
    [2]="删除VNC服务和桌面环境:config_services 2"
    [3]="更改使用的DE桌面环境:config_services 3"
    [4]="更改VNC分辨率:config_services 4"
    [5]="管理VNC服务启动状态:config_services_boot"
    )
    print_menu 1 5 返回主菜单 VNC配置菜单
    case $chosen_option in
        q) clear && main_menu;;
    [1-5]) 
            clear
            ${options[$chosen_option]#*:}
            ;;
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
    q)
        exit 0;;
    [1-5])
        clear && ${options[$chosen_option]#*:};;
    *)
        error_tips 3;;
    esac
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
    for i in $(seq $1 $2); do
        printf "| %-1d:${CYAN}%-28s\t${PLAIN} |\n" $i "${options[$i]%:*}"
    done
    printf "| q:${PURPLE}%-28s\t${PLAIN} |\n" "$3"
    echo " ================================"
    printf '%-30s\n' "${ish_type}版本:${ish_ver}"
    if [[ "$ish_type" == "iSH-AOK" ]]; then
        $echo_WARNING 检测为iSH-AOK版本，脚本尚未测试，请谨慎使用
    fi
    [[ $4 == *"菜单"* ]] && read -p "[*]  请选择需要的功能 [$a1-$b1]:" chosen_option
}

########### Main ###########
if [[ "$1" != *"-h"* ]]; then
	init_run && [[ $init_run_WARNING -ne 1 ]] && clear
fi
ish_main $@

#!/bin/bash
#
# Os repo mirror site speed test. lework copyright 
# 原文件 https://github.com/lework/script/blob/master/shell/test/os_repo_speed_test.sh
# Moded by lurenJBD 2023.02.24

########### Variable ###########
Version="3.0.0"
HOST="baidu.com"  
speed_test_log="/tmp/speed_test.log"
file_path="/alpine/v3.14/releases/x86/alpine-minirootfs-3.14.0-x86.tar.gz"
file_name="alpine-minirootfs-3.14.0-x86.tar.gz"
error_times=0

# 终端颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
PLAIN='\033[0m'
# 镜像源列表
declare -A mirrors
mirrors=(
  [官方源]="http://dl-cdn.alpinelinux.org"
  [交大源]="https://mirrors.sjtug.sjtu.edu.cn"
  [中科源]="http://mirrors.ustc.edu.cn"
  [兰大源]="http://mirror.lzu.edu.cn"
  [南大源]="http://mirrors.nju.edu.cn"
  [北外源]="https://mirrors.bfsu.edu.cn"
  [东软源]="http://mirrors.neusoft.edu.cn"
  [清华源]="http://mirrors.tuna.tsinghua.edu.cn"
  [华为源]="http://repo.huaweicloud.com"
  [腾讯源]="http://mirrors.cloud.tencent.com"
  [阿里源]="http://mirrors.aliyun.com"
)

########### Function ###########
# 检查网络
function network_test() {
    ping -4 -c 1 -w 1 -A $HOST &>/dev/null || {
    echo "WARNING 网络连接异常，尝试改为阿里DNS后重新测试"
    echo "nameserver 223.5.5.5" > /etc/resolv.conf
    ping -4 -c 1 -w 1 -A $HOST &>/dev/null || ( echo "WARNING 网络连接异常，离线下只能执行脚本部分功能" ) && network_err=1
    }
}

# 第一次运行脚本,初始化
function first_run() { 
    if [ ! -e /opt/iSH-VNC ];then
        echo "INFO 检测到第一次运行本脚本，正在进行初始化"
        [ "$network_err" = 1 ] && echo "${RED}ERROR 网络错误，无法进行初始化，脚本无法正常运行，自动退出${PLAIN}" && exit 1
        mkdir -p /opt/iSH-VNC
        apk info -e wget ncurses openrc &>/dev/null || apk add -q wget ncurses openrc
        if [ -z "$(command -v openrc)" ];then
        apk add -q openrc
        sed -i "s#::sysinit:/sbin/openrc sysinit#::sysinit:/sbin/openrc#g" /etc/inittab
        fi
    fi
}

# 镜像源测速旋转动画
function spinner() {
  local LC_CTYPE=C
  rm $speed_test_log 2> /dev/null
  touch $speed_test_log
  test_mirror "$@" &
  sleep 1
  local pid=$(ps -ef | grep -E '[w]get.*-4O /dev/null -T120' | awk '{print $1}')
  local spin='-\|/'
  local i=0
  tput civis
  while kill -0 $pid 2>/dev/null; do
    local i=$(((i + 1) % ${#spin}))
    printf "\r%s" "${spin:$i:1}"
    echo -en "\033[1D"
    sleep .1
  done
  tput cnorm
  wait
}
# 测速主要功能
function test_mirror() {
    local output=$(LANG=C wget ${3:+"--header="}"$3" -4O /dev/null -T120 "$1" 2>&1)
    local speed=$(printf '%s' "$output" | awk '/\/dev\/null/ {speed=$3 $4} END {gsub(/\(|\)/,"",speed); print speed}')
    local ipaddress=$(printf '%s' "$output" | awk -F'|' '/Connecting to .*\|([^\|]+)\|/ {print $2}'| tail -1)
    local time=$(printf '%s' "$output" | awk -F= '/100% / {print $2}')
    local size=$(printf '%s' "$output" | awk '/Length:/ {s=$3} END {gsub(/\(|\)/,"",s); print s}')
    [ -z "$speed" ] && local speed=0KB/s
    [ -z "$ipaddress" ] && local ipaddress=null time=null size=null
    printf "${YELLOW}%-17s${GREEN}%-16s${BLUE}%-12s${PLAIN}%-11s${RED}%-10s${PLAIN}\n" "$2" "${ipaddress}" "${size}" "${time}" "${speed}" 
    speed=$(echo "$speed" | awk '{if ($0 ~ /MB\/s/) printf "%.0fKB/s", $1*1024; else print}')
    echo "${mirror} ${mirrors[$mirror]} $speed" >> $speed_test_log
}

# 备份源文件
function backup_sources() {
    if [ ! -e /etc/apk/repositories.bk ]; then
        echo "INFO 创建 repositories.bk 备份"
        mv /etc/apk/repositories /etc/apk/repositories.bk
    else
        while :; do
        read -n 1 -p "INFO 检测到 repositories.bk 备份，是否要覆盖? [y/n]" var
        case $var in
            [yY])
                rm -f /etc/apk/repositories.bk
                mv /etc/apk/repositories /etc/apk/repositories.bk
                break;;
            [nN])
                echo "INFO 不覆盖 repositories.bk 备份"
                break;;
            *)
                error_type=1 && error_tips;;
        esac
        done
    fi
}
# 更换源文件
function change_sources(){
    sort -k 3 -n -r -o $speed_test_log $speed_test_log
    fastest_mirror=`head -n 1 $speed_test_log | cut -d ' ' -f2`
    fastest_mirror_name=`head -n 1 $speed_test_log | cut -d ' ' -f1`
    while :; do
    echo -e "INFO ${YELLOW}$fastest_mirror_name${PLAIN}下载速度最快，是否要替换? [y/n]"
    read -n 1 var
    case $var in
        [yY])
            backup_sources
            rm -f /etc/apk/repositories
            echo "$fastest_mirror/alpine/$version/main" >> /etc/apk/repositories
            echo "$fastest_mirror/alpine/$version/community" >> /etc/apk/repositories
            apk update -q
            echo "INFO 修改镜像源成功"
            break;;
        [nN])
            echo "INFO 源信息未做更改"
            break;;
        *)
           error_type=1 && error_tips;; 
    esac
    done
}
# 检查Alpine版本
detect_version(){
    ver=`cat /etc/alpine-release | awk -F "." '{print $1}'`
    if [ $ver = 3 ]; then
        ver=`cat /etc/alpine-release | awk -F "." '{print $2}'`
        version=v3."$ver"
    else
        echo "WARNING  未知的Alpine版本，换源后可能会出现问题，停止换源"
        exit 0
    fi
}

# 错误提醒与终止
function error_tips() {
    clear
    case $error_type in
        1)
        echo -e "\n${RED}WARNING: 只能输入 [Y/N]${PLAIN}";;
        2)
        echo -e "\n${RED}WARNING: 请检查输入内容是否有误?${PLAIN}";;
    esac
    error_times=$((error_times+1))
    if [ $error_times -ge 10 ]; then
        echo -e "\n${RED}ERROR: 已累计出现$error_times次错误，脚本已退出${PLAIN}"
        exit 1
    fi
    unset error_type var
}

function shutdown() {
    tput cnorm
    echo "INFO 感谢使用本脚本 by 路人去甲剩丙丁"
}

trap shutdown EXIT

#管理桌面环境，进行安装、删除或更改
function manager_de() {
    while :; do
        [ "$install_DE" = 1 ] && local do_install_DE=1 && read -t 15 -p "*  请选择想安装的桌面环境 15秒后自动选择'awesome' [awesome|i3wm]:" var || var=awesome && echo
        [ "$chance_DE" = 1 ] && local do_chance_DE=1 && read -p "*  更改桌面环境为 [awesome|i3]:" var
        [ "$del_DE" = 1 ] && local do_del_DE=1 && read -p "*  请选择想删除的桌面环境 [awesome|i3]:" var
        case ${var} in
            [aA][wW][eE][sS][oO][mM][eE])
                DE='awesome feh lua adwaita-gtk2-theme adwaita-icon-theme'
                DE_name='awesome'
                CMD='exec awesome'
                break;;
            [iI][3][wW][mM])
                DE='i3wm i3wm-doc i3status i3status-doc i3lock i3lock-doc ttf-dejavu'
                DE_name='i3wm'
                CMD='exec i3'
                break;;
            *)
                error_type=2 && error_tips;;
        esac
    done
    if [ "$do_del_DE" = 1 ]; then
        apk del -q ${DE}
        rm /root/.xinitrc
        echo "INFO 已删除${DE_name}桌面环境及配置文件"
    fi
    if [ "$do_chance_DE" = 1 ]; then
        source /opt/iSH-VNC/VNC_installed
        source /opt/iSH-VNC/VNC_installed_name
        do_install_DE=1
        apk del -q ${installed_DE}
        rm /root/.xinitrc
        echo "INFO 已删除${installed_DE_name}桌面环境及配置文件"
    fi
    if [ "$do_install_DE" = 1 ]; then
        if [ -z "$(command -v $DE_name)" ]; then
            echo "INFO 正在安装${DE_name}桌面环境"
            apk add -q xvfb x11vnc x11vnc-doc xorg-server xdpyinfo xdpyinfo-doc xf86-video-dummy xterm ${DE}
            echo installed_DE=$DE > /opt/iSH-VNC/VNC_installed
            echo installed_DE_name=$DE_name > /opt/iSH-VNC/VNC_installed_name
            xinit_vnc
        else
            echo "INFO 检测到${DE_name}桌面环境已安装，无需重复安装"
        fi
    fi
}

#X-org配置初始化
function xinit_vnc() {
[ ! -e /etc/X11/xorg.conf.d ] && mkdir -p /etc/X11/xorg.conf.d
if [ ! -e /etc/X11/xorg.conf.d/10-headless.conf ]; then
cat > /etc/X11/xorg.conf.d/10-headless.conf  << EOF
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
cat > /root/.xinitrc << EOF
xrdb -merge ~/.Xresources
EOF
fi
if [ "$CMD" = "exec i3" ]; then
echo "xterm -geometry 80x50+494+51 &" >>/root/.xinitrc
echo "xterm -geometry 80x20+494-0 &" >>/root/.xinitrc
fi
echo "${CMD}" >>/root/.xinitrc
if [ ! -e /root/.Xresources ]; then
cat > /root/.Xresources << EOF
Xft.dpi: 264
xterm*VT100.Translations: #override \
    Ctrl <Key> minus: smaller-vt-font() \n\
    Ctrl <Key> plus: larger-vt-font() \n\
    Ctrl <Key> 0: set-vt-font(d)
EOF
fi
}

#配置VNC分辨率
vnc_resolution() {
    while :; do
        echo " ============================================="
        echo " iPhone 推荐分辨率1280x720 选1"
        echo " iPad 推荐分辨率1024x768 选2"
        echo " iPad Pro 推荐分辨率1280x1024 选3"
        echo " 任意其他字符进入自定义"
        echo " ============================================="
        if [ "$install_DE" = 1 ]; then
            read -t 10 -p "*  请选择分辨率 [1/2/3] 10秒后自动选择'2':" var || var=2 && echo
        else
            read -p "* 请选择分辨率 [1/2/3]:" var
        fi
        case $var in
            1) VL='"1280x720"'
                break;;
            2) VL='"1024x768"'
                break;;
            3) VL='"1280x1024"'
                break;;
            *)
                while :; do
                echo "
INFO 使用自定义VNC分辨率
=======================
| iPad设备常见分辨率
| 2048x1536 (9.7/7.9寸)
| 2160x1620 (10.2寸)
| 2224x1668 (10.5寸)
| 2360x1640 (10.9寸)
| 2388x1668 (11寸)
| 2732x2048 (12.9寸)
======================="
                read -p "*  请输入分辨率长度和高度，用'x'分隔(只取前4位数字):" resolution
                if [[ $resolution =~ ^[0-9]{3,4}x[0-9]{3,4}$ ]]; then
                    echo "INFO 输入的分辨率为 $resolution"
                    while :; do
                        read -p "* 确认修改内容正确 [Y/N] " var
                        case $var in
                            [yY])
                                VL="\"$resolution\""
                                break;;
                            [nN])
                                echo "INFO 重新选择VNC分辨率"
                                break;;
                            *)
                                error_type=1 && error_tips;;
                        esac    
                    done
                    break
                else
                    echo "WARNING 无效值，请重新输入！"
                fi
                done
                break;;
        esac
    done
    echo "INFO VNC分辨率已设为$VL"
}


#创建服务启动文件
create_initd() {
if [ ! -e /etc/init.d/x11vnc ]; then
cat >/etc/init.d/x11vnc << EOF
#!/sbin/openrc-run
name="x11vnc"
description="x11vnc is a Virtual Network Computing server program to access X Windows desktop session"

start_pre() {
        if ! pidof xinit >/dev/null; then
            rc-service xinit start
            sleep 5
        fi
}

start() {
        ebegin "Starting x11vnc"
        start-stop-daemon -Sbmp /run/x11vnc.pid --exec x11vnc -- -xkb -noxrecord -noxfixes -noxdamage -display :0 -noshm -nopw -forever
        eend \$?
}

stop() {
        ebegin "Stopping x11vnc"
        start-stop-daemon -Kqp /run/x11vnc.pid
        eend \$?
        rc-service xinit stop
} 
EOF
chmod +x /etc/init.d/x11vnc
fi
if [ ! -e /etc/init.d/xinit ]; then
cat >/etc/init.d/xinit << EOF
#!/sbin/openrc-run
name="xinit"
description="xinit starts the X Window System server"

start() {
        ebegin "Starting xinit"
        start-stop-daemon -Sbmp /run/xinit.pid --exec xinit -- X :0
        eend \$?
}

stop() {
        ebegin "Stopping xinit"
        start-stop-daemon -Kqp /run/xinit.pid
        eend \$?
}
EOF
chmod +x /etc/init.d/xinit
fi
}

#iSH获取位置权限
get_localtion () {
    echo "
==========================================
| INFO 申请位置权限用于保持iSH后台运行
| INFO iPhone需要保持后台，iPad可用分屏模式
=========================================="            
    ex=0
    while [ $ex = 0 ]; do
        read -t 5 -n 1 -p "*  是否需要保持后台运行 5秒后自动选择 'N' [Y/N]: " var
        echo
        if [ -z "$var" ]; then
            echo "INFO 选择超时，自动选择'N'"
            var=n
        fi
        case $var in
            [yY])
                cat /dev/location >/tmp/location.log &
                echo "INFO 请在iOS授权界面上点击 '使用App时允许'"
                sleep 5
                if [ -s /tmp/location.log ]; then
                    echo "INFO 已赋予位置权限"
                    break
                else
                    echo "INFO 无法获取位置权限，iSH无法保持后台运行"
                    echo "INFO 这可能是赋权超时误判，请到设置中手动赋予权限"
                    break
                fi
                killall cat /dev/location &>/tmp/location.log
                rm /tmp/location.log
                cat /dev/location >/dev/null &;;
            [nN])
                echo "INFO 不保持后台运行"
                break;;
            *)
                error_type=1 && error_tips;;
        esac
    done
}

#询问是否立刻运行服务
run_service () {
        while :; do
        read -t 5 -p "*  是否立刻运行$service 5秒后自动选择'N' [Y/N]:" var
        echo
        if [ -z "$var" ]; then
            echo "INFO 选择超时，自动选择'N'"
            var=n
        fi
        case $var in
            [yY])
                rc-service x11vnc start
                echo "INFO rc-service x11vnc status 查看服务状态"
                echo "INFO 可以打开VNC软件，连接 127.0.0.1:5900 以访问"
                echo "INFO 如果没法访问，请尝试关闭iSH重启App"
                echo "INFO 接着手动输入 rc-service x11vnc start 启动VNC"
                break;;
            [nN])
                echo "INFO $info"
                break;;
            *)
                error_type=1 && error_tips;;
        esac
        done
}


########### Main ###########
network_test
first_run
clear
while :; do
echo "
    iSH-VNC 服务管理脚本 $Version
 ===============================
|  1：安装VNC服务和桌面环境     |
|  2：卸载VNC服务和桌面环境     |
|  3：安装SSH服务               |
|  4：修改相关配置              |
|  5：将脚本复制到bin           |
|  q：退出脚本                  |
|  Made by 路人去甲剩丙丁       |
 ===============================
*  请选择需要的功能 [1-5]："
read -n 1 var
case $var in
    1)
        clear
        echo "INFO 更新源中..."
        apk update &>/dev/null
        install_DE=1
        manager_de
        vnc_resolution
        create_initd
        PID=`pgrep -f 'cat /dev/location'`
        if [ -z "$PID" ]; then
            get_localtion
        fi
        echo "INFO VNC服务和桌面环境安装完成"
        info="输入 rc-service x11vnc start 启动VNC服务和桌面环境"
        service="VNC服务和桌面环境"
        run_service   
        break;;
    2)
        clear
        del_DE=1
        manager_de
        break;;
    3)
        clear
        echo "INFO 更新源中..."
        apk update &>/dev/null
        if [ -z "$(command -v sshd)" ]; then
            echo "INFO 正在安装SSH服务"
            apk add -q openssh
            if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
            echo "INFO 生成SSH安全密匙中"
            ssh-keygen -A
            fi
            echo 'root:alpine' | chpasswd
            sed -i "s/#Port.*/Port 22/g" /etc/ssh/sshd_config
            sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config
            echo "INFO SSH服务安装完成"
            echo "
NOTE SSH登入信息：用户 root，密码 alpine
NOTE 如需手动修改密码，输入 passwd root，接着输入密码即可
NOTE 注意：输入密码在屏幕上是无显示的"
            rc-update add sshd sysinit
            echo "SSH服务已经安装，并自动启动，请用SSH客户端访问 设备IP:22端口" >> /etc/motd
            echo "INFO 已经将SSH服务设置为自动启动"
            echo "INFO 因openrc有bug，第一次安装后需重启iSH，SSH服务会自己启动"
        else
            echo "INFO 检测到SSH服务已安装，无需重复安装"
        fi
        rc-service sshd start
        echo "INFO SSH服务已启动"
        echo "INFO 使用 rc-status --list | grep sshd 来查看服务是否已启动"
        break;;
    4)
        clear
        while :; do
        echo "
 ========================
| 1：更改VNC分辨率 
| 2：更改使用的桌面环境 
| 3：镜像源测速
| q：返回主菜单 
 ========================
*  请选择想运行的功能:"
        read -n 1 var
        case $var in
            1)
                [ ! -e /opt/iSH-VNC/VNC_installed ] && echo "INFO 似乎没安装过VNC服务，请先安装VNC服务和桌面环境" && break
                vnc_resolution
                sed -i "s#^           Modes.*#           Modes "$VL"#g" /etc/X11/xorg.conf.d/10-headless.conf
                echo "INFO VNC分辨率已修改"
                break;;
            2)
                [ ! -e /opt/iSH-VNC/VNC_installed ] && echo "INFO 似乎没安装过VNC服务，请先安装VNC服务和桌面环境" && break
                chance_DE=1 && manager_de
                echo "INFO 桌面环境已改为$DEP"
                break;;
            3)
                detect_version
                clear
                echo "INFO 正在进行镜像源测速，可能会需要较长的时间"
                echo -e "\n[镜像站点]"
                for mirror in ${!mirrors[*]}; do
                    printf "${PLAIN}%-3s${GREEN}%-3s${PLAIN}\n" ${mirror} ":  ${mirrors[$mirror]}"
                done
                echo -e "\n[测试信息]"
                echo -e "系统信息  : ${YELLOW}Alpine ${version}${PLAIN}"
                echo -e "下载文件  : ${YELLOW}${file_name}${PLAIN}"
                echo
                printf "%-19s%-17s%-16s%-16s%-10s\n" "镜像站名称" "IPv4 地址" "文件大小" "下载用时" "下载速度"
                for mirror in ${!mirrors[*]}; do
                    spinner "${mirrors[$mirror]}${file_path}" ${mirror}
                done
                change_sources
                break;;
            [qQ]) 
                clear
                echo "INFO 返回主菜单"
                break;;
            
            *)
                error_type=2 && error_tips;;
        esac
        done;;
    5)
        clear
        echo "INFO 正在将脚本复制到'/usr/local/bin'"
        cp $pwd/iSH-VNC.sh /usr/local/bin/iSH-VNC || wget https://github.com/lurenJBD/iSH-VNC/raw/main/iSH-VNC_CN.sh -qO /usr/local/bin/iSH-VNC
        chmod +x /usr/local/bin/iSH-VNC
        echo "INFO 复制完成，输入 iSH-VNC 即可运行本脚本"
        break;;
    [qQ]) 
        clear
        echo "INFO 退出iSH VNC服务管理脚本"
        break;;
    *)
        error_type=2 && error_tips;;
esac
done

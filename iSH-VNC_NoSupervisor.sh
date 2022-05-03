#!c:\git\bin\bash
HOST="baidu.com" 
MIRRORS_FILE="mirrors.list"   
SPEED_LOG="speed.list"
THX='感谢使用本脚本 by 路人去甲剩丙丁'

#检查网络
network_test (){
    ping -4 -c 1 -w 1 -A $HOST &>/dev/null || {
    echo "WARNING 网络连接异常，尝试改为阿里DNS后重新测试"
    echo "nameserver 223.5.5.5" > /etc/resolv.conf
    ping -4 -c 1 -w 1 -A $HOST &>/dev/null || ( echo"WARNING 网络连接异常，离线下只能执行脚本部分功能" )
    }
}

#更换源，访问速度检测（争取下次更新修正只用Ping来决定的bug）
ping_speed (){
    speed=`ping -4 -c 5 -w 5 -A $1 | grep 'avg' | cut -d '/' -f4`
    echo $speed
}

test_mirror(){
    rm $SPEED_LOG 2> /dev/null; touch $SPEED_LOG
    cat $MIRRORS_FILE | while read mirror; do
    if [ "$mirror" != "" ]; then
        mirror_host=`echo $mirror | cut -d '/' -f3`
        echo "Ping $mirror_host"
        speed=$(ping_speed $mirror_host)
        if [ "$speed" != "" ]; then
            echo "平均延迟为 $speed ms"
            echo "$mirror $speed" >> $SPEED_LOG
        else
            echo "WARNING 网络连接错误"
        fi
    fi
    done
}

get_fast_mirror(){
    sort -k 2 -n -o $SPEED_LOG $SPEED_LOG
    fast_mirror=`head -n 1 $SPEED_LOG | cut -d ' ' -f1`
    echo $fast_mirror
}

backup_sources(){
    echo "INFO 备份源内容到repositories.backup"
    mv /etc/apk/repositories /etc/apk/repositories.backup
}

update_sources(){
    mirror="$1"
    tmp=$(mktemp)
    detect_version
    echo "$mirror/alpine/$version/main" >> $tmp
    echo "$mirror/alpine/$version/community" >> $tmp
    mv "$tmp" /etc/apk/repositories
    echo "INFO 替换镜像源成功，输入apk update更新源"
}

detect_version(){
    ver=`cat /etc/alpine-release | awk -F "." '{print $1}'`
    if [ $ver = 3 ]; then
        ver=`cat /etc/alpine-release | awk -F "." '{print $2}'`
        case $ver in
           11)
            version=v3.11;;
           12)
            version=v3.12;;
           13)
            version=v3.13;;
           14)
            version=v3.14;;
            *)
            version=v3.12;;
        esac
    else
        echo "WARNING  未知的Alpine版本，换源后可能会出现问题，停止换源"
        exit 0
    fi
}

create_mirror_list(){
    cat >$MIRRORS_FILE <<EOF
http://mirrors.tuna.tsinghua.edu.cn
http://mirrors.aliyun.com
http://mirrors.ustc.edu.cn
http://dl-cdn.alpinelinux.org
EOF
}

change_sources(){
    test -f $MIRRORS_FILE
    if [ $? != "0" ]; then
        create_mirror_list
    fi
    echo "INFO 自动选择Ping延迟低的镜像源"
    test_mirror
    fast_mirror=$(get_fast_mirror)
    fast=`echo $fast_mirror | cut -d '/' -f3`
    echo "$fast访问延迟最低，是否要替换该镜像源？[y/n]"   
    read -n 1 var
    case $var in
        [yY]|"")
            backup_sources
            update_sources $fast_mirror
            ex=1
            ;;
        [nN]|*)
            echo "INFO 源信息未做更改"
            ex=1
            ;;
    esac
}

#安装或删除桌面环境
install_vnc() {
unset var
while :; do
    if [ $first = 1 ]; then
        read -t 15 -p "*  请选择想安装的桌面环境 15秒后默认选择'awesome' [xfce|awesome|i3]" var
        echo $var
        if [ $var = "" ]; then
            echo "INFO 选择超时，默认选择'awesome'"
            var=awesome
        fi
        else
        if [ $del = 1 ]; then
            read -p "*  请选择想删除的桌面环境 [xfce|awesome|i3] :" var
            else
            read -p "*  更改桌面环境为 [xfce|awesome|i3]" var
        fi
    fi
    case $var in
        [xX][fF][cC][eE]) 
            DE='xfce4 xfce4-terminal faenza-icon-theme lightdm-gtk-greeter dbus'
            CMD='exec startxfce4'
            DEP='xfce4'
            break
            ;;
        [aA][wW][eE][sS][oO][mM][eE]|"")
            DE='awesome feh xterm lua adwaita-gtk2-theme adwaita-icon-theme'
            CMD='exec awesome'
            DEP='awesome'
            break
            ;;
        [iI][33]|[i3wm])
            DE='i3wm xterm i3status i3lock ttf-dejavu'
            CMD='exec i3'
            DEP='i3wm'
            break
            ;;
        *)
            echo -e "\033[31mWARNING  请检查输入内容是否有误?\033[0m"
            unset var
            continue
            ;;
    esac
done
if [ $del = 1 ];then
    apk del -q ${DE}
    rm /usr/local/bin/openvnc
    echo "INFO 已删除${DEP}桌面环境及配置文件"
    echo "INFO $THX"
    else
    if [ -z "$(command -v $DEP)" ];then
        echo "INFO 正在安装${DEP}桌面环境"
        apk add -q xvfb x11vnc xorg-server xdpyinfo xf86-video-dummy ${DE} openrc nano
        else
        echo "INFO 检测到${DEP}桌面环境已安装，不再重复安装"
    fi
fi
}

#X-org初始化配置
xinit_vnc() {
if [ ! -e /etc/X11/xorg.conf.d ]; then
   mkdir -p /etc/X11/xorg.conf.d # If it doesn't exist, create it.
fi
if [ ! -e /etc/X11/xorg.conf.d/10-headless.conf ]; then
cat > /etc/X11/xorg.conf.d/10-headless.conf << EOF
Section "Monitor"
        Identifier "dummy_monitor"
        HorizSync 28.0-80.0
        VertRefresh 48.0-75.0
        DisplaySize  250 174    # In millimeters, iPad gen 7 & 8
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
           Modes "${VL}"
        EndSubSection
EndSection
EOF
fi
if [ ! -e /root/i3logs ]; then
   mkdir /root/i3logs
fi
if [ ! -e /root/.xinitrc ]; then
cat > /root/.xinitrc << EOF
xrdb -merge ~/.Xresources
xterm -geometry 80x50+494+51 &
xterm -geometry 80x20+494-0 &
${CMD}
EOF
fi
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

#VNC分辨率配置
vnc_resolution() {
ex=0;unset var
while [ $ex = 0 ]; do
echo " ============================================="
echo " iPhone 推荐分辨率1280x720 选1"
echo " iPad 推荐分辨率1024x768 选2"
echo " iPad Pro 推荐分辨率1280x1024 选3"
echo " 任意其他字符进入自定义"
echo " ============================================="
if [ $first = 1 ]; then
    read -t 10 -p "*  请选择分辨率 [1/2/3] 10秒后默认选择'2':" var
    echo $var
    if [ $var = "" ]; then
        echo "INFO 选择超时，默认选择'2'"
        var=2              
    fi 
    else
    read -p "* 请选择分辨率 [1/2/3]:" var
fi
case $var in
    1)
        VL='1280x720'
        break
        ;;
    2|"")
        VL='1024x768'
        break
        ;;
    3)
        VL='1280x1024'
        break
        ;;    
    *)
        unset var
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
        while :; do
        read -p "*  请输入分辨率长度(只取前4位数字):" num1
            expr ${num1:0:4} + 1 &>/dev/null
            if [ $? -eq 0 ];then
                    if [ ${num1:0:4} -lt 99 ];then
                    echo "WARNING 输入数值小于3位，请重新输入！"
                    continue
                else
                    echo "INFO 输入的长度为${num1:0:4}"
                    break
                fi
            else
                echo "WARNING 非法字符，请重新输入！"
                continue
            fi
        done                
        while :; do
        read -p "*  请输入分辨率高度(只取前4位数字):" num2
            expr ${num2:0:4} + 1 &>/dev/null
            if [ $? -eq 0 ];then
                if [ ${num2:0:4} -lt 99 ];then
                    echo "WARNING 输入数值小于3位数，请重新输入！"
                    continue
                else
                    echo "INFO 输入的高度为${num2:0:4}"
                    break
                fi
            else
                echo "WARNING 非法字符，请重新输入！"
                continue
            fi
        done
        echo "INFO 输入的分辨率为 ${num1:0:4}x${num2:0:4}"
        while :; do
        read -p "* 确认修改内容正确 [Y/N] " var
            case $var in
                [yY])
                    VL="${num1:0:4}x${num2:0:4}"
                    ex=1
                    break
                    ;;
                [nN])
                    echo "INFO 重新选择VNC分辨率"
                    break
                    ;;
                *)
                    clear
                    yn_error
                    continue
                    ;;
            esac    
        done
        ;;
esac
done
if [ -n "$VL" ]; then
echo "INFO VNC分辨率已设为$VL"
fi
}

yn_error (){
    echo -e "\033[31mWARNING 只能输入 [Y/N]\033[0m"
}

#创建VNC的启动文件
create_openvnc() {
if [ ! -e /usr/local/bin/openvnc ]; then
cat >/usr/local/bin/openvnc << EOF
#!/bin/ash
#
# Stupidly simple script to start vnc.  

CHECK=`ps -o args | grep "{startx} /bin/sh /usr/bin/startx" | wc -l`

# Only run once.  The grep causes CHECK to equal 1
if [ $CHECK -eq 1 ]; then # Nothing running, clear stale locks
   rm -rf /tmp/.X* 
else
   echo "$0 is already running.  We're done here."
   exit 1
fi

# See if location services are running already.  
# Having them running reduces the odds of iSH getting
# killed while in the background.
CHECK=`ps -o args | grep "cat /dev/location" | wc -l`

# Only run once.  The grep causes CHECK to equal 1
if [ $CHECK -eq 1 ]; then
   cat /dev/location > /dev/null &
fi

startx &
x11vnc -display :0 -noshm -nopw -forever & 
EOF
chmod +x /usr/local/bin/openvnc
fi
}

#创建SSH的Supervisor配置
create_ssh_ini() {
if [ ! -e /etc/supervisor.d ]; then
mkdir -p /etc/supervisor.d/
fi
if [ ! -e /etc/supervisor.d/OpenSSH.ini ]; then
cat >/etc/supervisor.d/OpenSSH.ini << EOF
[supervisord]
nodaemon=true
user=root

[program:OpenSSH]
command=/usr/sbin/sshd -D
autostart=false
autorestart=true
priority=200
user=root
EOF
fi
if [ ! -e /usr/local/bin/openssh ]; then
cat >/usr/local/bin/openssh << EOF
#!/bin/sh
supervisord >/dev/null 2>&1 &
if [ "\$(pgrep supervisor)" != "" ]; then
while :; do
echo "
============================
|  1  启动SSH服务
|  2  检查运行状态
|  3  关闭守护和SSH服务
============================
*  请选择需要的功能 "
read -n 1 var
case \$var in    
    1)
        echo "INFO SSH服务准备运行"
        echo "NOTE 请等终端更新状态再切换到后台"
        supervisorctl start OpenSSH
        echo "NOTE 在终端里输入{设备iP}:22以访问"
        break
        ;;
    2)
        clear
        echo "INFO 服务状态:"
        supervisorctl status
        ;;
    3)
        supervisorctl stop OpenSSH
        killall supervisord && echo "INFO 已关闭守护和SSH服务"
        break
        ;;
    *)
        clear
        echo -e "\033[31mWARNING 输入错误，请重新输入\033[0m"
        ;;
esac
done
fi
EOF
chmod +x /usr/local/bin/openssh
fi
}


#修改Openrc配置
openrc_init() {
if [ -z "$(command -v openrc)" ];then
apk add openrc
fi
sed -i "s#::sysinit:/sbin/openrc sysinit#::sysinit:/sbin/openrc#g" /etc/inittab
#rc-update add supervisord
}




network_test
while :; do
echo "
    iSH-VNC 服务管理脚本 3.0
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
        first=1
        install_vnc
        vnc_resolution
        unset first
        xinit_vnc
        openrc_init
        create_openvnc
        PID=`pgrep -f 'cat /dev/location'`
        if [ -z "$PID" ]; then
            get_localtion
        fi
        echo "INFO VNC服务和桌面环境安装完成"
        echo "INFO 输入openvnc启动VNC服务和桌面环境"
        while :; do
        if read -t 5 -p "*  是否立刻运行VNC服务 5秒后默认选择'Y' [Y/N] " var
        then
            case $var in
                [yY]|"")
                    clear
                    startx
                    break
                    ;;
                [nN])
                    break
                    ;;
                *)
                    yn_error
                    continue
                    ;;
            esac
        else
            echo "INFO 选择超时，使用默认选择'Y'"
            echo "INFO 输入openvnc启动VNC和桌面环境"
            openvnc
            break
        fi
        done
        echo "INFO $THX"    
        break
        ;;
    
    2)
        clear
        del=1
        install_vnc
        break
        ;;

    3)
        clear
        echo "INFO 更新源中..."
        apk update &>/dev/null
        echo "INFO 正在安装SSH服务"
        apk add -q openssh supervisor
        if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
        echo "INFO 生成SSH安全密匙中"
        ssh-keygen -A
        fi
        echo "
NOTE 修改root账号密码，请输入一段不少于6位的密码
NOTE 密码在输入后不会显示在屏幕
NOTE 密码需要重输一次以确保输入无误"
        passwd root
        sed -i "s/#Port.*/Port 22/g" /etc/ssh/sshd_config
        sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config
        create_ssh_ini
        echo "INFO SSH服务安装完成"
        rc-update add sshd
        echo "INFO 已经将SSH服务设置为自动启动"
        echo "INFO 输入'openssh'启动SSH服务"
        echo "INFO $THX"
        break
        ;;

    4)
        clear
        ex=0
        while [ $ex = 0 ]; do
        echo "
 ========================
| 1：更改VNC分辨率 
| 2：更改使用的桌面环境 
| 3：自动更换镜像源
| q：返回主菜单 
 ========================
*  请问想要修改守护配置的哪个参数:"
        read -n 1 var
        case $var in
            1)
                vnc_resolution
                sed -i "s#^           Modes.*#           Modes "$VL"#g" /etc/X11/xorg.conf.d/10-headless.conf
                echo "INFO VNC分辨率已修改"
                echo "INFO $THX"
                exit 0
                ;;
            2)
                ex=0
                while [ $ex = 0 ]; do
                read -p "*  更改桌面环境为 [xfce/awesome/i3]" var
                install_vnc
                echo "INFO 准备将桌面环境改为$DEP"
                sed -i "s/^exec.*/$CMD/g" /root/.xinitrc
                apk add -q ${DE}
                echo "INFO 桌面环境已改为$DEP"
                echo "INFO $THX"
                exit 0
                done
                continue
                ;;
            3)
                ex=0
                while [ $ex = 0 ]; do
                change_sources
                done
                echo "INFO 输入'apk update'以更新源信息"
                break
                ;;
            [qQ]) 
                clear
                echo "INFO 返回主菜单"
                break
                ;;
            
            *)
                clear
                echo "WARNING 输入内容错误，请重新输入"
                continue
                ;;
        esac
        done
        ;;

    5)
        clear
        echo "INFO 正在将脚本复制到'/usr/local/bin'"
        cp iSH-VNC.sh /usr/local/bin/iSH-VNC
        chmod +x /usr/local/bin/iSH-VNC
        echo "INFO 复制完成，输入 iSH-VNC 即可运行本脚本"
        echo "INFO $THX"
        break
        ;;
    [qQ]) 
        clear
        echo "INFO 退出iSH VNC服务管理脚本"
        echo "INFO $THX"
        break
        ;;
    *)
        clear
        echo "INFO 内容无法识别，请重新选择"
        continue
        ;;
esac
done

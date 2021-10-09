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
    ping -4 -c 1 -w 1 -A $HOST &>/dev/null || ( echo "INFO $THX";exit 0 )
    }
}
#检测apk命令并修复
fixapk (){
    if [ -z "$(command -v apk)" ];then
        echo "WARNING 检测到apk命令缺失"
        test -f $MIRRORS_FILE
        if [ $? != "0" ]; then
            create_mirror_list
        fi
        test_mirror >/dev/null
        fast_mirror=$(get_fast_mirror)
        update_sources $fast_mirror >/dev/null
        echo "INFO 修复APK命令中..."
        wget -qO- $fast_mirror/alpine/v3.12/main/x86/apk-tools-static-2.10.5-r1.apk  | tar -xz sbin/apk.static
        ./sbin/apk.static add -q apk-tools && rm -r sbin
        echo "INFO 修复wget SSL支持中..."
        apk add -q wget libtls-standalone
        echo "INFO 修复完成"
    fi
}

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
#更换源
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
#选择安装的桌面环境
install_vnc() {
case $var in
    [xX][fF][cC][eE])
        DE='xfce4 xfce4-terminal faenza-icon-theme dbus'
        CMD='/usr/bin/startxfce4'
        DEP='xfce4'
        break
        ;;
    [aA][wW][eE][sS][oO][mM][eE]|"")
        DE='awesome feh xterm lua adwaita-gtk2-theme adwaita-icon-theme nano'
        CMD='/usr/bin/awesome'
        DEP='awesome'
        break
        ;;
    [iI][33]|[i3wm])
        DE='i3wm xterm i3status i3lock ttf-dejavu'
        CMD='/usr/bin/i3'
        DEP='i3wm'
        break
        ;;
    [sS][sS][hH])
        DE='openssh'
        DEP='ssh'
        break
        ;;
    *)
        echo -e "\033[31mWARNING  请检查输入内容是否有误?\033[0m"
        continue
        ;;
esac
}
#VNC配置
vnc_resolution() {
case $var in
    1080|1080[pP])
        VL='1920x1080x24'
        VLN='1080P'
        break
        ;;
    720|720[pP])
        VL='1280x720x24'
        VLN='720P'
        break
        ;;
    480|480[pP]|"")
        VL='640x480x24'
        VLN='480P'
        break
        ;;    
    *)
        echo "
INFO 使用自定义VNC分辨率
=======================
| iPad设备常见分辨率
| 2048×1536 (9.7/7.9寸)
| 2160×1620 (10.2寸)
| 2224x1668 (10.5寸)
| 2360x1640 (10.9寸)
| 2388x1668 (11寸)
| 2732×2048 (12.9寸)
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
                    echo "INFO VNC分辨率已设为${num1:0:4}x${num2:0:4}"
                    VL="${num1:0:4}x${num2:0:4}x24"
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
if [ -n "$VLN" ]; then
echo "INFO VNC分辨率已设为$VLN"
fi
}
#iSH后台保持运行需要位置权限
function get_localtion () {
echo "
==========================================
| INFO 申请位置权限用于保持iSH后台运行
| INFO iPhone需要保持后台，iPad可用分屏模式
=========================================="            
ex=0
while [ $ex = 0 ]; do
    echo "*  是否需要保持后台运行 5秒后默认选择 'N' [Y/N] "
    if read -t 5 -n 1 var;then
    case $var in
        [yY])
            cat /dev/location >/tmp/location.log &
            echo "INFO 请在iOS授权界面上点击 '使用App时允许'"
            sleep 3
            if [ -s /tmp/location.log ]; then
                killall cat /dev/location &>/tmp/location.log
                rm /tmp/location.log
                cat /dev/location >/dev/null &
                echo "INFO 已赋予位置权限"
                break
            else
                killall cat /dev/location &>/tmp/location.log
                rm /tmp/location.log
                cat /dev/location >/dev/null &
                echo "INFO 未赋予位置权限，无法保持后台运行"
                echo "INFO 可能是赋权超时误判，请到设置中手动赋予权限"
                break
            fi
            ;;
        [nN]|"")
            echo "INFO 不保持后台运行"
            break
            ;;
        *)
            echo -e "\033[31mWARNING  请检查输入内容是否有误?\033[0m"
            while :;do
            echo "*  是否重新选择，输入'N'不保持后台运行 [Y/N]"
            read -n 1  var
                case $var in
                    [yY])
                        clear
                        break
                        ;;
                    [nN])
                        echo "INFO  不保持后台运行"
                        ex=1
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
    else
        clear
        echo "INFO 选择超时，默认选择'N'"
        echo "INFO 不保持后台运行"
        break
    fi 
done
}
yn_error (){
    echo -e "\033[31mWARNING 只能输入 [Y/N]\033[0m"
}
#创建supervisord守护配置和VNC配置
create_supervisor_ini() {
mkdir /etc/supervisor.d/ 2>/dev/null
cat >/etc/supervisor.d/VNC.conf <<EOF
[supervisord]
nodaemon=true
user=root

[program:xvfb]
command=/usr/bin/Xvfb :1 -screen 0 ${VL}
autostart=false
autorestart=true
priority=100
user=root

[program:x11vnc]
command=/usr/bin/x11vnc -permitfiletransfer -tightfilexfer -display :1 -noxrecord -noxdamage -noxfixes -wait 5 -shared -noshm -nopw -xkb
autostart=false
autorestart=true
priority=200
user=root

[program:GraphicalEnvironment]
environment=DISPLAY=":1"
autostart=false
autorestart=true
command=${CMD}
priority=300
user=root
EOF
cat >/usr/local/bin/startx <<EOF
#!/bin/sh
supervisord >/dev/null 2>&1 &
if [ "\$(pgrep supervisor)" != "" ]; then
while :; do
echo "
============================
|  1  启动VNC服务
|  2  检查运行状态
|  3  关闭守护和VNC服务
============================
*  请选择需要的功能 "
read -n 1 var
case \$var in 
    1)
        echo "INFO VNC服务和桌面环境准备运行"
        echo "NOTE 请等终端更新状态再切换到后台"
        supervisorctl start xvfb x11vnc GraphicalEnvironment
        echo "INFO 守护进程已运行"
        echo "NOTE 在VNC里输入127.0.0.1:5900以访问"
        break
        ;;
    2)
        clear
        echo "INFO 服务状态:"
        supervisorctl status
        ;;
    3)
        clear
        pkill -f 'cat /dev/location'
        supervisorctl stop xvfb x11vnc GraphicalEnvironment
        pkill supervisor && echo "INFO 已关闭守护和VNC服务"
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
chmod +x /usr/local/bin/startx
}
#创建SSH配置
create_ssh_ini() {
mkdir /etc/supervisor.d/ 2>/dev/null
cat >/etc/supervisor.d/OpenSSH.conf <<EOF
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
cat >/usr/local/bin/openssh <<EOF
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
}

network_test
fixapk
while :; do
echo "
    iSH-VNC 服务管理脚本 2.1
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
        while :; do
        if read -t 15 -p "*  请选择想安装的桌面环境 15秒后默认选择'awesome' [xfce|awesome|i3]" var ; then
            install_vnc
        else
            echo "INFO 选择超时，使用默认选择'awesome'"
            DE='awesome feh xterm lua adwaita-gtk2-theme adwaita-icon-theme nano'
            CMD='/usr/bin/awesome'
            DEP='awesome'
            break
        fi
        done
        echo "INFO 正在安装${DEP}桌面环境"
        apk add -q xvfb x11vnc xorg-server xf86-video-dummy ${DE} supervisor
        ex=0
        while [ $ex = 0 ]; do
        echo " ============================================="
        echo " 选项: 1080P / 720P / 480P / 任意字符进入自定义"
        echo " ============================================="
        if read -t 10 -p "*  请选择分辨率 10秒后默认选择'480P':" var
        then
            vnc_resolution
        else
            echo "INFO 选择超时，自动使用默认选择 '480P'"
            VL='640x480x24'
            echo "INFO 选择的VNC分辨率为480P (默认)"
            break               
        fi   
        done
        PID=`pgrep -f 'cat /dev/location'`
        if [ -z "$PID" ]; then
            get_localtion
        fi  
        echo "NOTE 守护进程配置位于 '/etc/supervisord.d/*.conf' "
        create_supervisor_ini

        sed -i "4cfile=/var/run/supervisor.sock   ; (the path to the socket file)" /etc/supervisord.conf
        sed -i "20cpidfile=/var/run/supervisord.pid ; (supervisord pidfile;default supervisord.pid)" /etc/supervisord.conf
        sed -i "40cserverurl=unix:///var/run/supervisor.sock ; use a unix:// URL  for a unix socket" /etc/supervisord.conf
        sed -i "131cfiles = /etc/supervisor.d/*.conf" /etc/supervisord.conf
        echo "INFO VNC服务和桌面环境安装完成"
        echo "INFO 输入startx启动VNC服务和桌面环境"
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
            echo "INFO 输入startx启动VNC和桌面环境"
            startx
            break
        fi
        done
        echo "INFO $THX"    
        break
        ;;
    
    2)
        clear
        ex=0
        while [ $ex = 0 ]; do
        read -p "*  请选择想删除的包 [xfce|awesome|i3|ssh] :" var
        install_vnc
        done
        apk del -q xvfb x11vnc ${DE} supervisor
        rmdir /etc/supervisor.d
        rm /usr/local/bin/startx
        rm /usr/local/bin/iSH-VNC
        echo "INFO 已删除${DEP}相关包及配置文件"
        echo "INFO $THX"
        break
        ;;

    3)
        clear
        echo "INFO 更新源中..."
        apk update &>/dev/null
        echo "INFO 正在安装SSH服务"
        apk add -q openssh supervisor
        if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
        echo "INFO 生成SSH安全密匙，回车继续"
        ssh-keygen -A
        fi
        echo "
NOTE 正在修改root账号密码
NOTE 密码在输入后不会显示在屏幕
NOTE 密码需要重输一次以确保输入无误"
        passwd root
        sed -i "s/#Port.*/Port 22/g" /etc/ssh/sshd_config
        sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config
        sed -i "4cfile=/var/run/supervisor.sock   ; (the path to the socket file)" /etc/supervisord.conf
        sed -i "20cpidfile=/var/run/supervisord.pid ; (supervisord pidfile;default supervisord.pid)" /etc/supervisord.conf
        sed -i "40cserverurl=unix:///var/run/supervisor.sock ; use a unix:// URL  for a unix socket" /etc/supervisord.conf
        sed -i "131cfiles = /etc/supervisor.d/*.conf" /etc/supervisord.conf        
        create_ssh_ini
        echo "INFO SSH服务安装完成"
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
                ex=0
                while [ $ex = 0 ]; do
                read -p "*  请选择分辨率 [1080P/720P/480P/任意字符进入自定义]" var
                vnc_resolution
                done
                sed -i "s/^command=\/usr\/bin\/Xvfb.*/command=\/usr\/bin\/Xvfb :1 -screen 0 $VL/g" /etc/supervisor.d/VNC.conf
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
                sed -i "23ccommand=${CMD}" /etc/supervisor.d/VNC.conf
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

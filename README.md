# iSH-VNC服务配置管理脚本
<p align="center">
<a href="https://ish.app">
<img src="https://user-images.githubusercontent.com/31967654/100516312-f1c91800-31bd-11eb-8beb-c485c84c157a.png">
</a>
</p>

本脚本是为了方便在iSH上安装管理VNC服务所写，只在iSH上测试，在其他Alpine上运行可能会出Bug。

本次2.0更新，修改了脚本大量内容，提高代码可读性，方便阅读修改；精简重复代码，缩小脚本体积。

* 2021-10-10
- 更新2.1.1修复App Store 1.2版本之后导致Supervisor守护运行报错的问题

# 脚本主要功能 

- 一键无交互式安装配置VNC服务和桌面环境。

- 修改VNC分辨率，更改桌面环境。（仅支持通过本脚本安装的VNC服务和桌面环境）

- 安装和配置SSH服务

- 为不熟悉Linux的使用者配置了一定程度问题的解决方案。

> 源下载慢，一键更换国内源<br/>
> 源更新失败，自动更改DNS后重试<br/>
> Supervisord不懂配置，脚本内置简单配置<br/>
> iSH后台运行需要位置权限，脚本帮助你判断<br/>
> 基本做到开箱即用，无需过多操作。

- ~~针对App Store版的iSH没有apk命令和wget不支持tls写了一键修复脚本~~

> ~~因为wget不支持tls导致没法用https链接，故自己弄了一台ECS用http代理了github的https链接，一定程度解决了这个问题;~~

# 如何使用

* 一键运行脚本命令

`wget https://github.com/lurenJBD/iSH-VNC/raw/main/iSH-VNC_CN.sh -q -O iSH-VNC.sh && sh iSH-VNC.sh `

* ~~针对App Store版wget不支持tls而使用http代理的命令（担心http代理不安全的请不要用！）~~

`~~wget http://ish.rinko.icu/lurenJBD/iSH-VNC/main/iSH-VNC_CN.sh -q -O iSH-VNC.sh && sh iSH-VNC.sh~~ `

# 注意事项

- 脚本只在iSH中通过测试，虽然iSH运行的是Alpine(i386)Linux，但无法保证在其它Alpine中能正常运作。

- 本人写Shell的水平一般，难免有纰漏。

- 在77版（包括TF和App Store版）之前的 iSH 还无法运行xfce4桌面环境，运行i3wm会遇到i3status报错（听闻可以运行，目前尚未找到办法），只有awesome桌面环境可以正常运行。

- 目前使用的Supervisord守护还没法做到开机启动，所以服务必须要等守护启动才可以用配置的快捷命令运行（脚本会检查守护是否运行再去启动对应服务）

- ~~因为http代理本身并不安全，想保证安全性的请自己手动到[Alpine官网](http://dl-cdn.alpinelinux.org/alpine)下载rootfs自行导入~~

> 1.点击键盘拓展栏上的设置图标,选择Filesystems菜单项<br/>
> 2.进入菜单后点击右上角Import，选择rootfs导入<br/>
> 3.找到Alpine.tar.gz导入<br/>
> 4.导入完成后在Filesystems菜单项中会多一个选项<br/>
> 5.点击新选项进入，选择'Boot From This Filesystem'<br/>
> 6.完成操作后iSH会闪退，重新打开app即可

# 相关链接

* [iSH Linux shell for iOS](https://github.com/ish-app/ish)
>感谢[tbodt](https://github.com/tbodt)写出如此有趣的软件，同时实现了在iOS上免越狱运行一款跨架构的Linux Shell

* [Termux-Alpine-VNC](https://github.com/dm9pZCAq/TermuxAlpineVNC)
>感谢[dm9pZCAq](https://github.com/dm9pZCAq)写的Alpine VNC安装脚本作参考

* [Supervisord使用教程](https://www.guaosi.com/2019/02/25/install-and-use-supervisor/)
>感谢[guaosi](https://www.guaosi.com/)写的Supervisord使用教程，学习后发现我最初的使用办法太蠢了

* [Alpine Linux](https://alpinelinux.org)
>非常优秀的轻量级Linux发行版，在iSH中Alpine的rootfs大小只有8.1MB。

* [演示视频](https://b23.tv/YYaNXG)
>B站简易效果演示，使用必剪app在iPad上完成录制剪辑投稿。

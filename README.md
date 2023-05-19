# iSH-Tools 介绍

<p align="center">
<a href="https://ish.app">
<img src="https://github.com/lurenJBD/iSH-Tools/assets/31967654/c58c787e-1299-459a-97a3-38a507e2eeb1">
</a>
</p>

iSH-Tools主要用于在iSH快捷方便地安装管理SSH和VNC，同时还提供多种工具，让iSH更好用，更易用

# 更新日志

* 2020-11-28

> 本次2.0更新，修改了脚本大量内容，提高代码可读性，方便阅读修改；精简重复代码，缩小脚本体积

* 2021-10-10

> 更新2.1.1版本
> 修复App Store 1.2版本之后导致Supervisor守护运行报错的问题

* 2023-02-26

> 更新3.0版本`<br/>`
> 适配 App Store 1.2.3版本 以及 TestFlight 1.3(458)版本`<br/>`
> 解决无法正常安装运行VNC和SSH`<br/>`
> 改用OpenRC作为服务管理，同时支持了SSH和VNC服务自启动`<br/>`
> 已知的BUG: 在首次执行脚本安装SSH或VNC服务，由于 iSH 自身的原因，导致OpenRC无法正确启动对应服务，需要重启iSH App才能正常启动`<br/>`

* 2023-05-14

> 更新3.1版本`<br/>`
> BUG修复：`<br/>`
> 1.镜像源测速永远选择最后一个源的错误`<br/>`
> 2.因漏了一对双引号，导致在安装好VNC服务后会提示 feh lua 的错误`<br/>`
> 3.已安装服务的判断逻辑存在漏洞，会导致重复安装`<br/>`
> 优化：`<br/>`
> 1.函数大幅规整，尽可能让他人容易理解其中的逻辑`<br/>`
> 2.减少部分重复代码，减少不必要的 if 判断`<br/>`
> 3.改变变量存储机制，避免变量被错误地使用`<br/>`
> 改进：`<br/>`
> 1.全新手搓的交互菜单`<br/>`
> 2.新内置3个工具 coremark、 cpuid2cpuflags 和 oh-my-zsh`<br/>`
> 3.大幅改进服务 安装&运行 状态提示，让其更直观，同时也有选项对其进行更改，无需手敲代码`<br/>`
> 4. 提示 现在有颜色了，更好理解重要等级

# 脚本主要功能

- 一键无交互式安装配置VNC服务和SSH服务。
- 支持修改VNC分辨率，更改桌面环境。（仅支持通过本脚本安装的VNC服务和桌面环境）
- 安装和配置SSH服务
- 为不熟悉Linux的使用者配置了一定程度问题的解决方案。

> 源更新慢？脚本内置一键测速换源功能`<br/>`
> 访问github慢，脚本内置镜像站替换功能`<br/>`
> DNS解析不了？脚本会自动更改DNS`<br/>`
> 不懂如何保持iSH后台运行，脚本帮你解决`<br/>`
> 基本做到开箱即用，无需过多操作

# 如何使用

* 一键运行脚本命令（3.1版本之前）

`apk add bash && wget https://github.com/lurenJBD/iSH-Tools/raw/main/iSH-Tools.sh -qO iSH-Tools.sh && bash iSH-Tools.sh `

* 一键运行脚本命令（3.2版本之后，推荐访问Github困难用户使用）

`sh -c "$(wget -qO- https://ghproxy.com/https://github.com/lurenJBD/iSH-Tools/raw/main/iSH-Tools-Setup-CN.sh)"`

# 注意事项

- 脚本只保证在iSH中正常运行，虽然iSH运行的是Alpine(i386)Linux，但无法保证在其它Alpine中能正常运作
- 本人写Shell的水平一般，难免有纰漏

# 相关链接

* [iSH Linux shell for iOS](https://github.com/ish-app/ish)

> 感谢[tbodt](https://github.com/tbodt)写出如此有趣的软件，同时实现了在iOS上免越狱运行一款跨架构的Linux Shell

* [OS repo speed test](https://github.com/lework/script/blob/master/shell/test/os_repo_speed_test.sh)

> 感谢[lework](https://github.com/lework)写的镜像源一键测速脚本，本人使用该作者的脚本代码作为一键换源功能

* [Termux-Alpine-VNC](https://github.com/dm9pZCAq/TermuxAlpineVNC)

> 感谢[dm9pZCAq](https://github.com/dm9pZCAq)写的Alpine VNC安装脚本作参考

* [Supervisord使用教程](https://www.guaosi.com/2019/02/25/install-and-use-supervisor/)

> 感谢[guaosi](https://www.guaosi.com/)写的Supervisord使用教程，学习后发现我最初的使用办法太蠢了

* [Alpine Linux](https://alpinelinux.org)

> 非常优秀的轻量级Linux发行版，在iSH中Alpine的rootfs大小只有8.1MB

* [演示视频](https://b23.tv/YYaNXG)

> B站简易效果演示，使用必剪app在iPad上完成录制剪辑投稿

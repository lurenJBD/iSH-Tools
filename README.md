# iSH-Tools 介绍

<p align="center">
<a href="https://ish.app">
<img src="https://github.com/lurenJBD/iSH-Tools/assets/31967654/c58c787e-1299-459a-97a3-38a507e2eeb1">
</a>
</p>

iSH-Tools主要用于在iSH快捷方便地安装管理SSH和VNC，同时还提供多种工具，让iSH更好用，更易用

# 更新日志

<details>
<summary> 2020-11-28  |  2.0 更新日志 </summary>
  
> 修改了脚本大量内容，提高代码可读性，方便阅读修改；精简重复代码，缩小脚本体积<br/>
</details>

<details>
<summary> 2021-10-10  |  2.1 更新日志 </summary>
  
> 修复App Store 1.2版本之后导致 Supervisor 守护运行报错的问题<br/>
</details>

<details>
<summary> 2023-02-26  |  3.0 更新日志 </summary>
  
> 适配 App Store 1.2.3版本 以及 TestFlight 1.3(458)版本<br/>
> 解决无法正常安装运行VNC和SSH服务的问题<br/>
> 改用OpenRC作为服务管理，同时支持了SSH和VNC服务自启动<br/>
> 已知的BUG: 在首次执行脚本安装SSH或VNC服务，由于 iSH 自身的原因，<br/>
> 导致OpenRC无法正确启动对应服务，需要重启iSH App才能正常启动<br/>
</details>

<details>
<summary> 2023-05-14  |  3.1 更新日志 </summary>
  
> 优化：<br/>
> 1.函数大幅规整，尽可能让他人容易理解其中的逻辑<br/>
> 2.减少部分重复代码，减少不必要的 if 判断<br/>
> 3.改变变量存储机制，避免变量被错误地使用<br/>
> 
> 修复：<br/>
> 1.镜像源测速永远选择最后一个源的错误<br/>
> 2.因漏了一对双引号，导致在安装好VNC服务后出现'feh lua...'的错误<br/>
> 3.已安装服务的判断逻辑存在漏洞，会导致重复安装<br/>
> 
> 改进：<br/>
> 1.全新手搓的交互菜单<br/>
> 2.新内置3个工具 coremark、 cpuid2cpuflags 和 oh-my-zsh<br/>
> 3.大幅改进服务 安装&运行 状态提示，让其更直观，同时支持对其进行更改，无需手敲代码<br/>
> 4.<提示>现在有颜色了，更好理解重要等级<br/>
</details>

<details>
<summary> 2024-01-17  |  3.3 更新日志 </summary>
  
> 优化：<br/>
> 1.改进部分提示，比如安装SSH服务后会提示用户保持iSH后台运行<br/>
> 2.修改用户地区的检测机制<br/>
> 3.对包安装的超时操作进行了调整，改使用清华源作为默认的镜像源<br/>
> 
> 修复：<br/>
> 1.修正/etc/iSH-Tools/配置文件混乱的问题，3.1之前的版本升级会需要再次初始化脚本<br/>
> 
> 改进：<br/>
> 1.尝试对iSH-AOK进行初步的适配<br/>
> 2.加入参数模式，使用 -h，--help 来查看具体内容<br/>
</details>

<details>
<summary> 2024-07-15  |  3.4 更新日志 </summary>
  
> 优化：<br/>
> 1.优化菜单显示，当没有安装VNC/SSH时不显示其他选项<br/>
> 2.源管理支持显示当前使用的源，如果显示为‘未知源’，请手动更换一次源<br/>
> 
> 修复：<br/>
> 1.修复VNC服务无法更换桌面环境的BUG<br/>
> 2.修复传入参数后无法快速执行对应功能的BUG<br/>
> 3.修复Coremark跑分只跑单线程测试的问题<br/>
> 
> 改进：<br/>
> 1.支持覆盖脚本内置变量，详细看下面说明<br/>
> 比如 支持跳过网络检查，地区检查等<br/>
</details>

# 脚本主要功能

- 交互式安装配置VNC服务和SSH服务
- 支持修改VNC分辨率，更改桌面环境（仅支持通过本脚本安装的VNC服务和桌面环境）
- 安装和配置SSH服务
- 为不熟悉Alpine的使用者配置了一定程度问题的解决方案

> 源更新慢？脚本内置一键测速换源功能<br/>
> 访问github慢，脚本内置镜像站替换功能<br/>
> DNS解析不了？脚本会自动更改DNS<br/>
> 不懂如何保持iSH后台运行，脚本帮你解决<br/>
> 基本做到开箱即用，无需过多操作

# 如何使用

* 一键运行脚本命令（海外用户使用）

`sh -c "$(wget -qO- https://github.com/lurenJBD/iSH-Tools/raw/main/iSH-Tools-Setup-CN.sh)"`

* 一键运行脚本命令（推荐访问Github困难用户使用）

`sh -c "$(wget -qO- https://mirror.ghproxy.com/https://github.com/lurenJBD/iSH-Tools/raw/main/iSH-Tools-Setup-CN.sh)"`

# 覆盖脚本内置变量

从 3.4 版本开始，支持覆盖脚本内置变量，让脚本适用于更多情况，以下是参数说明：

| 变量名称 | 可选项 | 注释说明 |
| --- | --- | --- |
| `HOST` | 任意网址，默认为 www.baidu.com | 用于检测网络连通性的网址 |
| `NAMESERVER` | 支持UDP查询的DNS，默认为 223.5.5.5 | 当遇到域名解析故障时替换的DNS服务器 |
| `Github_Url` | github网站，默认为 https://github.com | 从指定网站上下载iSH-Tools工具 |
| `Mirror_Url` | github镜像站，默认为 https://mirror.ghproxy.com/https://github.com | 用于加速github访问 |
| `Mirror_Repo` | 默认替换的镜像源，默认为 http://mirrors.tuna.tsinghua.edu.cn | 用于加速apk源访问 |
| `Bypass_Check` | 1：跳过网络&地区检查、Net：只跳过网络检查、Loc：只跳过地区检查，默认为 0 都不跳过| 跳过脚本内置检测功能 |
| `Dev_Mode` | 1：开启开发者模式。允许允许在非iSH的Alpine下，默认为 0 不开启 | 用于在其他Alpine下使用 |

## 例子
``` 
# 跳过全部检测
Bypass_Check=1 iSH-Tools

# 只跳过 网络连接检测
Bypass_Check=Net iSH-Tools

# 进入开发者模式 (在iSH里不会有效果)
Dev_Mode=1 iSH-Tools

# 让变量长久生效
export Bypass_Check=1

# 让变量自动生效，以ash为例子
echo "export Bypass_Check=1" >> ~/.profile
```


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

* [演示视频](https://www.bilibili.com/video/BV1Ma411A7UN/)

> B站简易效果演示，使用必剪app在iPad上完成录制剪辑投稿

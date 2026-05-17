# Toolbox (tb)

VPS 常用工具箱，命令 `tb` 一键呼出菜单。Debian 12/13。

## 安装

```bash
wget -O tb https://raw.githubusercontent.com/merlin-node/toolbox/main/tb.sh && chmod +x tb && sudo mv tb /usr/local/bin/tb
```

之后输入 `tb` 即可。

## 功能

- 系统（更新清理 / 系统信息 / 可疑进程检测 / 时区 / hostname / sudo 用户）
- 基础工具一键装卸（curl / wget / sudo / nano / htop / tmux / git / 等 12 项）
- 网络优化（BBR + fq 一键启用）
- swap 管理
- Caddy 反代（一键生成 Caddyfile / 自动 HTTPS / 服务管理）
- Docker 管理（容器/镜像/网络/卷交互式管理）
- 网络测试（yabs / NodeQuality / 三网回程 / IP 质量 / 流媒体解锁 等）
- SSH 管理（改密 / 改端口 / 密钥登录 / 禁 root / fail2ban）
- DD 重装系统（Debian / Ubuntu / Alma / Rocky / CentOS / Fedora / Alpine / 自定义）

## 卸载

菜单内 `9. 脚本管理 → 2) 卸载脚本`，或直接 `sudo rm /usr/local/bin/tb`。

## License

GPL-3.0

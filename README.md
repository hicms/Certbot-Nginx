# Certbot + Nginx SSL 证书自动化配置

> 本教程基于真实生产环境配置（novel.aipenman.com），为您的网站快速配置免费 HTTPS 证书。

## 环境信息

- **操作系统**: Ubuntu 24.04 LTS
- **Nginx 版本**: 1.24.0
- **Certbot 版本**: 2.9.0
- **证书路径**: `/etc/letsencrypt/live/`

## 实际案例

**域名**: novel.aipenman.com
**证书颁发**: 2025-10-28
**证书到期**: 2026-01-26（90天有效期）
**自动续期**: 每天检查，到期前30天自动续期

---

## 一键申请证书

只需一条命令，自动完成证书申请和 Nginx 配置：

```bash
/root/certbot-apply.sh your-domain.com your-email@example.com
```

**实际示例**：
```bash
/root/certbot-apply.sh novel.aipenman.com hicms@qq.com
```

**脚本自动完成**：
- ✅ 申请 Let's Encrypt 免费 SSL 证书（90天有效期）
- ✅ 自动配置 Nginx SSL 证书路径
- ✅ 自动配置 HTTP 到 HTTPS 重定向
- ✅ 创建续期配置文件

**申请成功后**：
- 证书文件：`/etc/letsencrypt/live/novel.aipenman.com/fullchain.pem`
- 私钥文件：`/etc/letsencrypt/live/novel.aipenman.com/privkey.pem`

---

## 自动续期机制

### 双重保障

系统已配置两种自动续期方式：

**1. Systemd Timer（主要）**
```bash
# 查看下次运行时间
systemctl list-timers | grep certbot
```

**2. Cron 定时任务（备用）**
```bash
# 查看定时任务
crontab -l

# 配置：每天凌晨 3:00 执行
0 3 * * * /root/certbot-renew.sh >> /var/log/certbot-renew.log 2>&1
```

### 重要说明

**续期时间线**：
```
申请证书              开始自动续期            证书到期
   |                       |                     |
2025-10-28            2025-12-27           2026-01-26
   |<-------60天-------->|<------30天------->|
```

**关键点**：
- ⚠️ 每天运行检查，但**只有距离到期 30 天内才会真正续期**
- ✅ 如果还有超过 30 天，直接跳过，不会重复申请证书
- ✅ 续期成功后自动重载 Nginx
- ✅ 续期后重新计算 90 天有效期

---

## 常用命令速查

### 查看证书信息
```bash
# 列出所有证书及到期时间
certbot certificates

# 查看特定域名证书
certbot certificates -d novel.aipenman.com
```

### 测试续期功能
```bash
# 模拟续期测试（不会真正续期）
certbot renew --dry-run

# 手动执行续期检查（只续期30天内到期的证书）
/root/certbot-renew.sh
```

### 查看日志
```bash
# 查看自定义续期日志
tail -f /var/log/certbot-renew.log

# 查看 Certbot 官方日志
tail -f /var/log/letsencrypt/letsencrypt.log
```

### 测试 HTTPS
```bash
# 测试 HTTPS 访问
curl -I https://novel.aipenman.com

# 测试 Nginx 配置
nginx -t

# 重载 Nginx
systemctl reload nginx
```

---

## Nginx SSL 配置示例

Certbot 会自动修改 Nginx 配置，生成如下配置：

```nginx
server {
    listen 443 ssl http2;
    server_name novel.aipenman.com;

    # SSL 证书配置（由 Certbot 自动添加）
    ssl_certificate /etc/letsencrypt/live/novel.aipenman.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/novel.aipenman.com/privkey.pem;

    # 其他配置...
}

# HTTP 自动跳转 HTTPS（由 Certbot 自动添加）
server {
    listen 80;
    server_name novel.aipenman.com;

    if ($host = novel.aipenman.com) {
        return 301 https://$host$request_uri;
    }
}
```

---

## 故障排查

### 1. 证书申请失败

**问题**：域名验证失败
```
Failed authorization procedure
```

**解决方案**：
```bash
# 检查域名 DNS 解析
dig novel.aipenman.com

# 检查 Nginx 是否运行
systemctl status nginx

# 检查端口是否开放
netstat -tlnp | grep -E ':(80|443)'
```

### 2. Cloudflare CDN 用户注意

如果使用 Cloudflare CDN：
- ✅ SSL/TLS 模式设为 **"Full"** 或 **"Full (strict)"**
- ❌ 不要用 **"Flexible"** 模式（会导致验证失败）

### 3. 续期测试时间过长

执行 `certbot renew --dry-run` 时可能需要等待几分钟，因为：
- Certbot 会添加随机延迟（避免服务器过载）
- 日志显示：`random delay of 234 seconds`
- 这是正常行为，生产环境中也会有随机延迟

### 4. 查看详细错误
```bash
# 查看完整日志
tail -100 /var/log/letsencrypt/letsencrypt.log

# 详细模式测试续期
certbot renew --dry-run -v
```

---

## 重要提示

### 证书有效期
- Let's Encrypt 证书有效期：**90 天**
- 自动续期时间：到期前 **30 天**
- 续期后新证书：重新计算 **90 天**

### 证书文件结构
```
/etc/letsencrypt/live/novel.aipenman.com/
├── fullchain.pem     # 完整证书链（Nginx 使用这个）
├── privkey.pem       # 私钥文件（Nginx 使用这个）
├── cert.pem          # 域名证书
└── chain.pem         # 中间证书
```

**备份建议**：定期备份 `/etc/letsencrypt/` 整个目录

### Let's Encrypt 速率限制
- 每个域名每周最多 **50 个证书**
- 每个 IP 每3小时最多 **10 个失败验证**
- 正常使用不会触发限制

---

## 验证清单

**申请证书前**：
- [ ] 域名 DNS 已解析到服务器
- [ ] Nginx 已安装并运行
- [ ] 防火墙开放 80 和 443 端口

**申请证书后**：
- [ ] 执行 `certbot certificates` 查看证书信息
- [ ] 访问 `https://your-domain.com` 测试 HTTPS
- [ ] 访问 `http://your-domain.com` 确认自动跳转 HTTPS
- [ ] 执行 `systemctl list-timers | grep certbot` 确认定时任务

---

## 快速参考

| 操作       | 命令                                                    |
| -------- | ----------------------------------------------------- |
| 申请证书     | `/root/certbot-apply.sh domain.com email@example.com` |
| 查看证书     | `certbot certificates`                                |
| 测试续期     | `certbot renew --dry-run`                             |
| 手动续期     | `/root/certbot-renew.sh`                              |
| 查看日志     | `tail -f /var/log/certbot-renew.log`                  |
| 测试 Nginx | `nginx -t`                                            |
| 重载 Nginx | `systemctl reload nginx`                              |

---

## 相关资源

- **Certbot 官网**: https://certbot.eff.org/
- **Let's Encrypt**: https://letsencrypt.org/
- **Nginx SSL 配置**: https://nginx.org/en/docs/http/configuring\_https\_servers.html

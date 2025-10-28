#!/bin/bash

###############################################################################
# Certbot SSL 证书申请脚本
# 用途：为域名申请 Let's Encrypt 免费 SSL 证书
# 使用方法：./certbot-apply.sh your-domain.com your-email@example.com
###############################################################################

# 检查参数
if [ $# -lt 2 ]; then
    echo "使用方法: $0 <域名> <邮箱>"
    echo "示例: $0 example.com admin@example.com"
    exit 1
fi

DOMAIN=$1
EMAIL=$2

echo "================================================"
echo "开始为域名 $DOMAIN 申请 SSL 证书"
echo "邮箱: $EMAIL"
echo "================================================"

# 检查 Certbot 是否安装
if ! command -v certbot &> /dev/null; then
    echo "错误: Certbot 未安装"
    echo "请先运行: apt install -y certbot python3-certbot-nginx"
    exit 1
fi

# 检查 nginx 是否运行
if ! systemctl is-active --quiet nginx; then
    echo "警告: nginx 未运行，尝试启动..."
    systemctl start nginx
    if [ $? -ne 0 ]; then
        echo "错误: 无法启动 nginx"
        exit 1
    fi
fi

# 方式1: 使用 nginx 插件自动配置（推荐）
echo ""
echo "方式1: 使用 nginx 插件自动申请和配置证书"
echo "------------------------------------------------"
certbot --nginx \
    -d $DOMAIN \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    --redirect

if [ $? -eq 0 ]; then
    echo ""
    echo "================================================"
    echo "证书申请成功！"
    echo "证书位置: /etc/letsencrypt/live/$DOMAIN/"
    echo "  - 证书文件: fullchain.pem"
    echo "  - 私钥文件: privkey.pem"
    echo "nginx 配置已自动更新"
    echo "================================================"
else
    echo ""
    echo "------------------------------------------------"
    echo "方式1 失败，尝试方式2: 手动申请证书"
    echo "------------------------------------------------"

    # 方式2: 仅申请证书，不自动配置 nginx
    certbot certonly \
        --webroot \
        -w /var/www/html \
        -d $DOMAIN \
        --email $EMAIL \
        --agree-tos \
        --no-eff-email

    if [ $? -eq 0 ]; then
        echo ""
        echo "================================================"
        echo "证书申请成功！"
        echo "证书位置: /etc/letsencrypt/live/$DOMAIN/"
        echo "  - 证书文件: fullchain.pem"
        echo "  - 私钥文件: privkey.pem"
        echo ""
        echo "请手动配置 nginx，在 server 块中添加:"
        echo "  ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;"
        echo "  ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;"
        echo "================================================"
    else
        echo "错误: 证书申请失败"
        exit 1
    fi
fi

# 显示证书信息
echo ""
echo "证书详细信息:"
certbot certificates -d $DOMAIN

echo ""
echo "提示: 证书已配置自动续期（通过 systemd timer）"
echo "查看续期任务: systemctl list-timers | grep certbot"

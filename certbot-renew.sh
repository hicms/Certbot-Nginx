#!/bin/bash

###############################################################################
# Certbot SSL 证书自动续期脚本
# 用途：自动检查并续期即将过期的 SSL 证书
# 建议：通过 cron 每天运行一次
###############################################################################

# 日志文件
LOG_FILE="/var/log/certbot-renew.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "================================================" | tee -a $LOG_FILE
echo "[$DATE] 开始证书续期检查" | tee -a $LOG_FILE
echo "================================================" | tee -a $LOG_FILE

# 检查 Certbot 是否安装
if ! command -v certbot &> /dev/null; then
    echo "[$DATE] 错误: Certbot 未安装" | tee -a $LOG_FILE
    exit 1
fi

# 运行证书续期
echo "[$DATE] 执行证书续期命令..." | tee -a $LOG_FILE

# --quiet: 静默模式（只在有错误时输出）
# --no-self-upgrade: 不自动升级 certbot
# --deploy-hook: 续期成功后执行的命令
certbot renew \
    --quiet \
    --no-self-upgrade \
    --deploy-hook "systemctl reload nginx" \
    2>&1 | tee -a $LOG_FILE

RENEW_STATUS=$?

if [ $RENEW_STATUS -eq 0 ]; then
    echo "[$DATE] 证书续期检查完成（续期或确认无需续期）" | tee -a $LOG_FILE
else
    echo "[$DATE] 错误: 证书续期失败，退出码: $RENEW_STATUS" | tee -a $LOG_FILE
    # 发送告警（可选）
    # 这里可以添加邮件或其他告警通知
fi

# 显示所有证书状态
echo "" | tee -a $LOG_FILE
echo "[$DATE] 当前证书状态:" | tee -a $LOG_FILE
certbot certificates 2>&1 | tee -a $LOG_FILE

# 清理旧日志（保留最近30天）
find /var/log/letsencrypt -name "*.log" -type f -mtime +30 -delete 2>/dev/null

echo "================================================" | tee -a $LOG_FILE
echo "[$DATE] 续期任务完成" | tee -a $LOG_FILE
echo "================================================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

exit $RENEW_STATUS

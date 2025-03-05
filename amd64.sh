#!/bin/sh

# 设置下载的 URL 和目标文件路径
URL="https://gh.685763.xyz/https://github.com/AirportR/miaospeed/releases/download/4.5.7/miaospeed-linux-amd64-4.5.7.tar.gz"
DOWNLOAD_PATH="/miaoko/miaospeed-linux-amd64-4.5.8.tar.gz"
EXTRACT_PATH="/miaoko"
# 查找进程名称
PROCESS_NAME="supervisord"

# 删除旧文件（如果存在）
echo "Removing old files..."
rm -f /miaoko/miaospeed-linux-amd64

# 使用 wget 下载文件
echo "Downloading file..."
wget $URL -O $DOWNLOAD_PATH

# 检查文件是否下载成功
if [ $? -eq 0 ]; then
    echo "Download successful!"
else
    echo "Download failed."
    exit 1
fi

# 解压文件
echo "Extracting the archive..."
tar -zxvf $DOWNLOAD_PATH -C /miaoko

# 检查是否解压成功
if [ $? -eq 0 ]; then
    echo "Extraction successful!"
else
    echo "Extraction failed."
    exit 1
fi

# 删除下载的 tar 文件（节省空间）
echo "Cleaning up..."
rm -f $DOWNLOAD_PATH

# 最后显示文件解压后的内容（可以替换成其他需要的操作）
echo "Contents of extracted folder:"
ls $EXTRACT_PATH
service supervisord restart

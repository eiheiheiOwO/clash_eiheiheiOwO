#!/bin/sh

# 设置下载的 URL 和目标文件路径
URL="https://gh.685763.xyz/https://github.com/AirportR/miaospeed/releases/download/4.5.7/miaospeed-linux-amd64-4.5.7.tar.gz"
DOWNLOAD_PATH="/miaoko/miaospeed-linux-amd64-4.5.7.tar.gz"
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

# 使用 ps 查找进程的 PID
PID=$(ps | grep "$PROCESS_NAME" | grep -v "grep" | awk '{print $1}')

# 如果找到了进程
if [ -n "$PID" ]; then
    echo "Found process $PROCESS_NAME with PID $PID. Killing it..."
    
    # 记录进程名和 PID
    echo "Killing process: $PROCESS_NAME (PID: $PID)" >> /tmp/process_kill_log.txt
    
    # 获取进程的完整路径
    COMMAND_PATH=$(readlink /proc/$PID/exe)
    
    # 如果获取到了路径
    if [ -n "$COMMAND_PATH" ]; then
        echo "Process path: $COMMAND_PATH"

        # 使用 kill -9 强制终止进程
        kill -9 $PID

        # 检查 kill 是否成功
        if [ $? -eq 0 ]; then
            echo "Process $PROCESS_NAME terminated successfully."
            
            # 重启进程
            echo "Restarting process $PROCESS_NAME..."
            $COMMAND_PATH &
            
            # 检查是否重启成功
            if [ $? -eq 0 ]; then
                echo "Process $PROCESS_NAME restarted successfully."
            else
                echo "Failed to restart $PROCESS_NAME."
            fi
        else
            echo "Failed to terminate process $PROCESS_NAME."
        fi
    else
        echo "Failed to retrieve the command path for PID $PID."
    fi
else
    echo "No process found with name $PROCESS_NAME."
fi

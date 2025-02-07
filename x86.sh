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
# 要查找的进程名称
PROCESS_NAME="supervisord"

# 使用 ps 查找进程并获取完整命令行
PROCESS_INFO=$(ps | grep "$PROCESS_NAME" | grep -v "grep")

# 如果找到了进程
if [ -n "$PROCESS_INFO" ]; then
    # 提取 PID 和完整命令行（从第二列开始提取命令）
    PID=$(echo $PROCESS_INFO | awk '{print $1}')
    COMMAND_LINE=$(echo $PROCESS_INFO | sed 's/^[^ ]* [^ ]* //')

    echo "Found process $PROCESS_NAME with PID $PID. Killing it..."

    # 记录进程名、PID 和命令行
    echo "Killing process: $PROCESS_NAME (PID: $PID, Command: $COMMAND_LINE)" >> /tmp/process_kill_log.txt
    
    # 使用 kill -9 强制终止进程
    kill -9 $PID

    # 检查 kill 是否成功
    if [ $? -eq 0 ]; then
        echo "Process $PROCESS_NAME terminated successfully."
        
        # 从命令行中提取命令的路径和参数
        COMMAND_PATH=$(echo $COMMAND_LINE | awk '{print $1}')
        COMMAND_ARGS=$(echo $COMMAND_LINE | sed 's/^[^ ]* //')

        # 重启进程
        echo "Restarting process $PROCESS_NAME with command: $COMMAND_PATH $COMMAND_ARGS"
        $COMMAND_PATH $COMMAND_ARGS &
        
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
    echo "No process found with name $PROCESS_NAME."
fi

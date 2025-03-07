#!/bin/bash
# chkconfig: 2345 55 25
# description: MW Cloud Service

### BEGIN INIT INFO
# Provides:          bt
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts mw
# Description:       starts the mw
### END INIT INFO


PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
# export LC_ALL="en_US.UTF-8"

mw_path={$SERVER_PATH}
PATH=$PATH:$mw_path/bin


if [ -f $mw_path/bin/activate ];then
    source $mw_path/bin/activate
else 
    echo ""
fi


mw_start(){
	isStart=`ps -ef|grep 'gunicorn -c setting.py app:app' |grep -v grep|awk '{print $2}'`
	if [ "$isStart" == '' ];then
            echo -e "Starting mw... \c"
            cd $mw_path &&  gunicorn -c setting.py app:app
            port=$(cat ${mw_path}/data/port.pl)
            isStart=""
            while [[ "$isStart" == "" ]];
            do
                echo -e ".\c"
                sleep 0.5
                isStart=$(lsof -n -P -i:$port|grep LISTEN|grep -v grep|awk '{print $2}'|xargs)
                let n+=1
                if [ $n -gt 15 ];then
                    break;
                fi
            done
            if [ "$isStart" == '' ];then
                    echo -e "\033[31mfailed\033[0m"
                    echo '------------------------------------------------------'
                    tail -n 20 ${mw_path}/logs/error.log
                    echo '------------------------------------------------------'
                    echo -e "\033[31mError: mw service startup failed.\033[0m"
                    return;
            fi
            echo -e "\033[32mdone\033[0m"
    else
            echo "Starting mw... mw(pid $(echo $isStart)) already running"
    fi


    isStart=$(ps aux |grep 'task.py'|grep -v grep|awk '{print $2}')
    if [ "$isStart" == '' ];then
            echo -e "Starting mw-tasks... \c"
            cd $mw_path && python3 task.py >> ${mw_path}/logs/task.log 2>&1 &
            sleep 0.3
            isStart=$(ps aux |grep 'task.py'|grep -v grep|awk '{print $2}')
            if [ "$isStart" == '' ];then
                    echo -e "\033[31mfailed\033[0m"
                    echo '------------------------------------------------------'
                    tail -n 20 $mw_path/logs/task.log
                    echo '------------------------------------------------------'
                    echo -e "\033[31mError: mw-tasks service startup failed.\033[0m"
                    return;
            fi
            echo -e "\033[32mdone\033[0m"
    else
            echo "Starting mw-tasks... mw-tasks (pid $isStart) already running"
    fi
}


mw_stop()
{
	echo -e "Stopping mw-tasks... \c";
    pids=$(ps aux | grep 'task.py'|grep -v grep|awk '{print $2}')
    arr=($pids)

    for p in ${arr[@]}
    do
            kill -9 $p
    done
    echo -e "\033[32mdone\033[0m"

    echo -e "Stopping mw... \c";
    arr=`ps aux|grep 'gunicorn -c setting.py app:app'|grep -v grep|awk '{print $2}'`
	for p in ${arr[@]}
    do
            kill -9 $p &>/dev/null
    done
    
    if [ -f $pidfile ];then
    	rm -f $pidfile
    fi
    echo -e "\033[32mdone\033[0m"
}

mw_status()
{
        isStart=$(ps aux|grep 'gunicorn -c setting.py app:app'|grep -v grep|awk '{print $2}')
        if [ "$isStart" != '' ];then
                echo -e "\033[32mmw (pid $(echo $isStart)) already running\033[0m"
        else
                echo -e "\033[31mmw not running\033[0m"
        fi
        
        isStart=$(ps aux |grep 'task.py'|grep -v grep|awk '{print $2}')
        if [ "$isStart" != '' ];then
                echo -e "\033[32mmw-task (pid $isStart) already running\033[0m"
        else
                echo -e "\033[31mmw-task not running\033[0m"
        fi
}


mw_reload()
{
	isStart=$(ps aux|grep 'gunicorn -c setting.py app:app'|grep -v grep|awk '{print $2}')
    
    if [ "$isStart" != '' ];then
    	echo -e "Reload mw... \c";
	    arr=`ps aux|grep 'gunicorn -c setting.py app:app'|grep -v grep|awk '{print $2}'`
		for p in ${arr[@]}
        do
                kill -9 $p
        done
        cd $mw_path && gunicorn -c setting.py app:app
        isStart=`ps aux|grep 'gunicorn -c setting.py app:app'|grep -v grep|awk '{print $2}'`
        if [ "$isStart" == '' ];then
                echo -e "\033[31mfailed\033[0m"
                echo '------------------------------------------------------'
                tail -n 20 $mw_path/logs/error.log
                echo '------------------------------------------------------'
                echo -e "\033[31mError: mw service startup failed.\033[0m"
                return;
        fi
        echo -e "\033[32mdone\033[0m"
    else
        echo -e "\033[31mmw not running\033[0m"
        mw_start
    fi
}


error_logs()
{
	tail -n 100 $mw_path/logs/error.log
}

case "$1" in
    'start') mw_start;;
    'stop') mw_stop;;
    'reload') mw_reload;;
    'restart') 
        mw_stop
        mw_start;;
    'status') mw_status;;
    'logs') error_logs;;
    'default')
        cd $mw_path
        port=7200
        
        if [ -f $mw_path/data/port.pl ];then
            port=$(cat $mw_path/data/port.pl)
        fi

        if [ ! -f $mw_path/data/default.pl ];then
            echo -e "\033[33mInstall Failed\033[0m"
            exit 0
        fi

        password=$(cat $mw_path/data/default.pl)
        if [ -f $mw_path/data/domain.conf ];then
            address=$(cat $mw_path/data/domain.conf)
        fi
        if [ -f $mw_path/data/admin_path.pl ];then
            auth_path=$(cat $mw_path/data/admin_path.pl)
        fi
        if [ "$address" = "" ];then
            address=$(curl -sS --connect-timeout 10 -m 60 https://www.bt.cn/Api/getIpAddress)
        fi
        echo -e "=================================================================="
        echo -e "\033[32mMW-Panel default info!\033[0m"
        echo -e "=================================================================="
        echo  "MW-Panel-URL: http://$address:$port$auth_path"
        echo -e `python3 $mw_path/tools.py username`
        echo -e "password: $password"
        echo -e "\033[33mWarning:\033[0m"
        echo -e "\033[33mIf you cannot access the panel, \033[0m"
        echo -e "\033[33mrelease the following port (7200|888|80|443|20|21) in the security group\033[0m"
        echo -e "=================================================================="
        ;;
esac
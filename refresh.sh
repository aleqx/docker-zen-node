#!/bin/bash
#
# To install from web, do:
#   curl -s https://raw.githubusercontent.com/aleqx/docker-zen-node/master/refresh.sh|INSTALL=1 bash
#

poll=30         # seconds, poll secure node logs every T seconds for the tracker reply
maxagochall=20  # hours, if last challenge was more than this many hours ago then quit (a challenge may be imminent)
url="https://raw.githubusercontent.com/aleqx/docker-zen-node/master/refresh.sh"
log=/root/zen-refresh.log
sh=/root/zen-refresh.sh
logkeep=1000

[[ $1 = install || $1 = update || $INSTALL = 1 ]] && {
    echo "Installing ..."
    # use the same time for all servers every day
    minhour=$(date -d 'Apr 4 15:35:00 CEST 2018' +'%M %H')
    echo "$minhour * * *  root  bash $sh >> $log" > /etc/cron.d/zen-refresh
    curl -s -o $sh "$url"
    exit
}

# truncate log
[[ -f $log && `wc -l < $log` -ge $logkeep ]] && echo $(tail -n $logkeep $log) > $log

#export TZ=`date +'%Z %z'`  # for converting times to current timezone
# EDIT: it seems that `date -d STR` does convert to the current timezone as long as STR includes
# the timezone at the end, or if it's formatted as {date}T{time}Z, which apparently is assumed GMT

lastchall=`docker logs zen-secnodetracker 2>/dev/null|grep 'Challenge result'|tail -n 1`
[[ $lastchall ]] || exit  # don't restart if a challenge hasn't happened (don't know if imminent)

lastchall=${lastchall/ -- *}
lastchall=`date -d"$lastchall" +%s`
agochall=$((`date +%s`-lastchall))

echo -n "`date +'%F %T'` Last challenge was $((agochall/3600))h $(((agochall%3600)/60))m ago. "
[[ $agochall -gt $((maxagochall*3600)) ]] && echo "Skipping ..." && exit  # don't restart if last challenge too long ago (likely imminent)
echo

# wait for a successful stats to be received from the tracker
for ((i=600;i>0;i-=poll)); do
    laststats=`docker logs --tail=50 zen-secnodetracker 2>/dev/null|grep 'Stats received by '|tail -n 1`
    [[ ! $laststats ]] && sleep $poll && continue
    laststats=${laststats/ -- *}
    #laststats=`date -d"$laststats" +%s`
    agostats=$((`date +%s`-`date -d"$laststats" +%s`))
    if [[ $agostats -gt 5 && $agostats -lt 95 ]]; then
        echo "`date +'%F %T'` Last stats was at $laststats ($agostats seconds ago). Restarting zen node ..."
        systemctl restart zen-node
        exit
    else
        echo "`date +'%F %T'` Last stats was at $laststats ($agostats seconds ago). Waiting ..."
    fi
    sleep $poll
done

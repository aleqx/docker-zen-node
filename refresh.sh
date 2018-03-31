#!/bin/bash

poll=30
maxagochall=20  # hours, if last challenge was more than this many hours ago then quit (a challenge may be imminent)
url

#export TZ=`date +'%Z %z'`  # for converting times to current timezone
# EDIT: it seems that `date -d STR` does convert to the current timezone as long as STR includes
# the timezone at the end, or if it's formatted as {date}T{time}Z, which apparently is assumed GMT

lastchall=`docker logs zen-secnodetracker|grep 'Challenge result'|tail -n 1`
[[ $lastchall ]] || exit  # don't restart if a challenge hasn't happened (don't know if imminent)

lastchall=${lastchall/ -- *}
lastchall=`date -d"$lastchall" +%s`
agochall=$((`date +%s`-lastchall))

echo "Last challenge was $((agochall/3600))h $(((agochall%3600)/60))m ago."

[[ $agochall -gt $((maxagochall*3600)) ]] && exit  # don't restart if last challenge too long ago (likely imminent)

# wait for a successful stats to be received from the tracker
for ((i=600;i>0;i-=poll)); do
        laststats=`docker logs --tail=10 zen-secnodetracker|grep 'Stats received by '|tail -n 1`
        [[ ! $laststats ]] && sleep $poll && continue
        laststats=${laststats/ -- *}
        #laststats=`date -d"$laststats" +%s`
        agostats=$((`date +%s`-`date -d"$laststats" +%s`))
        if [[ $agostats -gt 5 && $agostats -lt 75 ]]; then
                echo "Last stats was at $laststats ($agostats seconds ago). Restarting zen node ..."
                echo systemctl restart zen-node
                break
        else
                echo "Last stats was at $laststats ($agostats seconds ago). Waiting ..."
        fi
        sleep $poll
done

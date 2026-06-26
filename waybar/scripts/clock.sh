#!/usr/bin/env bash

KO_MONTHS=("" "1월" "2월" "3월" "4월" "5월" "6월" "7월" "8월" "9월" "10월" "11월" "12월")

year=$(date +%Y)
month=$(date +%-m)
month_pad=$(date +%m)
day=$(date +%-d)
time=$(date +%H:%M:%S)

first_dow=$(date -d "${year}-${month_pad}-01" +%w)
days_in_month=$(date -d "${year}-${month_pad}-01 +1 month -1 day" +%d)

lines="  ${KO_MONTHS[$month]} ${year}\n 일  월  화  수  목  금  토 "

line=""
for ((i=0; i<first_dow; i++)); do
    line+="    "
done

col=$first_dow
for ((d=1; d<=days_in_month; d++)); do
    if [ "$d" -eq "$day" ]; then
        line+=$(printf "[%2d]" $d)
    else
        line+=$(printf " %2d " $d)
    fi
    col=$(( (col + 1) % 7 ))
    if [ $col -eq 0 ]; then
        lines+="\n${line}"
        line=""
    fi
done
[ -n "$line" ] && lines+="\n${line}"

printf '{"text": "<small>%s</small>", "tooltip": "%s"}\n' "$time" "$lines"

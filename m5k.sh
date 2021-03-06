#!/bin/bash

N=0
while read DOMAIN
	do

	N=$(expr $N + 1)					
	INDEXKEY=$(echo $DOMAIN | colrm 3)

	LC_ALL=C grep -e "$DOMAIN" "$INDEXKEY" > "$DOMAIN".temp
	TOTALIP=$(LC_ALL=C cat $DOMAIN.temp | wc -l)
	UNIQUEIP=$(LC_ALL=C sort -u $DOMAIN.temp | wc -l) 

	while read IP
		do
		LC_ALL=C grep -e "$IP" "$DOMAIN".temp > "$IP".temp
		LC_ALL=C cat "$IP".temp | wc -l >> spearman.temp
		rm "$IP.temp"
	done <indexer.ip

	paste spearman.temp spearman.control > data.csv
	SPEARMAN=$(./spearman.r | sed 1d | cut -d ' ' -f4 | head -1)
	rm spearman.temp						
	rm "$DOMAIN".temp

	wget -q -O entropy.temp $DOMAIN -T 3 --tries=2

	ENTROPY=$(cat entropy.temp | perl -0777 -MHTML::Strip -nlE 'say HTML::Strip->new->parse($_)' | sed -e 's/[[:blank:]]//g' | sort -u | tr '\n' ' ' | ./entropy.r | cut -d ' ' -f2)
	rm entropy.temp
			
	sudo t search all "$DOMAIN" -l > twitter.temp
	TWENTROPY=$(cut -d ' ' -f9- twitter.temp | ./entropy.r | cut -d ' ' -f2)
	TWTOTAL=$(cut -d ' ' -f8 twitter.temp | wc -l)
	TWUNIQUE=$(cut -d ' ' -f8 twitter.temp | sort -u | wc -l)
	LC_ALL=C cut -d ' ' -f8 twitter.temp | sort -u | shuf -n 5 > handles.temp

	while read HANDLE
		do
		LC_ALL=C curl -s https://twitter.com/"$HANDLE" | grep data-is-compact | cut -d '>' -f2 | cut -d '<' -f1 | sed 2d | head -2 | tr '\n' '\t' >> network.temp
	done <handles.temp

	TWEETS=$(awk '{ sum += $1; n++ } END { if (n > 0) print sum / n; }' network.temp)
	FOLLOWERS=$(awk '{ sum += $2; n++ } END { if (n > 0) print sum / n; }' network.temp)
	rm network.temp

	sudo curl https://www.mywot.com/en/scorecard/"$DOMAIN" -s -m 3 --retry 2 > wot.temp
	TRUST=$(grep "trustworthiness" wot.temp | tr ' ' '\n' | grep data-value | cut -d '"' -f2)
	VOTES=$(grep -e "span itemprop=" wot.temp | grep votes | cut -d '>' -f2 | cut -d '<' -f1)
	rm wot.temp
					
	USER_AGENT=$(shuf indexer.ua | head -1)
	PROXY=$(shuf indexer.proxy | head -1)
	sudo wget -O alexa.temp --user-agent="$USER_AGENT" http://www.alexa.com/siteinfo/"$DOMAIN" -q --proxy-user "username" --proxy-password "password" use_proxy=yes -e http_proxy="$PROXY" -T 3 --tries=2
	BOUNCE=$(grep -e "%  " alexa.temp | colrm 10 | tr -d ":[[:blank:]]:" | sed "s/%//" | head -1)
	SEARCH=$(grep -e "%  " alexa.temp | colrm 10 | tr -d ":[[:blank:]]:" | sed "s/%//" | tail -1)
	ALEXARANK=$(grep -e "  </strong>" alexa.temp | colrm 15 | tr -d ":[[:blank:]]:" | sed 's/,//g' | head -1)
	INLINKS=$(grep "font-4 box1-r" alexa.temp | cut -d '>' -f2 | cut -d '<' -f1 | sed 's/,//g')

	rm alexa.temp

					
	SOV=$(echo -e "scale=5; ($TOTALIP / 23000)" | bc)
	QUALITY=$(echo -e "scale=3; l($BOUNCE * $SEARCH)" | bc -l)
	IPS=$(echo -e "scale=3; ($UNIQUEIP / $TOTALIP)" | bc)
	RANK=$(echo -e "scale=3; ($ALEXARANK /$N)" | bc)
	TRUST=$(echo -e "scale=3; l(l($TRUST * $VOTES) * $TRUST)^2" | bc -l)
	TWUNIQ=$(echo -e "scale=3; ($TWTOTAL / $TWUNIQUE)" | bc)
	TWSCORE=$(echo -e "scale=3; l($FOLLOWERS / $TWEETS)" | bc -l)
	TWENTROPY=$(echo -e "scale=3; l($TWENTROPY * 1)" | bc -l)
	ENTROPY=$(echo "$ENTROPY")
	SPEARMAN=$(echo "$SPEARMAN")
				
	echo -e "$DOMAIN,$SOV,$RANK,$IPS,$SPEARMAN,$TWSCORE,$TWENTROPY,$TWUNIQ,$TRUST,$ENTROPY,$QUALITY" | sed -e "s/,,/,NA,/g" >> indexer.output

done <master.input

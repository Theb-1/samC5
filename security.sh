#!/opt/bin/bash

c5_ip=192.168.1.15
c5_port=8899
primary_phone=1112223333
alert_emails=( "youremail@gmail.com" "$primary_phone@vtext.com" )

NETCAT=/opt/bin/nc
SOCAT=/opt/bin/socat
MSMTP=/opt/bin/msmtp

# Example commands:
#
# update phone numbers
#echo -e \\r\\n+CMT: \"+1$primary_phone\",\"\",\"01/01/01,15:52:50-28\"\\r\\nTel: \\r\\n2.$primary_phone\\r | $NETCAT -q 1 $c5_ip $c5_port
#
# disarm(0)/arm(1)/home(2):
#echo -e \\r\\n+CMT: \"+1$primary_phone\",\"\",\"01/01/01,15:52:50-28\"\\r\\n0\\r | $NETCAT -q 1 $c5_ip $c5_port
#echo -e \\r\\n+CMT: \"+1$primary_phone\",\"\",\"01/01/01,15:52:50-28\"\\r\\n1\\r | $NETCAT -q 1 $c5_ip $c5_port
#echo -e \\r\\n+CMT: \"+1$primary_phone\",\"\",\"01/01/01,15:52:50-28\"\\r\\n2\\r | $NETCAT -q 1 $c5_ip $c5_port
#
# rfid stuff
#echo -e \\r\\n+CMT: \"+1$primary_phone\",\"\",\"01/01/01,15:52:50-28\"\\r\\nChange RFID tags SMS notice:\\r\\n1.RFID: Name\\r | $NETCAT -q 1 $c5_ip $c5_port
#echo -e \\r\\n+CMT: \"+1$primary_phone\",\"\",\"01/01/01,15:52:50-28\"\\r\\nSMS No. for RFID tags\(0-20 digits\): \\r\\n1.$primary_phone\\r | $NETCAT -q 1 $c5_ip $c5_port
#
# get status:
#echo -e \\r\\n+CMT: \"+1$primary_phone\",\"\",\"01/01/01,15:52:50-28\"\\r\\n00\\r | $NETCAT -q 1 $c5_ip $c5_port
#
# misc:
#echo -e \\r\\n+CMT: \"+1$primary_phone\",\"\",\"01/01/01,15:52:50-28\"\\r\\nSiren volume\(0 Mute, 1 Low, 2 High\):0\\r | $NETCAT -q 1 $c5_ip $c5_port
#echo -e \\r\\n+CMT: \"+1$primary_phone\",\"\",\"01/01/01,15:52:50-28\"\\r\\nExit delay time\(0-300sec\): 35\\r | $NETCAT -q 1 $c5_ip $c5_port
#echo -e \\r\\n+CMT: \"+1$primary_phone\",\"\",\"01/01/01,15:52:50-28\"\\r\\nEntry delay time\(0-300sec\): 25\\r | $NETCAT -q 1 $c5_ip $c5_port

function send {
	echo -e -n "\\r\\n$1\\r" | $NETCAT -q 1 $c5_ip $c5_port
	echo "> $1"
}

function sendRaw {
	echo -e -n "\\r\\n$1" | $NETCAT -q 1 $c5_ip $c5_port
	echo "> $1"
}

while true; do
	RESULT=$($SOCAT -T60 TCP:$c5_ip:$c5_port,escape=0x0d STDOUT)
	if [ "$RESULT" ]; then
		echo \< $RESULT
		
		if [ "$RESULT" == "AT+CREG?" ]; then
			send "+CREG: 0,1"
			send "OK"
		elif grep -q "T+CMGS="<<<$RESULT; then
			sendRaw ">"
			
			PHONE=${RESULT:10:10}
			
			MSG=$($SOCAT -T60 TCP:$c5_ip:$c5_port,escape=0x1a STDOUT)
			echo -e "< \n$MSG"
			
			if [ "$PHONE" != "0000000000" ]; then
				for email in "${alert_emails[@]}"; do
					{ echo Subject: ALARM SYSTEM; echo "$MSG"; } | $MSMTP $email
				done
			fi
			
			send "+CMGS: 0"
			send "OK"
		elif [ "$RESULT" == "AT+CLCC" ]; then
			send "+CLCC: 1,0,0,0,0,\"$primary_phone\",0"
			#echo -e \\r\\n+CLCC: 1,0,0,0,0,\"$primary_phone\",129\\r | $NETCAT -q 1 $c5_ip $c5_port
		else
			send "OK"
		fi
	fi
done

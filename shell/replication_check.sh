date; elinks -dump-width 1024 "`links http:localhost:20000 | awk '/master/{print $2}' |sed 's/master//'`replicationz" > /tmp/replicaitons.txt && awk '/Replication SubTasks/,/Replication Tasks/ {print $2,$6}' /tmp/replicaitons.txt | sort | uniq -c | egrep 'k(Accept|Start)' | sed 's/kAccepted/Running Replications/g; s/kStarted/Queued Replications/g' | sort

Pend=`cat /tmp/replicaitons.txt | egrep 'k(Started)'| cut -d "k" -f2 | awk '{print $2,$3,$4,$5}'| sort -k2,2r -k1,1n -k3,3n | tail -1`
Run=`cat /tmp/replicaitons.txt | egrep 'k(Accepted)'| cut -d "k" -f2 | awk '{print $2,$3,$4,$5}'| sort -k2,2r -k1,1n -k3,3n | tail -1`
runsnx=`cat /tmp/replicaitons.txt | grep asx1 | egrep 'k(Accepted)' | cut -d "k" -f2 | awk '{print $2,$3,$4,$5}' | sort -k2,2r -k1,1n -k3,3n | tail -1`
pendsnx=`cat /tmp/replicaitons.txt | grep asx1 | egrep 'k(Started)' | cut -d "k" -f2 | awk '{print $2,$3,$4,$5}' | sort -k2,2r -k1,1n -k3,3n | tail -1`

nsasx1=`cat /tmp/replicaitons.txt | grep asx1 | egrep 'k(Accepted)' | grep "0," | wc -l`


echo ""
echo "Replications pending start by target:"
echo "asx1dragcl-az replications = " $nsasx1
echo ""
echo "Oldest by Target:"
if [[ -z $runsnx  ]]; then

        echo "Oldest Running Replication asx1 =  None"  
else
        echo "Oldest Running Replication asx1 = " $runsnx 
fi

if [[ -z $pendsnx ]]; then

        echo "Oldest Pending Replication asx1 =  None" 
else
        echo "Oldest Pending Replication asx1 = " $pendsnx 

fi

echo""
echo "Total Oldest by Cluster:"
echo "Oldest Replication Pending = " $Pend
echo "Oldest Replication Running = " $Run

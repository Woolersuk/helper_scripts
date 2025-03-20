alias awscur="aws sts get-caller-identity"
alias awslp="aws configure list-profiles"
alias awsq="aws configure list"
alias awswho="aws configure list"

function insid() {
    local QUERY='Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,PublicIpAddress,State.Name,Tags[?Key==`Name`]| [0].Value]'
    if [[ $1 =~ ^i- ]]; then
        # If argument looks like an instance ID (starts with "i-")
        aws ec2 describe-instances --instance-ids "$1" --query "$QUERY" --output text
    else
        # If argument is not an instance ID, assume it's a Name tag
        aws ec2 describe-instances --filters "Name=tag:Name,Values=$1" --query "$QUERY" --output text
    fi
}


function instag() {
    local TAG="${2:-Name}"
    local VALUE="${1:-*}"
    local QUERY='Reservations[*].Instances[*].[InstanceId,Placement.AvailabilityZone,InstanceType,Platform,LaunchTime,PrivateIpAddress,PublicIpAddress,State.Name,Tags[?Key==`Name`]| [0].Value]'
    local RESULT=$(aws ec2 describe-instances --filters "Name=tag:$TAG,Values=$VALUE" --query "$QUERY" --output text)
    if [[ -z "$RESULT" ]]; then
        echo "No instances found for tag $TAG=$VALUE"
    else
        echo "$RESULT"
    fi
}

function inssec() {
  local INSID=$1
  local SUMMARY=$2
  SGIDS=$(aws ec2 describe-instances --instance-ids $INSID --query 'Reservations[*].Instances[*].NetworkInterfaces[*].Groups[*].GroupId' --output text)
  echo "instance $INSID has security groups\n$SGIDS"
  for i in $SGIDS; do
    echo "rules for $i"
    aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$i" --query 'SecurityGroupRules[*].[IsEgress,FromPort,ToPort,CidrIpv4,Description]' --output text | \
      awk '$1 == "False"' | \
      cut -f2- | \
      sed '1i FromPort ToPort CidrIpv4 Description' | \
      column --table
    # inssec i-0cbffe08369061686 | grep -v "rules for sg-\|FromPort.*ToPort.*CidrIpv4\|instance.*i-" | grep . | awk '{print $1, $2, $3}' | sort -u | column --table
    echo
  done | grep -v "rules for sg-\|FromPort.*ToPort.*CidrIpv4\|instance.*i-" | grep . | awk '{print $1, $2, $3}' | sort -u | column --table
}


alias ssm="aws ssm start-session --target $i"

function sst() {
  IFS=$'\n'
  echo "logging you into these instances"
  NAME="'*$1*'"
  instag $NAME | grep running
  INSID=$(instag $NAME | grep running | cut -f1)
  for i in $(instag $NAME | grep running); do
    echo "logging you into $i"
    ssm $(echo $i | cut -f1)
  done
}

function lins() {
  aws ec2 describe-instances --filter "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,PublicIpAddress,State.Name,Tags[?Key==`Name`]| [0].Value]' --output text | column -t
}

function lssec() {
  aws secretsmanager list-secrets --query 'SecretList[].[Name,ARN]' --output text | column -t
}

function getsec() {
  for i in $(aws secretsmanager list-secrets --query 'SecretList[].[Name,ARN]' --output text | column -t | grep $1 | awk '{print $2}'); do
    echo Secret: $(echo $i | sed 's/.*://g')
    aws secretsmanager get-secret-value --secret-id $i --query 'SecretString' --output text | sed 's/\\//g' | jq | grep -v '{\|}' | sed 's/"//g;s/://g;s/,//g;s/  //g' | column -t -s ' '
    echo
  done
}

function awsp() {
	export AWS_PROFILE=$1
}

function taws() {
  if [ !  -z "$1" ]
  then
    export AWS_ACCESS_KEY_ID=$1
    export AWS_SECRET_ACCESS_KEY=$2
  else
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
  fi
}
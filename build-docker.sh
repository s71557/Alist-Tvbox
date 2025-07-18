set -e

BASE_DIR=/opt/alist
PORT1=4567
PORT2=5344
MOUNT=""

while getopts ":d:p:P:v:" arg; do
    case "${arg}" in
        d)
            BASE_DIR=${OPTARG}
            ;;
        p)
            PORT1=${OPTARG}
            ;;
        P)
            PORT2=${OPTARG}
            ;;
        v)
            MOUNT="${MOUNT} -v ${OPTARG}"
            ;;
        *)
            ;;
    esac
done

shift $((OPTIND-1))

if [ $# -gt 0 ]; then
  BASE_DIR=$1
fi

if [ $# -gt 1 ]; then
	PORT1=$2
fi

if [ $# -gt 2 ]; then
	PORT2=$3
fi

if [ $# -gt 3 ]; then
	MEM_OPT="-Xmx${4}M"
	echo "Java Memory: ${MEM_OPT}"
fi

rm -rf src/main/resources/static/assets && \
cd web-ui && \
npm run build || exit 1
cd ..

#cp src/main/resources/application.yaml application-backup.yaml
#sed -i '/- name: 本地/,+2d' src/main/resources/application.yaml
#sed -i '/sites:/r add.txt' src/main/resources/application.yaml

mvn clean package || exit 1
cd target && java -Djarmode=layertools -jar alist-tvbox-1.0.jar extract && cd ..

#mv application-backup.yaml src/main/resources/application.yaml

export TZ=Asia/Shanghai
echo $((($(date +%Y) - 2023) * 366 + $(date +%j | sed 's/^0*//'))).$(date +%H%M) > data/version
echo "build haroldli/alist-tvbox:latest"
docker build -f docker/Dockerfile --tag=haroldli/alist-tvbox:latest .

echo -e "\e[36m使用配置目录：\e[0m $BASE_DIR"
echo -e "\e[36m端口映射：\e[0m $PORT1:4567  $PORT2:5244"

sudo systemctl stop atv

docker rm -f xiaoya-tvbox alist-tvbox 2>/dev/null
docker run -d -p $PORT1:4567 -p $PORT2:5244 -e ALIST_PORT=$PORT2 -e INSTALL=new -v "$BASE_DIR":/data -v "$BASE_DIR/alist":/opt/alist/data ${MOUNT} --name=alist-tvbox haroldli/alist-tvbox:latest

sleep 1

IP=$(ip a | grep -F '192.168.' | awk '{print $2}' | awk -F/ '{print $1}' | head -1)
if [ -n "$IP" ]; then
  echo -e "\e[32m请用以下地址访问：\e[0m"
  echo -e "    \e[32m管理界面\e[0m： http://$IP:$PORT1/"
  echo -e "    \e[32mAList\e[0m： http://$IP:$PORT2/"
else
  echo -e "\e[32m云服务器请用公网IP访问\e[0m"
fi
echo ""

docker logs -f alist-tvbox

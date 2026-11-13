#!/usr/bin/env bash
# =============================================================================
#  lab — lệnh tắt điều khiển cụm CT482 (môi trường bigdata-lab) trong codespace
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
cd "$ROOT"
_UP="${UPSTREAM_REPO:-}"   # biến môi trường được ưu tiên hơn cau-hinh.env (thử với repo khác)
set -a; . .devcontainer/cau-hinh.env 2>/dev/null; set +a
[ -n "$_UP" ] && UPSTREAM_REPO="$_UP"
CORE=(-f docker-compose.yml)
ALL=(-f docker-compose.yml -f docker-compose.extras.yml)
EXTRAS=(hiveserver2 hive-metastore hive-metastore-db kafka hbase mongodb)
# Tệp môi trường lấy từ repo gốc khi chạy `lab update` (KHÔNG đụng src/, data/ — bài làm của sinh viên)
TEP_MOI_TRUONG=(.devcontainer docker-compose.yml docker-compose.extras.yml docker-compose.noports.yml
                docker-compose.extras.noports.yml scripts-host conf/hive huong-dan HUONG-DAN-CODESPACES.md)

extras_buoi() {  # extras_buoi <N> → dịch vụ bổ sung cần cho Buổi N (rỗng = chỉ cụm lõi)
  case "$1" in
    0|1|2|5|7) echo "" ;;
    3) echo "hiveserver2 hive-metastore hive-metastore-db" ;;
    4) echo "hbase mongodb" ;;
    6) echo "kafka" ;;
    *) return 1 ;;
  esac
}

extras_dang_chay() {  # các dịch vụ bổ sung đang chạy (kể cả đang restart), cách nhau bởi dấu cách
  docker compose "${ALL[@]}" ps --services 2>/dev/null | grep -xE "$(IFS='|'; echo "${EXTRAS[*]}")" | xargs
}

tat_extras() {  # tat_extras [dịch vụ...] — mặc định: mọi dịch vụ bổ sung
  local ds=("$@"); [ ${#ds[@]} -eq 0 ] && ds=("${EXTRAS[@]}")
  if printf '%s\n' "${ds[@]}" | grep -qx hiveserver2; then
    # Tez (Hive) để lại hàng GB dữ liệu tạm trong container hiveserver2 — dọn trước khi dừng
    docker exec hiveserver2 bash -c 'rm -rf /tmp/hive/hive/_tez_session_dir/*' 2>/dev/null
  fi
  # HBase cần > 10 s để đóng region/WAL gọn gàng; quá hạn mặc định Docker sẽ kill -9 (Exited 137)
  docker compose "${ALL[@]}" stop -t 60 "${ds[@]}"
}

bat_hive()  { lan_dau apache/hive:4.2.1 "4 GB"; lan_dau postgres:16 "0,6 GB"
              docker compose "${ALL[@]}" up -d --no-build --wait --wait-timeout 420 hiveserver2; }
bat_nosql() { lan_dau mongo:8.0 "1,3 GB"
              docker compose "${ALL[@]}" up -d --no-build --wait --wait-timeout 300 hbase mongodb; }
bat_kafka() { lan_dau apache/kafka:4.3.1 "0,7 GB"
              docker compose "${ALL[@]}" up -d --no-build --wait --wait-timeout 300 kafka; }

buoi() {  # buoi <N>: bật cụm lõi + đúng dịch vụ bổ sung của Buổi N, tắt dịch vụ bổ sung không dùng
  local n="${1:-}" can dang s tat=()
  can=$(extras_buoi "$n") || { echo "Dùng: lab buoi <0-7>   (ví dụ: lab buoi 3)"; return 1; }
  dang=" $(extras_dang_chay) "
  for s in "${EXTRAS[@]}"; do
    [[ " $can " != *" $s "* && "$dang" == *" $s "* ]] && tat+=("$s")
  done
  if [ ${#tat[@]} -gt 0 ]; then echo "Tắt dịch vụ Buổi $n không dùng: ${tat[*]}"; tat_extras "${tat[@]}"; fi
  echo "Bật cụm lõi (HDFS, YARN, Spark)..."
  docker compose "${CORE[@]}" up -d --no-build --wait --wait-timeout 300 || return 1
  case "$n" in 3) bat_hive ;; 4) bat_nosql ;; 6) bat_kafka ;; esac || return 1
  echo "Buổi $n sẵn sàng: cụm lõi${can:+ + $can}."
}

cap_nhat() {  # lấy bản mới của các tệp môi trường từ repo gốc của giảng viên
  local src="${UPSTREAM_REPO:-https://github.com/tttquyen/bigdatalab.git}" f co=() dang
  echo "Tải bản mới của môi trường từ $src ..."
  git fetch --quiet "$src" main || { echo "Không tải được (kiểm tra mạng / tên repo)."; return 1; }
  for f in "${TEP_MOI_TRUONG[@]}"; do git cat-file -e "FETCH_HEAD:$f" 2>/dev/null && co+=("$f"); done
  git checkout FETCH_HEAD -- "${co[@]}" || return 1
  if git diff --cached --quiet -- "${co[@]}"; then echo "Môi trường đã là bản mới nhất."; return 0; fi
  echo "Đã cập nhật:"; git diff --cached --stat -- "${co[@]}" | tail -n 15
  # Tạo lại các container đang chạy có cấu hình thay đổi (dữ liệu trong volume giữ nguyên)
  dang=$(docker compose "${ALL[@]}" ps --services 2>/dev/null | xargs)   # xargs: bỏ dòng trống (rỗng thật sự khi không có container)
  [ -n "$dang" ] && docker compose "${ALL[@]}" up -d --no-build $dang
  echo "Lưu lại vào repo của bạn (tuỳ chọn): git commit -m 'Cập nhật môi trường' && git push"
}

url() {  # url <cổng> → đường dẫn mở được trong trình duyệt
  if [ -n "${CODESPACE_NAME:-}" ]; then
    echo "https://${CODESPACE_NAME}-$1.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
  else echo "http://localhost:$1"; fi
}

ram_may() {  # RAM của máy codespace (cgroup nếu bị giới hạn, không thì /proc/meminfo) — gồm cả VS Code
  local max cur
  max=$(cat /sys/fs/cgroup/memory.max 2>/dev/null); cur=$(cat /sys/fs/cgroup/memory.current 2>/dev/null)
  if [[ "$max" =~ ^[0-9]+$ && "$cur" =~ ^[0-9]+$ ]]; then
    # bỏ phần cache tệp (thu hồi được), giống cách docker stats tính
    cur=$(( cur - $(awk '$1=="file"{print $2}' /sys/fs/cgroup/memory.stat 2>/dev/null || echo 0) ))
    awk -v m="$max" -v c="$cur" 'BEGIN{printf "RAM máy codespace: dùng %.1f / %.1f GB\n", c/1073741824, m/1073741824}'
  else
    awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "RAM máy codespace: dùng %.1f / %.1f GB\n", (t-a)/1048576, t/1048576}' /proc/meminfo
  fi
}

lan_dau() {  # lan_dau <image> <dung lượng> — nhắc khi image dịch vụ bổ sung chưa có (lần bật đầu tiên)
  docker image inspect "$1" >/dev/null 2>&1 || echo "Lần đầu: tải image $1 (~$2), có thể mất vài phút..."
}

case "${1:-help}" in
  start)   docker compose "${CORE[@]}" up -d --no-build --wait --wait-timeout 300 ;;
  buoi)    buoi "${2:-}" ;;
  hive)    bat_hive ;;
  nosql)   bat_nosql ;;
  kafka)   bat_kafka ;;
  update)  cap_nhat ;;
  extras)
    mem_gb=$(awk '/MemTotal/{printf "%d", $2/1048576}' /proc/meminfo)
    if [ "${mem_gb:-0}" -lt 12 ]; then
      echo "CẢNH BÁO: máy có ~${mem_gb} GB RAM. Bật cùng lúc mọi dịch vụ bổ sung chỉ còn ~2 GB trống,"
      echo "job Spark có thể lỗi ngẫu nhiên. Nên bật theo bài: lab hive | lab nosql | lab kafka."
      echo "Vẫn bật tất cả sau 5 giây (Ctrl+C để huỷ)..."; sleep 5
    fi
    docker compose "${ALL[@]}" up -d --wait --wait-timeout 420 ;;
  stop-extras) tat_extras ;;
  stop)    docker compose "${ALL[@]}" stop ;;
  status)
    docker compose "${ALL[@]}" ps --format 'table {{.Name}}\t{{.Status}}'
    echo
    loop=$(docker compose "${ALL[@]}" ps --status restarting --services 2>/dev/null | xargs)
    [ -n "$loop" ] && echo "CẢNH BÁO: container đang khởi động lại liên tục: $loop → xem: docker logs --tail 50 <tên>"
    ex=$(extras_dang_chay)
    [ -n "$ex" ] && echo "Dịch vụ bổ sung đang bật: $ex — không dùng ở buổi này thì gõ: lab buoi <N> (hoặc lab stop-extras)"
    r=$(docker exec namenode hdfs dfsadmin -report 2>/dev/null); echo "$r" | grep -q "Live datanodes" \
      && echo "HDFS: $(echo "$r" | grep -m1 'Live datanodes')" || echo "HDFS: chưa chạy"
    r=$(docker exec resourcemanager yarn node -list 2>/dev/null); echo "$r" | grep -q "Total Nodes" \
      && echo "YARN: $(echo "$r" | grep -m1 'Total Nodes')" || echo "YARN: chưa chạy"
    docker stats --no-stream --format '{{.MemUsage}}' 2>/dev/null | awk '{v=$1; u=v; gsub(/[0-9.]/,"",u); gsub(/[A-Za-z]/,"",v);
      if(u=="GiB")v*=1024; else if(u=="KiB")v/=1024; else if(u=="B")v/=1048576; s+=v} END{printf "RAM các container: %.1f GB\n", s/1024}'
    ram_may
    docker system df --format '{{.Size}}' 2>/dev/null | awk '{v=$1; u=v; gsub(/[0-9.]/,"",u); gsub(/[A-Za-z]/,"",v);
      if(u=="MB")v/=1000; else if(u=="kB")v/=1e6; else if(u=="B")v/=1e9; else if(u=="TB")v*=1000; s+=v}
      END{printf "Đĩa Docker (image + volume + container): %.1f GB\n", s}'
    n=$(( $(wc -l < data/retail_transactions.csv 2>/dev/null || echo 1) - 1 ))
    if [ "$n" -ge 5000000 ]; then echo "Dữ liệu mẫu: $n giao dịch"
    else echo "Dữ liệu mẫu: $n giao dịch — các bài dùng 5 triệu dòng, chạy: lab data 5000000"; fi
    ;;
  ui)
    printf '%-24s %s\n' "HDFS NameNode" "$(url 9870)" "YARN ResourceManager" "$(url 8088)" \
      "Spark Master" "$(url 8080)" "Spark UI (job đang chạy)" "$(url 4040)" \
      "Spark History" "$(url 18080)" "MapReduce JobHistory" "$(url 19888)" \
      "HiveServer2 UI" "$(url 10002)" "HBase Master" "$(url 16010)" \
      "HBase RegionServer" "$(url 16030)" "NodeManager 1" "$(url 8042)" "NodeManager 2" "$(url 8043)" \
      "DataNode 1" "$(url 9864)" "DataNode 2" "$(url 9865)"
    if [ -n "${CODESPACE_NAME:-}" ]; then echo "(Hoặc mở tab PORTS bên cạnh TERMINAL, bấm biểu tượng quả địa cầu.)"; fi ;;
  test)    bash scripts-host/smoke_test.sh ;;
  data)
    if command -v python3 >/dev/null; then python3 gen_data.py --rows "${2:-200000}" --out ./data
    else docker run --rm --entrypoint python3 --user "$(id -u):$(id -g)" -v "$ROOT":/w -w /w bigdata-lab:2026.10 \
           gen_data.py --rows "${2:-200000}" --out ./data; fi ;;
  reset)
    read -r -p "XOÁ TOÀN BỘ dữ liệu HDFS/Hive/Kafka/HBase/MongoDB? Gõ 'xoa' để xác nhận: " a
    [ "$a" = "xoa" ] && docker compose "${ALL[@]}" down -v && echo "Đã xoá. Gõ: lab start" || echo "Huỷ." ;;
  *)
    cat <<'H'
Các lệnh:
  lab buoi N       bật ĐÚNG dịch vụ của Buổi N (0–7), tắt dịch vụ bổ sung không dùng — nên dùng đầu mỗi buổi
                   Buổi 0,1,2,5,7: cụm lõi · Buổi 3: + Hive · Buổi 4: + HBase, MongoDB · Buổi 6: + Kafka
  lab start        bật cụm lõi (HDFS, YARN, Spark) — tự chạy khi mở codespace
  lab hive         bật Hive (Lab 3)          lab nosql   bật HBase + MongoDB (Lab 4)
  lab kafka        bật Kafka (Lab 6)         lab extras  bật tất cả dịch vụ bổ sung
  lab stop-extras  tắt dịch vụ bổ sung để giải phóng RAM
  lab update       lấy bản sửa lỗi môi trường mới nhất từ repo của giảng viên (không đụng src/, data/)
  lab stop         dừng mọi container (GIỮ dữ liệu)
  lab status       trạng thái container, HDFS, YARN, RAM
  lab ui           đường dẫn Web UI
  lab test         chạy smoke test toàn cụm
  lab data [N]     sinh lại dữ liệu mẫu N dòng (mặc định 200000)
  lab reset        xoá sạch dữ liệu cụm, làm lại từ đầu
Các lệnh trong README.md (docker exec -it namenode bash, ...) dùng nguyên như cũ.
H
    ;;
esac

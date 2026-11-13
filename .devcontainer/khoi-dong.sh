#!/usr/bin/env bash
# khoi-dong.sh — chạy MỖI LẦN codespace khởi động (postStartCommand): bật cụm lõi nếu AUTO_START=core
set -uo pipefail
cd "$(dirname "$0")/.."
set -a; . .devcontainer/cau-hinh.env 2>/dev/null; set +a
. .devcontainer/docker-san-sang.sh
cho_docker || { echo "[khoi-dong] Docker không chạy (xem /tmp/dockerd.log)"; exit 0; }
# Dịch vụ bổ sung có restart: unless-stopped → nếu lần trước còn bật lúc codespace dừng, Docker tự bật lại
# cả 6 container (Hive, HBase, MongoDB, Kafka...) dù buổi này không dùng. Tắt chúng; sinh viên bật lại theo
# bài bằng `lab buoi <N>`. Đặt KEEP_EXTRAS=1 trong cau-hinh.env để giữ nguyên như cũ.
if [ "${KEEP_EXTRAS:-0}" != "1" ]; then
  con=$(docker compose -f docker-compose.yml -f docker-compose.extras.yml ps --services 2>/dev/null \
        | grep -xE 'hiveserver2|hive-metastore|hive-metastore-db|kafka|hbase|mongodb' | tr '\n' ' ')
  if [ -n "$con" ]; then
    echo "[khoi-dong] Tắt dịch vụ bổ sung còn bật từ lần trước: $con"
    bash .devcontainer/lab.sh stop-extras >/dev/null 2>&1
    echo "[khoi-dong] Bật lại khi cần: lab buoi 3 (Hive) | lab buoi 4 (HBase, MongoDB) | lab buoi 6 (Kafka)"
  fi
fi
if [ "${AUTO_START:-core}" != "core" ]; then echo "[khoi-dong] AUTO_START=${AUTO_START} — không tự bật cụm. Gõ: lab start"; exit 0; fi
if ! docker image inspect bigdata-lab:2026.10 >/dev/null 2>&1; then
  echo "[khoi-dong] Chưa có image (khoi-tao.sh chưa xong hoặc lỗi). Xem log tạo codespace."; exit 0
fi
echo "[khoi-dong] Bật cụm lõi Hadoop/Spark..."
docker compose up -d --no-build --wait --wait-timeout 300 \
  && echo "[khoi-dong] Cụm đã sẵn sàng. Gõ 'lab ui' để lấy đường dẫn Web UI." \
  || echo "[khoi-dong] Cụm chưa healthy hết — gõ 'lab status' để kiểm tra."

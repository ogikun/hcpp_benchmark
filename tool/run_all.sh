#!/usr/bin/env bash
# 記事の「計測結果」の表と同じ 13 条件をまとめて計測する。
# 使い方: tool/run_all.sh [繰り返し回数(既定 1)]
# 終わったら `dart run tool/summarize.dart` で表の行を出力する。
set -euo pipefail
cd "$(dirname "$0")/.."

repeat="${1:-1}"

# 名前 フレーバー PV_MODE PV_KIND 負荷(ms)
# hcpp フレーバーでは PV_MODE=hybrid もエンジンが HCPP に切り替える
conditions=(
  "tlhc_view_load0    legacy textureLayer animated 0"
  "hc_view_load0      legacy hybrid       animated 0"
  "hcpp_view_load0    hcpp   hybrid       animated 0"
  "tlhc_view_load4    legacy textureLayer animated 4"
  "hc_view_load4      legacy hybrid       animated 4"
  "hcpp_view_load4    hcpp   hybrid       animated 4"
  "tlhc_view_load8    legacy textureLayer animated 8"
  "hc_view_load8      legacy hybrid       animated 8"
  "hcpp_view_load8    hcpp   hybrid       animated 8"
  "hc_surface_load0   legacy hybrid       surface  0"
  "hcpp_surface_load0 hcpp   hybrid       surface  0"
  "hc_surface_load8   legacy hybrid       surface  8"
  "hcpp_surface_load8 hcpp   hybrid       surface  8"
)

for ((i = 1; i <= repeat; i++)); do
  for c in "${conditions[@]}"; do
    read -r name flavor mode kind load <<<"$c"
    echo "=== [$i/$repeat] $name"
    SUMMARY_NAME="${name}_run$i" flutter drive --no-dds --profile --flavor "$flavor" \
      --driver=test_driver/perf_driver.dart \
      --target=integration_test/scroll_perf_test.dart \
      --dart-define=PV_MODE="$mode" \
      --dart-define=PV_KIND="$kind" \
      --dart-define=MAIN_THREAD_LOAD_MS="$load" \
      --dart-define=OVERLAY=true \
      --dart-define=DURATION_SEC=15
  done
done

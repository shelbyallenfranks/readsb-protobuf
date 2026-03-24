#!/usr/bin/env bash
set -euo pipefail

isSet() { [[ -n "${1:-}" ]]; }
isTrue() { isSet "${1:-}" && [[ "${1,,}" == 'true' || "${1,,}" == '1' ]]; }
fatal() { printf -- 'fatal: %s\n' "${1?error message required}" >&2; exit 1; }

READSB_HTTP_PORT="${READSB_HTTP_PORT:-8080}"
READSB_WRITE_OUTPUT_PATH="${READSB_WRITE_OUTPUT_PATH:-/run/readsb}"

READSB_ARGS=('--quiet')

if isSet "${READSB_DEVICE_TYPE:-}"; then
  READSB_ARGS+=("--device-type=${READSB_DEVICE_TYPE}")
else
  fatal 'no device type set'
fi

case "$READSB_DEVICE_TYPE" in
  rtlsdr)
    if isSet "${READSB_RTLSDR_DEVICE:-}"; then
      READSB_ARGS+=("--device=${READSB_RTLSDR_DEVICE}")
    else
      fatal 'cannot locate RTL-SDR device without a device index or serial'
    fi
    isTrue "${READSB_RTLSDR_ENABLE_AGC:-}" && READSB_ARGS+=('--enable-agc')
    isSet "${READSB_RTLSDR_PPM:-}"         && READSB_ARGS+=("--ppm=${READSB_RTLSDR_PPM}")
    ;;
  bladerf)
    if isSet "${READSB_BLADERF_DEVICE:-}"; then
      READSB_ARGS+=("--device=${READSB_BLADERF_DEVICE}")
    else
      fatal 'cannot locate bladeRF device without a device identifier'
    fi
    isSet "${READSB_BLADERF_BANDWIDTH:-}"  && READSB_ARGS+=("--bladerf-bandwidth=${READSB_BLADERF_BANDWIDTH}")
    isSet "${READSB_BLADERF_DECIMATION:-}" && READSB_ARGS+=("--bladerf-decimation=${READSB_BLADERF_DECIMATION}")
    isSet "${READSB_BLADERF_FPGA:-}"       && READSB_ARGS+=("--bladerf-fpga=${READSB_BLADERF_FPGA}")
    ;;
  modesbeast)
    if isSet "${READSB_BEAST_SERIAL:-}"; then
      READSB_ARGS+=("--beast-serial=${READSB_BEAST_SERIAL}")
    else
      fatal 'cannot locate Mode-S Beast device without a serial device path'
    fi
    isTrue "${READSB_BEAST_CRC_OFF:-}"   && READSB_ARGS+=('--beast-crc-off')
    isTrue "${READSB_BEAST_DF045_ON:-}"  && READSB_ARGS+=('--beast-df045-on')
    isTrue "${READSB_BEAST_DF1117_ON:-}" && READSB_ARGS+=('--beast-df1117-on')
    isTrue "${READSB_BEAST_FEC_OFF:-}"   && READSB_ARGS+=('--beast-fec-off')
    isTrue "${READSB_BEAST_MLAT_OFF:-}"  && READSB_ARGS+=('--beast-mlat-off')
    isTrue "${READSB_BEAST_MODEAC:-}"    && READSB_ARGS+=('--beast-modeac')
    ;;
  gnshulc)
    if isSet "${READSB_BEAST_SERIAL:-}"; then
      READSB_ARGS+=("--beast-serial=${READSB_BEAST_SERIAL}")
    else
      fatal 'cannot locate GNS HULC device without a serial device path'
    fi
    ;;
  plutosdr)
    isSet "${READSB_PLUTO_NETWORK:-}" && READSB_ARGS+=("--pluto-network=${READSB_PLUTO_NETWORK}")
    isSet "${READSB_PLUTO_URI:-}"     && READSB_ARGS+=("--pluto-uri=${READSB_PLUTO_URI}")
    ;;
  *)
    fatal 'invalid device type'
esac

if isTrue "${READSB_WRITE_OUTPUT:-true}"; then
  READSB_ARGS+=("--write-output=${READSB_WRITE_OUTPUT_PATH}")
  if isSet "${READSB_WRITE_OUTPUT_INTERVAL:-}"; then
    READSB_ARGS+=("--write-output-every=${READSB_WRITE_OUTPUT_INTERVAL}")
  else
    READSB_ARGS+=("--write-output-every=1")
  fi
fi

isTrue "${READSB_FIX:-}"          && READSB_ARGS+=('--fix')
isTrue "${READSB_DCFILTER:-}"     && READSB_ARGS+=('--dcfilter')
isTrue "${READSB_FORWARD_MLAT:-}" && READSB_ARGS+=('--forward-mlat')

if isSet "${READSB_GAIN:-}"; then
  if [[ "$READSB_GAIN" == 'autogain' ]]; then
    READSB_ARGS+=("--gain=-10")
  else
    READSB_ARGS+=("--gain=${READSB_GAIN}")
  fi
fi

isSet "${READSB_LAT:-}"                  && READSB_ARGS+=("--lat=${READSB_LAT}")
isSet "${READSB_LON:-}"                  && READSB_ARGS+=("--lon=${READSB_LON}")
isSet "${READSB_RX_LOCATION_ACCURACY:-}" && READSB_ARGS+=("--rx-location-accuracy=${READSB_RX_LOCATION_ACCURACY}")

if isTrue "${READSB_NET_ENABLE:-true}"; then
  READSB_ARGS+=('--net')
  READSB_ARGS+=("--net-bind-address=${READSB_BIND_ADDRESS:-0.0.0.0}")
  READSB_ARGS+=("--net-ri-port=${READSB_RAW_INPUT_PORT:-30001}")
  READSB_ARGS+=("--net-ro-port=${READSB_RAW_OUTPUT_PORT:-30002}")
  READSB_ARGS+=("--net-sbs-port=${READSB_BASESTATION_OUTPUT_PORT:-30003}")
  READSB_ARGS+=("--net-bi-port=${READSB_BEAST_INPUT_PORT:-30004}")
  READSB_ARGS+=("--net-bo-port=${READSB_BEAST_OUTPUT_PORT:-30005}")
fi

if isTrue "${READSB_HTTP_ENABLE:-true}"; then
  printf -- 'Starting HTTP server on port: %d\n' "$READSB_HTTP_PORT"
  export READSB_WRITE_OUTPUT_PATH READSB_HTTP_PORT
  lighttpd -f /dev/stdin << EOF
server.document-root = env.READSB_WRITE_OUTPUT_PATH
server.port = env.READSB_HTTP_PORT
mimetype.assign = (".pb" => "application/protobuf", "" => "application/octet-stream")
EOF
fi

printf -- 'Starting readsb with args: %s\n' "${READSB_ARGS[*]}"

exec /usr/local/bin/readsb "${READSB_ARGS[@]}"

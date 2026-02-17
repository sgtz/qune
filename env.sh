# qdust environment — sourced by the qdust wrapper before Q detection.
# All variables are optional. Sensible defaults are derived at runtime.

# --- Q installation ---

# Base directory of Q installation (e.g. ~/q). If set, QHOME and QDUST_Q
# are derived from it using detected OS and optional version.
# export QDUST_Q_HOME_BASE="$HOME/q"

# Q version subdirectory (e.g. "4.1"). Only used when QDUST_Q_HOME_BASE is set.
# Layout: $QDUST_Q_HOME_BASE/$QVER/$QARCH/q  (versioned)
#     or: $QDUST_Q_HOME_BASE/$QARCH/q         (flat, no QVER)
# export QVER=""

# Explicit Q executable path. Overrides all auto-detection.
# export QDUST_Q="/path/to/q"

# OS detection: m=macOS, l=linux, w=windows
if [[ -z "${QOS:-}" ]]; then
  case "$(uname -s)" in
    Darwin)          QOS="m" ;;
    Linux)           QOS="l" ;;
    CYGWIN*|MINGW*)  QOS="w" ;;
    *)               QOS="l" ;;
  esac
  export QOS
fi

# Architecture detection: 64 or 32
if [[ -z "${QARCH_BITS:-}" ]]; then
  case "$(uname -m)" in
    x86_64|aarch64|arm64) QARCH_BITS="64" ;;
    *)                    QARCH_BITS="32" ;;
  esac
  export QARCH_BITS
fi

# Combined OS+arch token (e.g. m64, l64)
QARCH="${QOS}${QARCH_BITS}"
export QARCH

# Build QHOME from base + version + arch if base is set
if [[ -n "${QDUST_Q_HOME_BASE:-}" && -z "${QHOME:-}" ]]; then
  if [[ -n "${QVER:-}" ]]; then
    export QHOME="${QDUST_Q_HOME_BASE}/${QVER}/${QARCH}"
  else
    export QHOME="${QDUST_Q_HOME_BASE}/${QARCH}"
  fi
fi

# Build QDUST_Q from QHOME if not explicitly set
if [[ -z "${QDUST_Q:-}" && -n "${QHOME:-}" && -x "${QHOME}/q" ]]; then
  export QDUST_Q="${QHOME}/q"
fi

# --- rlwrap ---

# rlwrap binary path. Detected via PATH if not set.
if [[ -z "${QDUST_RLWRAP:-}" ]]; then
  QDUST_RLWRAP="$(command -v rlwrap 2>/dev/null || true)"
  export QDUST_RLWRAP
fi

# rlwrap flags. Standard Q defaults.
export QDUST_RLWRAP_OPTS="${QDUST_RLWRAP_OPTS:--A -pYELLOW -c -r -H ~/.q_history}"

# --- Debug ---

# Set to 1 to enable debug mode (equivalent to -debug flag)
# export QDUST_DEBUG=1

# export QHOME=""
# export QLIC=""

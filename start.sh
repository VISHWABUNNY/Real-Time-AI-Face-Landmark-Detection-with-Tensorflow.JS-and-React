#!/bin/bash

# ============================================================
#   🎭 Real-Time AI Face Landmark Detection
#   Startup Script | Frontend + Backend
# ============================================================

# ── Colors & Styles ──────────────────────────────────────────
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"

BG_BLACK="\033[40m"

# ── Helpers ───────────────────────────────────────────────────
print_banner() {
  echo ""
  echo -e "${BOLD}${CYAN}"
  echo "  ███████╗ █████╗  ██████╗███████╗    ███╗   ███╗███████╗███████╗██╗  ██╗"
  echo "  ██╔════╝██╔══██╗██╔════╝██╔════╝    ████╗ ████║██╔════╝██╔════╝██║  ██║"
  echo "  █████╗  ███████║██║     █████╗      ██╔████╔██║█████╗  ███████╗███████║"
  echo "  ██╔══╝  ██╔══██║██║     ██╔══╝      ██║╚██╔╝██║██╔══╝  ╚════██║██╔══██║"
  echo "  ██║     ██║  ██║╚██████╗███████╗    ██║ ╚═╝ ██║███████╗███████║██║  ██║"
  echo "  ╚═╝     ╚═╝  ╚═╝ ╚═════╝╚══════╝    ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝"
  echo -e "${RESET}"
  echo -e "  ${DIM}${WHITE}🧠 Real-Time AI Face Landmark Detection  •  TensorFlow.js + React + FastAPI${RESET}"
  echo ""
  echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

log_step()    { echo -e "  ${BOLD}${BLUE}▶${RESET}  ${BOLD}$1${RESET}"; }
log_success() { echo -e "  ${BOLD}${GREEN}✔${RESET}  $1"; }
log_warn()    { echo -e "  ${BOLD}${YELLOW}⚠${RESET}  $1"; }
log_error()   { echo -e "  ${BOLD}${RED}✘${RESET}  $1"; }
log_info()    { echo -e "  ${DIM}   $1${RESET}"; }

section() {
  echo ""
  echo -e "  ${BG_BLACK}${BOLD}${CYAN}  $1  ${RESET}"
  echo -e "  ${DIM}  ──────────────────────────────────────${RESET}"
}

spinner() {
  local pid=$1
  local msg=$2
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i+1) % 10 ))
    printf "\r  ${CYAN}${spin:$i:1}${RESET}  ${DIM}%s...${RESET}" "$msg"
    sleep 0.1
  done
  printf "\r                                          \r"
}

# ── Cleanup on Ctrl+C ────────────────────────────────────────
BACKEND_PID=""

cleanup() {
  echo ""
  echo ""
  section "🛑 Shutting Down"
  if [ -n "$BACKEND_PID" ] && kill -0 "$BACKEND_PID" 2>/dev/null; then
    kill "$BACKEND_PID" 2>/dev/null
    sleep 1
    log_success "Backend stopped (PID $BACKEND_PID)"
  fi
  # Also kill any lingering processes on ports
  for PORT in 8000 3000; do
    PIDS=$(lsof -ti tcp:$PORT 2>/dev/null)
    if [ -n "$PIDS" ]; then
      echo "$PIDS" | xargs kill -9 2>/dev/null
    fi
  done
  echo ""
  echo -e "  ${DIM}👋  Goodbye! See you next time.${RESET}"
  echo ""
  exit 0
}

trap cleanup SIGINT SIGTERM

# ── Resolve script root ───────────────────────────────────────
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
FRONTEND_DIR="$ROOT_DIR/frontend"

# ─────────────────────────────────────────────────────────────
# BANNER
# ─────────────────────────────────────────────────────────────
clear
print_banner

# ─────────────────────────────────────────────────────────────
# PRE-FLIGHT CHECKS
# ─────────────────────────────────────────────────────────────
section "🔍 Pre-flight Checks"

command -v python3 &>/dev/null && log_success "Python3  $(python3 --version)" || { log_error "Python3 not found"; exit 1; }
command -v node   &>/dev/null && log_success "Node.js  $(node --version)"    || { log_error "Node.js not found"; exit 1; }
command -v npm    &>/dev/null && log_success "npm      v$(npm --version)"    || { log_error "npm not found";     exit 1; }

[ -d "$BACKEND_DIR" ]  || { log_error "backend/ not found";  exit 1; }
[ -d "$FRONTEND_DIR" ] || { log_error "frontend/ not found"; exit 1; }
log_success "Project structure verified"

# ─────────────────────────────────────────────────────────────
# CLEAN UP OLD PROCESSES
# ─────────────────────────────────────────────────────────────
section "🧹 Cleaning Up Previous Runs"

for PORT in 8000 3000; do
  PIDS=$(lsof -ti tcp:$PORT 2>/dev/null)
  if [ -n "$PIDS" ]; then
    echo "$PIDS" | xargs kill -9 2>/dev/null
    sleep 0.5
    log_success "Freed port $PORT"
  else
    log_info "Port $PORT already free"
  fi
done

# ─────────────────────────────────────────────────────────────
# BACKEND — runs in background
# ─────────────────────────────────────────────────────────────
section "🐍 Backend Setup (FastAPI)"

cd "$BACKEND_DIR" || exit 1

if [ ! -d "venv" ]; then
  log_step "Creating Python virtual environment..."
  python3 -m venv venv &
  spinner $! "Setting up venv"
  log_success "Virtual environment created"
else
  log_success "Virtual environment already exists"
fi

source venv/bin/activate
log_success "Virtual environment activated"

log_step "Installing backend dependencies..."
pip install -r requirements.txt -q &
spinner $! "Installing packages"
log_success "Backend dependencies installed"

log_step "Starting FastAPI server in background..."
nohup python main.py > /tmp/backend.log 2>&1 &
BACKEND_PID=$!
sleep 2

if kill -0 "$BACKEND_PID" 2>/dev/null; then
  log_success "Backend running  ${DIM}→ http://localhost:8000${RESET}  ${DIM}(PID: $BACKEND_PID)${RESET}"
  log_info   "API Docs → http://localhost:8000/docs"
  log_info   "Logs     → /tmp/backend.log"
else
  log_error "Backend failed to start — check /tmp/backend.log"
  cat /tmp/backend.log
  exit 1
fi

deactivate

# ─────────────────────────────────────────────────────────────
# FRONTEND — runs in FOREGROUND so compilation is visible
# ─────────────────────────────────────────────────────────────
section "⚛️  Frontend (React + TensorFlow.js)"

cd "$FRONTEND_DIR" || exit 1

if [ ! -d "node_modules" ]; then
  log_step "Installing frontend dependencies..."
  npm install --silent &
  spinner $! "Running npm install"
  log_success "Frontend dependencies installed"
else
  log_success "node_modules already present"
fi

echo ""
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "  ${BOLD}${GREEN}🚀 Launching React Dev Server...${RESET}"
echo ""
echo -e "  ${CYAN}  ◉  Frontend${RESET}  →  ${BOLD}http://localhost:3000${RESET}   ${DIM}(React + TensorFlow.js)${RESET}"
echo -e "  ${MAGENTA}  ◉  Backend${RESET}   →  ${BOLD}http://localhost:8000${RESET}   ${DIM}(FastAPI)${RESET}"
echo -e "  ${MAGENTA}  ◉  API Docs${RESET}  →  ${BOLD}http://localhost:8000/docs${RESET}"
echo ""
echo -e "  ${BOLD}${YELLOW}⚠${RESET}  First compile takes 2–5 min (TensorFlow.js is large)."
echo -e "  ${DIM}   Browser opens automatically when ready. Press Ctrl+C to stop all.${RESET}"
echo ""
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# Run npm start in the FOREGROUND — all output is visible, browser auto-opens on success
npm start

# If npm start exits (either Ctrl+C or crash), run cleanup
cleanup

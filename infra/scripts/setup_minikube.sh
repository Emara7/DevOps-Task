#!/usr/bin/env bash
set -euo pipefail

MINIKUBE_VERSION="${MINIKUBE_VERSION:-v1.34.0}"
K8S_VERSION="${K8S_VERSION:-v1.29.6}"
DRIVER="${DRIVER:-docker}"
CPUS="${CPUS:-2}"
MEMORY_MB="${MEMORY_MB:-4096}"
PROFILE="${PROFILE:-minikube}"

log() { echo "[setup-minikube] $*"; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

ensure_packages() {
  if have_cmd apt-get; then
    sudo apt-get update -y
    sudo apt-get install -y curl conntrack socat ebtables ca-certificates gnupg lsb-release apt-transport-https jq
  elif have_cmd yum; then
    sudo yum install -y curl conntrack socat ebtables ca-certificates gnupg2 jq
  elif have_cmd dnf; then
    sudo dnf install -y curl conntrack socat ebtables ca-certificates gnupg2 jq
  else
    log "Unsupported package manager. Please install dependencies manually."
  fi
}

install_docker() {
  if have_cmd docker; then
    log "Docker already installed"
    return
  fi
  log "Installing Docker..."
  if have_cmd apt-get; then
    sudo install -m 0755 -d /etc/apt/keyrings || true
    curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  else
    curl -fsSL https://get.docker.com | sh
  fi
  sudo usermod -aG docker "$USER" || true
}

install_kubectl() {
  if have_cmd kubectl; then
    log "kubectl already installed"
    return
  fi
  log "Installing kubectl..."
  curl -fsSLo kubectl "https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/amd64/kubectl" || \
  curl -fsSLo kubectl "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/kubectl
}

install_helm() {
  if have_cmd helm; then
    log "helm already installed"
    return
  fi
  log "Installing helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}

install_minikube() {
  if have_cmd minikube; then
    log "minikube already installed"
    return
  fi
  log "Installing minikube ${MINIKUBE_VERSION}..."
  curl -fsSLo minikube.deb "https://storage.googleapis.com/minikube/releases/${MINIKUBE_VERSION}/minikube_latest_amd64.deb" || true
  if [ -f minikube.deb ]; then
    sudo dpkg -i minikube.deb || true
    rm -f minikube.deb || true
  else
    curl -fsSLo minikube "https://storage.googleapis.com/minikube/releases/${MINIKUBE_VERSION}/minikube-linux-amd64"
    sudo install minikube /usr/local/bin/minikube
    rm -f minikube
  fi
}

start_minikube() {
  log "Starting minikube profile=${PROFILE} driver=${DRIVER} k8s=${K8S_VERSION} cpus=${CPUS} mem=${MEMORY_MB}MB"
  if ! minikube status -p "$PROFILE" >/dev/null 2>&1; then
    minikube start -p "$PROFILE" \
      --driver="$DRIVER" \
      --kubernetes-version="$K8S_VERSION" \
      --cpus="$CPUS" \
      --memory="$MEMORY_MB" \
      --addons=ingress
  else
    log "Minikube already running (profile ${PROFILE})"
  fi
  minikube update-context -p "$PROFILE"
}

main() {
  ensure_packages
  if [ "$DRIVER" = "docker" ]; then
    install_docker
  fi
  install_kubectl
  install_helm
  install_minikube
  start_minikube
}

main "$@"

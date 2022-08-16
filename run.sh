#!/bin/bash

function init(){
  export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
  export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
  export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
  export AWS_REGION="eu-central-1"
  export CLUSTER_NAME="eks_cluster"
}

function install_requirements(){
  echo "Kubectl is downloading"
  curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.23.6/bin/linux/amd64/kubectl
  chmod +x kubectl
  mv kubectl /usr/local/bin/kubectl
  
  echo "Helm is downloading"
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod 700 get_helm.sh
  ./get_helm.sh --version v3.8.2
  helm version
  pip3 install awscli --upgrade --user

}

function install(){
  install_requirements;
  aws eks --region $AWS_REGION update-kubeconfig --name $CLUSTER_NAME
  cd charts/prometheus
  helm dependency update
  cd ${CI_PROJECT_DIR}
  helm install prometheus-stack charts/prometheus --namespace monitoring
  helm install grafana charts/grafana --namespace monitoring
  sed -i -r "s/CLUSTER_NAME/${CLUSTER_NAME}/g" fluent-bit/fluent-bit_configmap.yaml
  sed -i -r "s/REGION_NAME/${AWS_REGION}/g" fluent-bit/fluent-bit_configmap.yaml
  kubectl apply -f fluent-bit -n monitoring
}

function update(){
  install_requirements;
  aws eks --region $AWS_REGION update-kubeconfig --name $CLUSTER_NAME
  cd charts/prometheus
  helm dependency update
  cd ${CI_PROJECT_DIR}
  helm upgrade prometheus-stack charts/prometheus --namespace monitoring
  helm upgrade grafana charts/grafana --namespace monitoring
  sed -i -r "s/CLUSTER_NAME/${CLUSTER_NAME}/g" fluent-bit/fluent-bit-configmap.yaml
  sed -i -r "s/REGION_NAME/${AWS_REGION}/g" fluent-bit/fluent-bit-configmap.yaml
  kubectl apply -f fluent-bit -n monitoring
}

function destroy(){
  install_requirements;
  aws eks --region $AWS_REGION update-kubeconfig --name $CLUSTER_NAME
  cd charts/prometheus
  helm dependency update
  cd ${CI_PROJECT_DIR}
  helm delete prometheus-stack charts/prometheus --namespace monitoring
  helm delete grafana charts/grafana --namespace monitoring
  kubectl delete daemonset fluent-bit --namespace monitoring
}

function main() {
  init;
  if [ "$1" == "install" ];then
    install;
  elif [ "$1" == "update" ];then
    update;
  elif [ "$1" == "destroy" ];then
    destroy;
  fi
}

main $1

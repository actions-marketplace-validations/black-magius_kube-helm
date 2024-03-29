#!/bin/bash
set -e

echo Auth process
mkdir $HOME/.kube
echo "$kube_helm_deploy_kube_auth_line" | base64 -d > $HOME/.kube/config

echo kube_helm_deploy_get_app_version
echo "$kube_helm_deploy_app_version"
if [[ "$kube_helm_deploy_app_version" == '' ]]; then
  if [[ ${GITHUB_REF_TYPE} == 'branch' ]]; then
    export APP_VERSION="0.0.1-${GITHUB_REF_NAME}-${GITHUB_SHA}"
  else
    export APP_VERSION="${GITHUB_REF_NAME}"
  fi
else
  export APP_VERSION="${kube_helm_deploy_app_version}"
fi
echo "APP_VERSION=$APP_VERSION"

echo kube_helm_deploy_get_imagePullPolicy
echo "$kube_helm_deploy_imagePullPolicy"
if [[ "$kube_helm_deploy_imagePullPolicy" == '' ]]; then
  if [[ ${GITHUB_REF_TYPE} == 'branch' ]]; then
    export IMAGE_PULL_POLICY="Always"
  else
    export IMAGE_PULL_POLICY="IfNotPresent"
  fi
else
  export IMAGE_PULL_POLICY="$kube_helm_deploy_imagePullPolicy"
fi
echo "IMAGE_PULL_POLICY=$IMAGE_PULL_POLICY"

echo kube_helm_deploy_get_docker_config
export DOCKER_CONFIG=$(echo -n "{\"auths\":{\"$CI_REGISTRY\":{\"auth\":\"$(echo -n "${CI_DEPLOY_USER}:${CI_DEPLOY_PASSWORD}" | base64 -w0)\"}}}" | base64 -w0)

echo kube_helm_deploy_release_name
if [[ "$kube_helm_deploy_release_name" == '' ]]; then
  export kube_helm_deploy_release_name=${CI_PROJECT_NAME//_/-}
fi
echo $kube_helm_deploy_release_name

echo kube_helm_deploy_set_chart
envsubst < "$kube_helm_deploy_path_to_helm_files/$kube_helm_deploy_chart_tpl_name" > "$kube_helm_deploy_path_to_helm_files/Chart.yaml"
cat "$kube_helm_deploy_path_to_helm_files/Chart.yaml"

echo kube_helm_deploy_set_values
if [[ -f "$kube_helm_deploy_path_to_helm_files/$kube_helm_deploy_value_tpl_name" ]]; then
  envsubst < "$kube_helm_deploy_path_to_helm_files/$kube_helm_deploy_value_tpl_name" > "$kube_helm_deploy_path_to_helm_files/values.yaml"
else
  envsubst < "$kube_helm_deploy_path_to_helm_files/$kube_helm_deploy_value_tpl_name" > "$kube_helm_deploy_path_to_helm_files/values_tmp.yaml"
  mv -f "$kube_helm_deploy_path_to_helm_files/values_tmp.yaml" "$kube_helm_deploy_path_to_helm_files/values.yaml"
fi
cat "$kube_helm_deploy_path_to_helm_files/values.yaml"
  
echo kube_helm_deploy_set_values_additional
if [[ -f "$kube_helm_deploy_path_to_helm_files/$kube_helm_deploy_value_file_name" ]]; then
  envsubst < "$kube_helm_deploy_path_to_helm_files/$kube_helm_deploy_value_file_name" | \
  helm template "$kube_helm_deploy_path_to_helm_files"  -n "$kube_helm_deploy_destination_namespace" --debug --values - > debug.yaml; true
else
  echo value file not found file kube_helm_deploy_value_file_name=$kube_helm_deploy_value_file_name 
  helm template "$kube_helm_deploy_path_to_helm_files"  -n "$kube_helm_deploy_destination_namespace" --debug > debug.yaml; true
fi
cat ./debug.yaml
  
echo kube_helm_deploy_run
if [[ -f "$kube_helm_deploy_path_to_helm_files/$kube_helm_deploy_value_file_name" ]]; then
  envsubst < "$kube_helm_deploy_path_to_helm_files/$kube_helm_deploy_value_file_name" | \
  helm upgrade "$kube_helm_deploy_release_name" "$kube_helm_deploy_path_to_helm_files" \
  --install --create-namespace -n "$kube_helm_deploy_destination_namespace" --values -
else
  helm upgrade "$kube_helm_deploy_release_name" "$kube_helm_deploy_path_to_helm_files" \
  --install --create-namespace -n "$kube_helm_deploy_destination_namespace"
fi

#!/bin/bash

#
# Date .......: 09/11/2026
# Developer ..: Waldirio M Pinheiro <waldirio@gmail.com> | <waldirio@redhat.com>
# Disclaimer .: Script not supported By Red Hat.
# Purpose ....: Update the Notebooks/Workbenches after a migration of RHOAI 2.25 -> 3+
#              There is a warning in the webUI, telling that you need to open and edit
#              to update the URL, or you can use this script to fix the same.
# 


LOG="/tmp/fix_notebook_url.log"
>$LOG

# By default, the script will not update anything
fix_nb=0

# Verify if the user is authenticated in the cluster
verify_login()
{
  echo "# Authentication" | tee -a $LOG
  oc get nodes &>/dev/null
  if [ $? -eq 0 ]; then
    echo "Authenticated! Good to go" | tee -a $LOG
    echo "---" | tee -a $LOG
    oc get nodes | tee -a $LOG
    echo "---" | tee -a $LOG
    echo "" | tee -a $LOG
  else
    echo "You are not logged in the OCP cluster, exiting ..." | tee -a $LOG
    exit
  fi
}

# Getting the complete list of Notebooks
current_notebooks()
{
  echo "# Checking All the Notebooks" | tee -a $LOG
  oc get notebooks.kubeflow.org -A | tee -a $LOG
  echo "" | tee -a $LOG

  # Here, iterating on each one of them
  oc get notebooks.kubeflow.org -A --no-headers | while read ns name age
  do
    echo "" | tee -a $LOG
    echo "NS: $ns, NAME: $name" | tee -a $LOG
    fix_it $ns $name
  done
}

# Starting the fixing process
fix_it()
{
  #echo "# Fixing It"
  #echo "Here, first: $1, second: $2"
  # The first parameter is the Namespace
  NS=$1
  # The second parameter is the Notebook name
  NB=$2
  echo "Namespace .: $NS" | tee -a $LOG
  echo "Notebook ..: $NB" | tee -a $LOG

# confirm current container order (webhook may have re-added kube-rbac-proxy at a different index since we last checked)
# oc get notebook wb00 -n demo-no-label -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\n"}{end}'
  echo "Command: oc get notebook $NB -n $NS -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{\"\n\"}{end}'" | tee -a $LOG
  echo "---" | tee -a $LOG
  oc get notebook $NB -n $NS -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\n"}{end}' | tee -a $LOG
  echo "---" | tee -a $LOG
  echo "Ps.: Here, the '$NB' and 'kube-rbac-proxy' are expected" | tee -a $LOG

  response=$(oc get notebook $NB -n $NS -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\n"}{end}')

  resp_notebook_name=$(echo $response | grep $NB | wc -l | awk '{print $1}')
  resp_rbac=$(echo $response | grep rbac | wc -l | awk '{print $1}')
  resp_oauth=$(echo $response | grep oauth | wc -l | awk '{print $1}')

  echo "nb_name: $resp_notebook_name" | tee -a $LOG
  echo "rbac: $resp_rbac" | tee -a $LOG
  echo "oauth: $resp_oauth" | tee -a $LOG

  if [ $resp_notebook_name -eq 1 ] && [ $resp_rbac -eq 1 ]  && [ $resp_oauth -eq 0 ]; then
    echo "Nothing to do!" | tee -a $LOG
  elif [ $resp_notebook_name -eq 1 ] && [ $resp_rbac -eq 0 ] && [ $resp_oauth -eq 1 ]; then
    echo "Need fix here" | tee -a $LOG
    if [ $fix_nb -eq 1 ]; then
      fix_2nd_level $NS $NB
    else
      echo "Not now, only reporting" | tee -a $LOG
    fi
  elif [ $resp_notebook_name -eq 1 ] && [ $resp_rbac -eq 1 ] && [ $resp_oauth -eq 1 ]; then
    echo "Alsooooo Need fix here" | tee -a $LOG
    if [ $fix_nb -eq 1 ]; then
      fix_2nd_level $NS $NB
    else
      echo "Not now, only reporting" | tee -a $LOG
    fi
  else
    echo "We need to check" | tee -a $LOG
  fi

}

# Second part, which will effectively update some stuff
fix_2nd_level()
{
  # The first parameter is the Namespace
  NS=$1
  # The second parameter is the Notebook name
  NB=$2

  echo "2nd Namespace .: $NS" | tee -a $LOG
  echo "2nd Notebook ..: $NB" | tee -a $LOG
     
  # 1. Add the missing annotation
  # oc annotate notebook wb00 -n demo-no-label \
  #    notebooks.opendatahub.io/inject-auth=true --overwrite
  echo "Command: oc annotate notebook $NB -n $NS notebooks.opendatahub.io/inject-auth=true --overwrite" | tee -a $LOG
  echo "---" | tee -a $LOG
  oc annotate notebook $NB -n $NS notebooks.opendatahub.io/inject-auth=true --overwrite | tee -a $LOG
  echo "---" | tee -a $LOG

  # Checking
  # oc get notebook wb00 -n demo-no-label -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\n"}{end}'
  echo "Command: oc get notebook $NB -n $NS -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{\"\n\"}{end}'" | tee -a $LOG
  echo "---" | tee -a $LOG
  oc get notebook $NB -n $NS -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\n"}{end}' | tee -a $LOG
  echo "---" | tee -a $LOG
  echo "Ps.: Here, the '$NB' and 'kube-rbac-proxy' are expected" | tee -a $LOG

  # To check the order to remove the proper entry
  list_containers=$(oc get notebook $NB -n $NS -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\n"}{end}')
  temp_pos=$(echo "$list_containers" | grep -n "oauth-proxy" | cut -d: -f1)
  final_pos=$(echo $temp_pos - 1 | bc) 
  echo "List of Containers" | tee -a $LOG
  echo "$list_containers" | tee -a $LOG
  echo "Temp Pos ...: $temp_pos" | tee -a $LOG
  echo "Pos ...: $final_pos" | tee -a $LOG

  # remove the oauth-proxy container (adjust index below if the order isn't wb00,oauth-proxy,kube-rbac-proxy)
  # oc patch notebook wb00 -n demo-no-label --type=json \
  #     -p '[{"op":"remove","path":"/spec/template/spec/containers/1"}]'
  echo "Command: oc patch notebook $NB -n $NS --type=json -p '[{\"op\":\"remove\",\"path\":\"/spec/template/spec/containers/$final_pos\"}]'" | tee -a $LOG
  echo "---" | tee -a $LOG
  oc patch notebook $NB -n $NS --type=json -p '[{"op":"remove","path":"/spec/template/spec/containers/'$final_pos'"}]' | tee -a $LOG
  echo "---" | tee -a $LOG

  # confirm the patch held
  # oc get notebook $WB -n $NS -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\n"}{end}'
  echo "Command: oc get notebook $NB -n $NS -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{\"\n\"}{end}'" | tee -a $LOG
  echo "---" | tee -a $LOG
  oc get notebook $NB -n $NS -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\n"}{end}' | tee -a $LOG
  echo "---" | tee -a $LOG
  echo "Ps.: Here, the '$NB' and 'kube-rbac-proxy' are expected" | tee -a $LOG

  # cycle the pod so the new container list actually takes effect
  # oc annotate notebook $WB -n $NS kubeflow-resource-stopped="$(date -u +%Y-%m-%dT%H:%M:%SZ)" --overwrite
  echo "Command: oc annotate notebook $NB -n $NS kubeflow-resource-stopped=\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\" --overwrite" | tee -a $LOG
  echo "---" | tee -a $LOG
  oc annotate notebook $NB -n $NS kubeflow-resource-stopped="$(date -u +%Y-%m-%dT%H:%M:%SZ)" --overwrite  | tee -a $LOG
  echo "---" | tee -a $LOG

  # If we would like to restart the workbenches in a sequence, we could execute the command below
  # oc annotate notebook wb00 -n demo-no-label kubeflow-resource-stopped-
}


## Main

if [ "$1" == "--help" ]; then
  echo "You can call '$0 --fix' to fix automatically all the notebooks"
  echo ""
  echo "Only '$0' will generate a full report"
  exit
elif [ "$1" == "--fix" ]; then
  echo "Fixing automatically"
  fix_nb=1
fi



verify_login         # Verify if you are logged
current_notebooks    # Check the Current Notebooks

#fix_it demo-no-label wb100
#fix_it demo-no-label wb-manual02
#fix_it demo-no-label wb-manual01
#fix_it demo wb00

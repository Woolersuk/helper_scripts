function kcdescribepod { param ([string] $i); kubectl describe pod $i }
function kgetall { kubectl get all }
function kgetpodsall { kubectl get pods }
function kgetpodspecific { param ([string] $i); kubectl get pod $i }
function klist { kubectl config get-contexts }
function kswitch { param ([string] $i); kubectl config use-context $i }
function kconnect { param ([string] $i); kubectl exec -it $i -- /bin/bash }
function klogs { param ([string] $i); kubectl logs --v=8 $i }
function dockerps { docker ps }

New-Alias -Name "kuse" kuswitch -Force
New-Alias -Name "kns" kubens -Force
New-Alias -Name "klog" klogs -Force
New-Alias -Name "klist" klist -Force
New-Alias -Name "kgpo" kgetpodspecific -Force
New-Alias -Name "kgpa" kgetpodsall -Force
New-Alias -Name "kga" kgetall -Force
New-Alias -Name "kcx" kubectx -Force
New-Alias -Name "kconn" kuconnect -Force
New-Alias -Name "kcdp" kcdescribepod -Force
New-Alias -Name "kc" kubectl -Force

# Define kubectl aliases as functions
function k { kubectl @args }
function kl { kubectl logs @args }
function kexec { kubectl exec -it @args }
function kpf { kubectl port-forward @args }
function kaci { kubectl auth can-i @args }
function kat { kubectl attach @args }
function kapir { kubectl api-resources @args }
function kapiv { kubectl api-versions @args }

# Get commands
function kg { kubectl get @args }
function kgns { kubectl get ns @args }
function kgp { kubectl get pods @args }
function kgs { kubectl get secrets @args }
function kgd { kubectl get deploy @args }
function kgrs { kubectl get rs @args }
function kgss { kubectl get sts @args }
function kgds { kubectl get ds @args }
function kgcm { kubectl get configmap @args }
function kgcj { kubectl get cronjob @args }
function kgj { kubectl get job @args }
function kgsvc { kubectl get svc -o wide @args }
function kgn { kubectl get no -o wide @args }
function kgr { kubectl get roles @args }
function kgrb { kubectl get rolebindings @args }
function kgcr { kubectl get clusterroles @args }
function kgrb { kubectl get clusterrolebindings @args }
function kgsa { kubectl get sa @args }
function kgnp { kubectl get netpol @args }

# Edit commands
function ke { kubectl edit @args }
function kens { kubectl edit ns @args }
function kes { kubectl edit secrets @args }
function ked { kubectl edit deploy @args }
function kers { kubectl edit rs @args }
function kess { kubectl edit sts @args }
function keds { kubectl edit ds @args }
function kesvc { kubectl edit svc @args }
function kecm { kubectl edit cm @args }
function kecj { kubectl edit cj @args }
function ker { kubectl edit roles @args }
function kecr { kubectl edit clusterroles @args }
function kerb { kubectl edit clusterrolebindings @args }
function kesa { kubectl edit sa @args }
function kenp { kubectl edit netpol @args }

# Describe commands
function kd { kubectl describe @args }
function kdns { kubectl describe ns @args }
function kdp { kubectl describe pod @args }
function kds { kubectl describe secrets @args }
function kdd { kubectl describe deploy @args }
function kdrs { kubectl describe rs @args }
function kdss { kubectl describe sts @args }
function kdds { kubectl describe ds @args }
function kdsvc { kubectl describe svc @args }
function kdcm { kubectl describe cm @args }
function kdcj { kubectl describe cj @args }
function kdj { kubectl describe job @args }
function kdsa { kubectl describe sa @args }
function kdr { kubectl describe roles @args }
function kdrb { kubectl describe rolebindings @args }
function kdcr { kubectl describe clusterroles @args }
function kdcrb { kubectl describe clusterrolebindings @args }
function kdnp { kubectl describe netpol @args }

# Delete commands
function kdel { kubectl delete @args }
function kdelns { kubectl delete ns @args }
function kdels { kubectl delete secrets @args }
function kdelp { kubectl delete po @args }
function kdeld { kubectl delete deployment @args }
function kdelrs { kubectl delete rs @args }
function kdelss { kubectl delete sts @args }
function kdelds { kubectl delete ds @args }
function kdelsvc { kubectl delete svc @args }
function kdelcm { kubectl delete cm @args }
function kdelcj { kubectl delete cj @args }
function kdelj { kubectl delete job @args }
function kdelr { kubectl delete roles @args }
function kdelrb { kubectl delete rolebindings @args }
function kdelcr { kubectl delete clusterroles @args }
function kdelrb { kubectl delete clusterrolebindings @args }
function kdelsa { kubectl delete sa @args }
function kdelnp { kubectl delete netpol @args }

# Mock commands
function kmock { kubectl create mock -o yaml --dry-run=client @args }
function kmockns { kubectl create ns mock -o yaml --dry-run=client @args }
function kmockcm { kubectl create cm mock -o yaml --dry-run=client @args }
function kmocksa { kubectl create sa mock -o yaml --dry-run=client @args }

# Config commands
function kcfg { kubectl config @args }
function kcfgv { kubectl config view @args }
function kcfgns { kubectl config set-context --current --namespace @args }
function kcfgcurrent { kubectl config current-context @args }
function kcfggc { kubectl config get-contexts @args }
function kcfgsc { kubectl config set-context @args }
function kcfguc { kubectl config use-context @args }

# Kubescape related
function kssbom { kubectl -n kubescape get sbomspdxv2p3s @args }
function kssbomf { kubectl -n kubescape get sbomspdxv2p3filtereds @args }
function kssboms { kubectl -n kubescape get sbomsummaries @args }
function ksvulns { kubectl -n kubescape get vulnerabilitymanifestsummaries @args }
function ksvuln { kubectl -n kubescape get vulnerabilitymanifests @args }

# Kubescape related with labels
function kssboml { kubectl -n kubescape get sbomspdxv2p3s --show-labels @args }
function kssbomfl { kubectl -n kubescape get sbomspdxv2p3filtereds --show-labels @args }
function kssbomsl { kubectl -n kubescape get sbomsummaries --show-labels @args }
function ksvulnsl { kubectl -n kubescape get vulnerabilitymanifestsummaries --show-labels @args }
function ksvulnl { kubectl -n kubescape get vulnerabilitymanifests --show-labels @args }

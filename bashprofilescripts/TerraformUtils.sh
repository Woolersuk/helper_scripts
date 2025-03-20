findit() {
    local search_term="$1"
    local result="$(grep -H -v "Terraform has created a lock file .terraform.lock.hcl to record the provider" *.txt | grep -H "$search_term" | sed 's/(standard input)//' | awk -F ":" '{gsub(/:$/, ""); printf "%-35s %s:%s:%s:%s\n", $1, $2, $3, $4, $5}' | column -t)"
    local count="$(echo "$result" | wc -l)"
    echo "$result"
    echo "Total entries found: $count"
}

findin() {
    local filename="$1"
    local search_term="$2"
    local result="$(grep -H -v "Terraform has created a lock file .terraform.lock.hcl to record the provider" "$filename"*.txt | grep -H "$search_term" | sed 's/(standard input)//' | awk -F ":" '{gsub(/:$/, ""); printf "%-35s %s:%s:%s:%s\n", $1, $2, $3, $4, $5}' | column -t)"
    local count="$(echo "$result" | wc -l)"
    echo "$result"
    echo "Total entries found: $count"
}

function tgsp() {
    terragrunt state pull > "$1.tfstate"
}

function tgf() {
	for i in $(find -name "terragrunt*" | grep -v terragrunt-cache)
		do TEMP=$(echo $i | sed 's/hcl/tf/g')
		mv $i $TEMP
		terraform fmt $TEMP
		mv $TEMP $i
	done
}

function fmtbranch() {
  for i in $(find -name "*.hcl" | sed 's/\.hcl//'); do
    mv $i.hcl $i.tf
    terraform fmt $i.tf
    mv $i.tf
    $i.hcl
  done
}

alias allfmt="tg run-all hclfmt"
alias allinit="tg run-all init"
alias allplan="tg run-all plan"
alias cleanall='find . -type d -name ".terragrunt*" | xargs rm -rf'
alias cleanup='rm -rf .terra*'
alias cls=clear
alias pci='pre-commit install'
alias pcra='pre-commit run -a'
alias pcrc='pre-commit clean'
alias pcu='pre-commit uninstall'
alias rerunf='clear && cleanall && terraform init && terraform plan '
alias rerunfa='clear && cleanall && terraform init && terraform plan && terraform apply '
alias rerung='clear && cleanall && terragrunt init && terragrunt plan '
alias rerunga='clear && cleanall && terragrunt init && terragrunt plan && terragrunt apply '
alias sortvars='/mnt/tf_vars_sort.awk < variables.tf | tee z_sorted_variables.tf'
alias sortouts='/mnt/tf_vars_sort.awk < outputs.tf | tee z_sorted_outputs.tf'
alias tfa='time terraform apply'
alias tfaa='time terraform apply -auto-approve '
alias tfd='time terraform destroy'
alias tfda='time terraform destroy -auto-approve '
alias tff='terraform fmt --recursive'
alias tfi='terraform init'
alias tfoj='terraform output --json '
alias tfp='time terraform plan'
alias tfupdate="terraform get -update"
alias tfv='terraform validate'
alias tg="terragrunt"
alias tgc="terragrunt console"
alias tga='terragrunt apply --tf-forward-stdout --log-level=warn '
alias tgaa='terragrunt apply -auto-approve --tf-forward-stdout --log-level=warn '
alias tgd='terragrunt destroy --tf-forward-stdout --log-level=warn '
alias tgda='terragrunt destroy -auto-approve --tf-forward-stdout --log-level=warn '
alias tgf='terragrunt hclfmt --recursive'
alias tgfu="terragrunt force-unlock $1"
alias tgfu="tg force-unlock $1 -force"
alias tgi='clear && terragrunt init --tf-forward-stdout --log-level=warn '
alias tgims='terragrunt init -migrate-state --tf-forward-stdout --log-level=warn'
alias tgip='clear && cleanall && terragrunt init --tf-forward-stdout --log-level=warn && terragrunt plan --tf-forward-stdout --log-level=warn '
alias tgipaa='cleanall && terragrunt init --tf-forward-stdout --log-level=warn && terragrunt plan --tf-forward-stdout --log-level=warn && terragrunt apply --tf-forward-stdout --log-level=warn'
alias tgir='terragrunt init -reconfigure --tf-forward-stdout --log-level=warn'
alias tgiu='terragrunt init -upgrade  --tf-forward-stdout --log-level=warn'
alias tgiup='terragrunt init -upgrade --tf-forward-stdout --log-level=warn && terragrunt plan --tf-forward-stdout --log-level=warn '
alias tgiupaa='terragrunt init -upgrade --tf-forward-stdout --log-level=warn && terragrunt plan --tf-forward-stdout --log-level=warn && terragrunt apply --tf-forward-stdout --log-level=warn'
alias tgciup='cleanall && terragrunt init -upgrade --tf-forward-stdout --log-level=warn && terragrunt plan --tf-forward-stdout --log-level=warn'
alias clp='cleanall && terragrunt init -upgrade --tf-forward-stdout --log-level=warn && terragrunt plan --tf-forward-stdout --log-level=warn '
alias tgciupa='cleanall && terragrunt init -upgrade && terragrunt plan --tf-forward-stdout --log-level=warn && terragrunt apply'
alias tgo="terragrunt output"
alias tgp='clear && terragrunt plan --tf-forward-stdout --log-level=warn '
alias tgpaa="terragrunt plan --tf-forward-stdout --log-level=warn && terragrunt apply --tf-forward-stdout --log-level=warn "
alias tgpd='terragrunt plan --tf-forward-stdout --log-level=warn -destroy '
alias tgr="terragrunt refresh --tf-forward-stdout --log-level=warn "
alias tgro="terragrunt refresh --tf-forward-stdout --log-level=warn && terragrunt output"
alias tgpro="terragrunt plan -refresh-only --tf-forward-stdout --log-level=warn "
alias tgra='terragrunt run-all apply '
alias tgrd='terragrunt run-all destroy '
alias tgsa='terragrunt show -json'
alias tgsl='terragrunt state list --tf-forward-stdout --log-level=warn'
alias tgss="terragrunt state show $1 --tf-forward-stdout --log-level=warn"
#alias tgsp="terragrunt state pull > $1.tfstate"
alias tgupdate="terragrunt get -update --tf-forward-stdout --log-level=warn"
alias tgv='terragrunt validate '
alias tgv='terragrunt validate -json '
alias tgwd="terragrunt workspace delete $1"
alias tgws="terragrunt workspace select $1"
alias tgwl="terragrunt workspace list"
alias twl='terraform workspace list '
alias twn='terraform workspace new '
alias tws='terraform workspace select '
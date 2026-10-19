# Atalhos para rodar tudo localmente (precisa de Docker, kind, kubectl, helm e terraform)
APP ?= ../almoxarifado-robotica
TAG ?= $(shell git -C $(APP) rev-parse --short=12 HEAD)
TF  := terraform -chdir=terraform

.PHONY: tudo validar cluster imagens deploy teste destruir

tudo: cluster imagens deploy teste

validar:
	scripts/validar-chart.sh
	$(TF) fmt -check -recursive
	$(TF) init -backend=false -input=false
	$(TF) validate
	$(TF) test

cluster:
	scripts/criar-cluster.sh

imagens:
	TAG=$(TAG) scripts/construir-imagens.sh $(APP)

deploy:
	$(TF) init -input=false
	$(TF) apply -var-file=kind.tfvars -var versao=$(TAG)

teste:
	helm test almoxarifado -n almox --logs
	scripts/teste-fumaca.sh

destruir:
	kind delete cluster --name almox
	rm -f terraform/terraform.tfstate terraform/terraform.tfstate.backup

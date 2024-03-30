########
# util #
########

.phony: list graph 

graph:
	make -Bnd $(target) | make2graph | dot -Tpng -o dep-graph.png

list:
	@LC_ALL=C $(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/(^|\n)# Files(\n|$$)/,/(^|\n)# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | grep -E -v -e '^[^[:alnum:]]' -e '^$@$$'

##############
# Networking #
##############

.phony: forward unforward

forward: 
	sudo ssh -g -L 80:localhost:6880 -f -N kwkaiser@localhost	
	sudo ssh -g -L 443:localhost:6840 -f -N kwkaiser@localhost	

##############
# Deployment #
##############

.phony: redeploy apply-secrets

apply-secrets:
	PROD=$(prod) ./scripts/secrets.sh 

template:
	helm template . --values ./values/shared.yaml --values ./values/$(env).yaml > template.yaml

redeploy-dev:
	PROD=false ./scripts/secrets.sh

redeploy-prod:
	PROD=true ./scripts/secrets.sh
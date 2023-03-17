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
	iptables -t nat -A PREROUTING -s 127.0.0.1 -p tcp --dport 80 -j REDIRECT --to 6980
	iptables -t nat -A OUTPUT -s 127.0.0.1 -p tcp --dport 80 -j REDIRECT --to 6980

unforward:
	systemctl restart iptables
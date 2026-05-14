.PHONY: all pnpm

SCRIPTS := ../scripts

all : sincos.bin UI

pnpm :
	pnpm -C $(SCRIPTS) --silent i

UI : | pnpm
	node -- $(SCRIPTS)/tilemap.ts UI.json ../assets

sincos.bin : | pnpm
	node -- $(SCRIPTS)/sincostable.ts ../assets/sincos.bin

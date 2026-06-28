.PHONY: all pnpm

SCRIPTS := ../scripts

all : sincos.bin UI

pnpm :
	pnpm -C $(SCRIPTS) --silent i

UI : UI.json | pnpm
	node -- $(SCRIPTS)/tilemap.ts $< ../assets

sincos.bin : | pnpm
	node -- $(SCRIPTS)/sincostable.ts ../assets/sincos.bin

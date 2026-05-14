.PHONY: all clean assets

DEPDIR := .deps
SRCS = main.asm snddriver.z80

%.bin : %.asm $(DEPDIR)/%.asm.d | $(DEPDIR)
	vasmm68k_mot -Fbin -nosym -x -warncomm -o $@ -L $*.lst -depend=make -depfile $(word 2,$^) $<

%.bin : %.z80 $(DEPDIR)/%.z80.d | $(DEPDIR)
	vasmz80_oldstyle -Fbin -nosym -x -o $@ -L $*.lst -depend=make -depfile $(word 2,$^) $<

all : snddriver.bin main.bin

clean :
	-rm -f *.bin *.lst

mdrogue.bin : main.bin | all
	cp $< $@

assets/% :
	$(MAKE) -C raw-assets/ all

$(DEPDIR) : ; @mkdir -p $@

#DEPFILES := $(SRCS:%.asm=$(DEPDIR)/%.d)
DEPFILES := $(addprefix $(DEPDIR)/,$(addsuffix .d,$(SRCS)))
$(DEPFILES) :
include $(wildcard $(DEPFILES))

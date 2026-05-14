
DEPDIR := .deps
SRCS = main.asm snddriver.z80

%.bin : %.asm $(DEPDIR)/%.asm.d | $(DEPDIR)
	vasmm68k_mot -Fbin -nosym -x -warncomm -o $@ -L $*.lst -depend=make -depfile $(DEPDIR)/$*.asm.d $<

%.bin : %.z80 $(DEPDIR)/%.z80.d | $(DEPDIR)
	vasmz80_oldstyle -Fbin -nosym -x -o $@ -L $*.lst -depend=make -depfile $(DEPDIR)/$*.z80.d $<

all : snddriver.bin main.bin

clean :
	-rm -f *.bin *.lst

mdrogue.bin : main.bin snddriver.bin
	cp $< $@

$(DEPDIR) : ; @mkdir -p $@

#DEPFILES := $(SRCS:%.asm=$(DEPDIR)/%.d)
DEPFILES := $(addprefix $(DEPDIR)/,$(addsuffix .d,$(SRCS)))
$(DEPFILES) :
include $(wildcard $(DEPFILES))

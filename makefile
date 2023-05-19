#targets=../bin \
		../bin/test \
		../bin/asmTest \
		../bin/diamond \
		../bin/mem \
		../bin/nestedLoop
muslcPath=../../muslc
muslcFiles=$(muslcPath)/linked_muslc.ll

muslcIncludePath=$(muslcPath)/inc
muslcInclude=-I$(muslcIncludePath)/src/internal -I$(muslcIncludePath)/include -I$(muslcIncludePath)/obj/include -I$(muslcIncludePath)/arch/x86_64 -I$(muslcIncludePath)/arch/generic -I$(muslcIncludePath)/obj/src/internal -I $(muslcIncludePath)/malloc/mallocng
#muslcFiles=$(muslcPath)/rand.ll $(muslcPath)/malloc.ll $(muslcPath)/__lock.ll
#muslcFiles=$(muslcPath)/rand.ll $(muslcPath)/atol.ll $(muslcPath)/strtol.ll $(muslcPath)/shgetc.ll $(muslcPath)/intscan.ll

#muslcFiles = ./muslc/gettimeofday.ll
#muslcFiles = ./muslc/gettimeofday.ll ./muslc/printf.ll 
#muslcFiles = ./muslc/gettimeofday.ll ./muslc/printf.ll ./muslc/puts.ll ./muslc/__lockfile.ll
#muslcPath=/media/hdd0/research/shared/musl-1.2.3

#muslcInclude=-I$(muslcPath)/src/internal -I$(muslcPath)/include -I$(muslcPath)/obj/include -I$(muslcPath)/arch/x86_64 -I$(muslcPath)/arch/generic -I$(muslcPath)/obj/src/internal

#Currently tested case
targets=$(ZRAY_BIN_PATH)/list_traversal

all: $(targets)

cxxFlags=$(shell ${CONFIG} --cxxflags)
ldFlags=$(shell ${CONFIG} --ldflags --libs)

optLevel=-O3

ifeq ($(MAKECMDGOALS), gem5)
CFLAGS=-DGEM5_BUILD
else ifeq ($(MAKECMDGOALS), gem5_zray)
CFLAGS=-DGEM5_ZRAY_BUILD
endif

#flags=-ggdb #If we want debugging symbols
ifeq ($(MACHINE_ARCH),x86_64)
flags=-fxray-instrument -Xclang -disable-O0-optnone -I$(GEM5_PATH)/include -L$(GEM5_PATH)/util/m5/build/x86/out
else ifeq ($(MACHINE_ARCH), riscv64)
flags=-fxray-instrument -Xclang -disable-O0-optnone -I/usr/include/riscv64-linux-gnu -march=rv64g -msmall-data-limit=0 -latomic
endif
requiredPasses=-mem2reg

$(ZRAY_BIN_PATH):
	mkdir $@

#Test programs
%.ll: %.cc $(ZRAY_BIN_PATH)/tool.so
	$(CUSTOM_CC) -o tmp_$<.ll $< -std=c++14 $(CFLAGS) $(flags) $(optLevel) -S -emit-llvm -fverbose-asm 
	$(CUSTOM_LINK) -o tmp_$<.ll tmp_$<.ll $(muslcFiles)

ifeq ($(MAKECMDGOALS), gem5)
	$(CUSTOM_OPT) -enable-new-pm=0 $(optLevel) $(requiredPasses) --debug-pass=Arguments  -S < tmp_$<.ll > $@
else
	$(CUSTOM_OPT) -enable-new-pm=0 $(optLevel) $(requiredPasses) -load $(ZRAY_BIN_PATH)/tool.so -tool_pass --debug-pass=Arguments  -S < tmp_$<.ll > $@
endif

%.ll: %.c $(ZRAY_BIN_PATH)/tool.so
	$(CUSTOM_C) -o tmp_$<.ll $< $(CFLAGS) $(flags) $(optLevel) -S -emit-llvm -fverbose-asm $(muslcInclude)
	$(CUSTOM_LINK) -o tmp_$<.ll tmp_$<.ll $(muslcFiles)
ifeq ($(MAKECMDGOALS), gem5)
	$(CUSTOM_OPT) -enable-new-pm=0 $(optLevel) $(requiredPasses) --debug-pass=Arguments  -S < tmp_$<.ll > $@
else
	#$(CUSTOM_OPT) -enable-new-pm=0 $(optLevel) $(requiredPasses) --debug-pass=Arguments  -S < tmp_$<.ll > $@
	$(CUSTOM_OPT) -enable-new-pm=0 $(optLevel) $(requiredPasses) -load $(ZRAY_BIN_PATH)/tool.so --loophoist=false --postdomset=true --mirpass=true -tool_pass --debug-pass=Arguments  -S < tmp_$<.ll > $@
endif

$(ZRAY_BIN_PATH)/%: %.ll $(ZRAY_BIN_PATH)/tool_dyn.ll
	#Link modules together
	$(CUSTOM_LINK) -o linked_$<.ll $^ 
	#Link into binary, zip metadata and concat
ifeq ($(MAKECMDGOALS), gem5)
	$(CUSTOM_CC) -o $@ linked_$<.ll -std=c++14 $(flags) $(muslcInclude)
else
	$(CUSTOM_CC) -o $@ linked_$<.ll -std=c++14 $(flags) $(muslcInclude)
	#zip tool_file.zip tool_file
	#cat $@_tmp tool_file.zip > $@
	#chmod +x $@
	#Cleanup
	#rm $@_tmp tool_file tool_file.zip
endif

.PHONY: gem5 gem5_zray

gem5: $(targets)

gem5_zray: $(targets)

clean:
	rm -rf *.ll $(targets)

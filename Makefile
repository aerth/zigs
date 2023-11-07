zig ?= zig
#CC=zig cc
LDFLAGS += -L./zig-out/lib -lzigs -lc -Wl,.
CFLAGS += -Izig-out/include
zigsrcs=cmds/*.zig lib/*.zig
mods=--mod zigs::lib/zigs.zig --deps zigs -lc
target ?= x86_64-linux

#zigflags += -freference-trace  -fno-llvm -fno-lld
zigflags += -freference-trace


ifeq (${release},1)
zigflags += -Doptimize=ReleaseSmall -Dtarget=${target}
optimize=ReleaseSmall
else
CFLAGS += -ggdb -Wall
zigflags += -Doptimize=Debug -Dtarget=${target}
optimize=Debug
endif

test123: 
	zig build-exe ${zigflags} ./cmds/library_tester.zig -lc
	zig build-lib ${zigflags} ./libzigs/zigs_c.zig ${mods} --name zigs -dynamic
	@echo 'run: echo password | library_tester ./libzigs.so slowhash -'
	@echo '     should return'
	@echo dc470601a550fe8775efcd4c5ccdcb84042f3b88cf3bdbb59469d69aa0cf7c21

library: ./zig-out/lib/libzigs.so ./zig-out/lib/libzigs.a 
	@cp ./zig-out/lib/libzigs.so .
	file ./libzigs.so
	@printf 'ldd: '
	@ldd ./libzigs.so
default: all report
all: library zig-out/bin/tester example report

examples: bin/test-hash-c-static bin/test-hash-c-shared
	@echo done
zig-out/lib/libzigs.a: */*.zig
	@echo building ${@}
	${zig} build ${zigflags} lib
zig-out/lib/libzigs.so: */*.zig
	@echo building ${@}
	${zig} build ${zigflags} shared
report:
	@file zig-out/*/*
	@ldd zig-out/bin/* || true
	@sha256sum zig-out/bin/* || true
	@file zig-out/lib/* || true
	@nm -UW ./zig-out/lib/libzigs.a || true
	@nm -UW ./zig-out/lib/libzigs.so || true
zig-out/bin/examplezig: ${zigsrcs}
	${zig} build ${zigflags} examplezig
zig-out/bin/tester: ${zigsrcs}
	${zig} build ${zigflags} tester




bin/%: cmds/%.zig lib/*.zig   
	@mkdir -p bin    
	zig build-exe ${zigflags} ${mods} -femit-bin=$@ $<     
	@echo `ls -lh $@` `sha256sum $@` `file $@`     
bin/test-hash-c-static: testing/library-test-hash.c
	@mkdir -p bin
	${CC} ${CFLAGS} -ggdb -I. $^ -o $@ ./zig-out/lib/libzigs.a  -O3 -Doptimize=${optimize}
bin/test-hash-c-shared: testing/library-test-hash.c
	@mkdir -p bin
	${CC} ${CFLAGS} -ggdb -I. $^ -o $@ ./zig-out/lib/libzigs.so -O3 -Doptimize=${optimize} ${LDFLAGS} -lc 

clean:
	rm -rf bin zig-out */*.o */*.a */*.so *.a *.o *.so a.out
clean-all: clean
	rm -rf zig-cache

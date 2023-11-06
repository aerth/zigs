zigsrcs=cmds/*.zig lib/*.zig
target ?= x86_64-linux
ifeq (${release},1)
zigflags ?= -Doptimize=ReleaseSmall -Dtarget=${target}
else
zigflags ?= -Doptimize=Debug -Dtarget=${target}
endif
default: all
all: library zig-out/bin/tester example report
example: zig-out/bin/examplezig 
library: ./zig-out/lib/libzigs.a
zig-out/lib/libzigs.a: */*.zig
	zig build ${zigflags} install lib
	@file zig-out/lib/*
	@nm -gUW $@
	#nm -gUW ./zig-out/lib/libzigs.so || true
report:
	@file zig-out/*/*
	@ldd zig-out/bin/* || true
	@sha256sum zig-out/bin/*
zig-out/bin/examplezig: ${zigsrcs}
	zig build ${zigflags} examplezig
zig-out/bin/tester: ${zigsrcs}
	zig build ${zigflags} tester
bin/%: cmds/%.zig lib/*.zig   
	@mkdir -p bin    
	zig build-exe ${zigflags} -femit-bin=$@ $<     
	@echo `ls -lh $@` `sha256sum $@` `file $@`     
clean:
	rm -rf bin zig-cache zig-out

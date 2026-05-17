# Zenith Build System
# Builds the runtime C extension and links Zeta programs against it

ZETA_HOME = /home/zeta/.openclaw/workspace/zeta
ZETAC = $(ZETA_HOME)/bin/zetac
RUNTIME_O = $(ZETA_HOME)/runtime/zenith_runtime_c.o
OLD_RUNTIME_O = $(ZETA_HOME)/zeta_runtime_c.o

.PHONY: all runtime clean test

all: runtime

# Build the C runtime extension
runtime:
	cc -O2 -fPIC -msse4.2 -c $(ZETA_HOME)/runtime/zenith_runtime.c -o $(RUNTIME_O)
	@echo "Runtime built: $(RUNTIME_O)"

# Install runtime as the default (replaces zeta_runtime_c.o)
install: runtime
	cp $(RUNTIME_O) $(OLD_RUNTIME_O)
	@echo "Runtime installed as default"

# Build Zenith programs
build: runtime
	$(ZETAC) -o zenith_test tests/test_zenith.zeta \
		-L. -lzstd -lpthread $(RUNTIME_O)

# Run tests
test: build
	./zenith_test

# Clean
clean:
	rm -f $(RUNTIME_O)
	rm -f zenith_test

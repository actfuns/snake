.PHONY: all clean build skynet build-skynet

TOP=$(PWD)
CS_COMMON_DIR=./cs_common
BUILD_DIR=./build

INCLUDE_DIR=$(BUILD_DIR)/include
BUILD_CLUALIB_DIR=$(BUILD_DIR)/clualib
BUILD_CLIB_DIR=$(BUILD_DIR)/clib
BUILD_CSERVICE_DIR=$(BUILD_DIR)/cservice

#all instrunctions begin

all: build

cleanall:
	-rm -rf build/**
	$(CLEAN_ALL)

clean:
	-rm -rf build/**

#all instrunctions end

#create all dynamic dir begin

build:
	-mkdir $(INCLUDE_DIR)
	-mkdir $(BUILD_CLUALIB_DIR)
	-mkdir $(BUILD_CLIB_DIR)
	-mkdir $(BUILD_CSERVICE_DIR)

#create all dynamic dir end

#build skynet begin

all: skynet
SKYNET_MAKEFILE=skynet/Makefile

skynet: build-skynet
	install -p -m 0644 skynet/skynet-src/*.h $(INCLUDE_DIR)
	@echo 'make skynet finish'

SKYNET_DEP_PATH = BUILD_PATH=../build

build-skynet:
	cd skynet && $(MAKE) PLAT=linux $(SKYNET_DEP_PATH)
	install -p -m 0755 skynet/3rd/lua/lua $(BUILD_DIR)/lua
	install -p -m 0755 skynet/3rd/lua/luac $(BUILD_DIR)/luac
	install -p -m 0644 skynet/3rd/lua/*.h $(INCLUDE_DIR)
	install -d $(INCLUDE_DIR)/gdsl
	install -p -m 0644 skynet/3rd/gdsl/include/*.h $(INCLUDE_DIR)
	install -p -m 0644 skynet/3rd/gdsl/include/gdsl/*.h $(INCLUDE_DIR)/gdsl

define CLEAN_SKYNET
	cd skynet && $(MAKE) cleanall
endef

CLEAN_ALL += $(CLEAN_SKYNET)

#build skynet end

#build zinc begin

all: zinc

CFLAGS = -g3 -O2 -rdynamic -Wall -I$(INCLUDE_DIR)
LDFLAGS = -L$(BUILD_CLIB_DIR) -Wl,-rpath $(BUILD_CLIB_DIR) -pthread -lm -ldl -lrt
SHARED = -fPIC --shared

CLIB=rc4 pbc xor
CSERVICE=zinc_gate
CLUALIB=protobuf laoi gaoi ltimer lfs snapshot lsum ldes lpsum

CLIB_TARGET=$(patsubst %, $(BUILD_CLIB_DIR)/lib%.so, $(CLIB))
CSERVICE_TARGET=$(patsubst %, $(BUILD_CSERVICE_DIR)/%.so, $(CSERVICE))
CLUALIB_TARGET=$(patsubst %, $(BUILD_CLUALIB_DIR)/%.so, $(CLUALIB))



zinc: \
	$(CLIB_TARGET) \
	$(CSERVICE_TARGET) \
	$(CLUALIB_TARGET)
	
PROTOBUFSRC = \
  clib/lua-protobuf/context.c \
  clib/lua-protobuf/varint.c \
  clib/lua-protobuf/array.c \
  clib/lua-protobuf/pattern.c \
  clib/lua-protobuf/register.c \
  clib/lua-protobuf/proto.c \
  clib/lua-protobuf/map.c \
  clib/lua-protobuf/alloc.c \
  clib/lua-protobuf/rmessage.c \
  clib/lua-protobuf/wmessage.c \
  clib/lua-protobuf/bootstrap.c \
  clib/lua-protobuf/stringpool.c \
  clib/lua-protobuf/decode.c

#clib
$(BUILD_CLIB_DIR)/librc4.so : clib/rc4/rc4.c clib/rc4/rc4.h clib/rc4/conn_keys.h
	install -p -m 0644 clib/rc4/*.h $(INCLUDE_DIR)
	gcc $(CFLAGS) $(SHARED) $^ -o $@ 

$(BUILD_CLIB_DIR)/libxor.so : clib/xor/xor.c clib/xor/xor.h
	install -p -m 0644 clib/xor/*.h $(INCLUDE_DIR)
	gcc $(CFLAGS) $(SHARED) $^ -o $@ $(LDFLAGS)

$(BUILD_CLIB_DIR)/libpbc.so : $(PROTOBUFSRC)
	install -p -m 0644 clib/lua-protobuf/pbc.h $(INCLUDE_DIR)
	gcc $(CFLAGS) $(SHARED) $^ -o $@ $(LDFLAGS)

# cservice
$(BUILD_CSERVICE_DIR)/zinc_gate.so : clib/service-src/service_zinc_gate.c
	gcc $(CFLAGS) -Iskynet/service-src $(SHARED) $^ -o $@  $(LDFLAGS) -lrc4 -lxor

#clualib
$(BUILD_CLUALIB_DIR)/protobuf.so : clib/lua-protobuf/pbc-lua53.c $(BUILD_CLIB_DIR)/libpbc.so
	gcc $(CFLAGS) $(SHARED) $^ -o $@ $(LDFLAGS)

$(BUILD_CLUALIB_DIR)/laoi.so : clib/aoi/aoi.c clib/aoi/lua-aoi.c
	install -p -m 0644 clib/aoi/aoi.h $(INCLUDE_DIR)
	gcc $(CFLAGS) $(SHARED) $^ -o $@ $(LDFLAGS)

$(BUILD_CLUALIB_DIR)/gaoi.so : clib/gaoi/gaoi.c clib/gaoi/lua-gaoi.c
	install -p -m 0644 clib/gaoi/gaoi.h $(INCLUDE_DIR)
	gcc $(CFLAGS) $(SHARED) $^ -o $@ $(LDFLAGS)

$(BUILD_CLUALIB_DIR)/lsum.so : clib/sum/sum.c clib/sum/lua-sum.c
	install -p -m 0644 clib/sum/sum.h $(INCLUDE_DIR)
	gcc $(CFLAGS) $(SHARED) $^ -o $@ $(LDFLAGS)

$(BUILD_CLUALIB_DIR)/lpsum.so : clib/psum/psum.c clib/psum/lua-psum.c
	install -p -m 0644 clib/psum/psum.h $(INCLUDE_DIR)
	gcc $(CFLAGS) $(SHARED) $^ -o $@ $(LDFLAGS)

$(BUILD_CLUALIB_DIR)/ltimer.so : clib/timingwheel/twheel.c clib/timingwheel/lua-twheel.c clib/timingwheel/twheel.h
	install -p -m 0644 clib/timingwheel/twheel.h $(INCLUDE_DIR)
	gcc $(CFLAGS) $(SHARED) $^ -o $@ $(LDFLAGS)

$(BUILD_CLUALIB_DIR)/lfs.so: clib/luafilesystem/src/lfs.c
	install -p -m 0644 clib/luafilesystem/src/lfs.h $(INCLUDE_DIR)
	gcc $(CFLAGS) $(SHARED) $^ -o $@ $(LDFLAGS)

$(BUILD_CLUALIB_DIR)/snapshot.so : clib/snapshot/snapshot.c
	gcc $(CFLAGS) $(SHARED) $^ -o $@ $(LDFLAGS)

$(BUILD_CLUALIB_DIR)/ldes.so : clib/des/lua-des.c
	gcc $(CFLAGS) $(SHARED) $^ -o $@ $(LDFLAGS)

#build zinc end

all:
	@echo 'make finish'

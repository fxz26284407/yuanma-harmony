cmake_minimum_required(VERSION 3.16)
project(codex_mobile_noise_core C)
set(CMAKE_C_STANDARD 99)
if(NOT DEFINED NOISE_SOURCE)
  message(FATAL_ERROR "Set NOISE_SOURCE to the pinned Noise-C checkout")
endif()
set(N ${NOISE_SOURCE}/src)
file(GLOB PROTOCOL ${N}/protocol/*.c)
list(REMOVE_ITEM PROTOCOL ${N}/protocol/rand_sodium.c)
file(GLOB BACKEND ${N}/backend/ref/*.c)
set(CRYPTO
 ${N}/crypto/aes/rijndael-alg-fst.c ${N}/crypto/blake2/blake2b.c ${N}/crypto/blake2/blake2s.c
 ${N}/crypto/chacha/chacha.c ${N}/crypto/donna/poly1305-donna.c ${N}/crypto/ghash/ghash.c
 ${N}/crypto/newhope/batcher.c ${N}/crypto/newhope/error_correction.c ${N}/crypto/newhope/fips202.c
 ${N}/crypto/newhope/newhope.c ${N}/crypto/newhope/ntt.c ${N}/crypto/newhope/poly.c
 ${N}/crypto/newhope/precomp.c ${N}/crypto/newhope/reduce.c ${N}/crypto/newhope/crypto_stream_chacha20.c
 ${N}/crypto/sha2/sha256.c ${N}/crypto/sha2/sha512.c ${N}/crypto/ed25519/ed25519.c
 ${N}/crypto/curve448/curve448.c ${N}/crypto/goldilocks/src/p448/arch_ref64/p448.c)
add_library(noiseprotocol STATIC ${PROTOCOL} ${BACKEND} ${CRYPTO})
set_target_properties(noiseprotocol PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_compile_definitions(noiseprotocol PRIVATE ED25519_CUSTOMHASH ED25519_CUSTOMRANDOM)
target_include_directories(noiseprotocol PUBLIC ${NOISE_SOURCE}/include PRIVATE ${N} ${N}/protocol
 ${N}/crypto/goldilocks/src/include ${N}/crypto/goldilocks/src/p448 ${N}/crypto/goldilocks/src/p448/arch_ref64)

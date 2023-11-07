#include <stdio.h>

#include "zigs.h" // for fasthash, slowhash

void printHex(const unsigned char* input, size_t len,
              const unsigned char* prefix) {
  printf("%s: ", prefix);
  for (size_t i = 0; i < len; i++) {
    printf("%02x", input[i]);
  }
  printf("\n");
}

#define HASH_LEN 32
#define LOOP_SLOW 50
#define LOOP_FAST 1024 * 10

int main() {
  unsigned char in[32] = {0};
  size_t input_size = 0;
  unsigned char out[HASH_LEN] = {0};
  printf("hashing...\n");
  for (int i = 0; i < LOOP_SLOW; i++)
    if (slowhash(in, input_size, out)) {
      return -1;
    }
  printHex(out, HASH_LEN, "slow ");
  for (int i = 0; i < LOOP_FAST; i++)
    if (fasthash(in, input_size, out)) {
      return -1;
    }
  printHex(out, HASH_LEN, "fast");
}

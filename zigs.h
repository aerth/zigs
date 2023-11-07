#ifndef ZIGS_H
#define ZIGS_H
#define OUT
#define IN
#include <stddef.h>
int fasthash(IN const char *input, size_t len, OUT char *out);
int okayhash(IN const char *input, size_t len, OUT char *out);
int slowhash(IN const char *input, size_t len, OUT char *out);
#endif

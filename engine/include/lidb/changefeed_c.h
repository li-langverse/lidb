#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct lidb_changefeed lidb_changefeed;

lidb_changefeed* lidb_changefeed_open(const char* data_dir);
void lidb_changefeed_close(lidb_changefeed* handle);

uint64_t lidb_changefeed_subscribe(lidb_changefeed* handle, const char* table);
void lidb_changefeed_unsubscribe(lidb_changefeed* handle, uint64_t subscription_id);

uint64_t lidb_changefeed_native_insert(lidb_changefeed* handle, const char* table);

int lidb_changefeed_poll(lidb_changefeed* handle, char* buf, size_t cap, size_t* out_len);

int lidb_changefeed_serve_unix(lidb_changefeed* handle, const char* socket_path);

#ifdef __cplusplus
}
#endif

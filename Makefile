EXTENSION = hessra_pg
MODULES = hessra_pg
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)

# Add current directory for header lookup
PG_CPPFLAGS += -I.

# Link against the shared FFI library
SHLIB_LINK = -L. -lhessra_ffi

include $(PGXS)

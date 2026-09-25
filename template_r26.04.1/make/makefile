# Engulfment work directory for MESA r26.04.1: MESA's standard work makefile
# plus the energy module used by run_star_extras.

ifeq ($(MESA_DIR),)
ifeq ($($MESA_DIR_INTENTIONALLY_EMPTY),)
  $(error MESA_DIR environment variable is not set)
endif
endif

STAR = star
RUN_STAR_EXTRA_OBJS = energy.o

include $(MESA_DIR)/star/work_standard_makefile

run_star_extras.o: energy.o

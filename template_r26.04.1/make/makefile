# Engulfment work directory for MESA r26.04.1: MESA's standard work makefile plus the physics modules
# used by run_star_extras (one module per process, as in MESA-Engulf).

ifeq ($(MESA_DIR),)
ifeq ($($MESA_DIR_INTENTIONALLY_EMPTY),)
  $(error MESA_DIR environment variable is not set)
endif
endif

STAR = star
RUN_STAR_EXTRA_OBJS = grid.o potential.o planet.o drag.o tides.o heating.o orbit.o

include $(MESA_DIR)/star/work_standard_makefile

potential.o: grid.o
heating.o: grid.o
orbit.o: grid.o potential.o planet.o drag.o tides.o
run_star_extras.o: $(RUN_STAR_EXTRA_OBJS)

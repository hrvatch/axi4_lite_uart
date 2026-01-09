XRUN_ARGS+= -access +rwc 
XRUN_ARGS+= -sv
XRUN_ARGS+= -f $(AXI4_LITE_UART_PATH)/rtl/uart.f
XRUN_ARGS+= -timescale 1ns/1ps
XRUN_ARGS+= -errormax 10
XRUN_ARGS+= -nowarn CUVWSP
XRUN_ARGS+= -64bit

XRUN_SIM_ARGS+= $(AXI4_LITE_UART_PATH)/tb/simple_tb/tb_uart_top.sv
XRUN_SIM_ARGS+= -top tb_uart_top

.PHONY: compile clean sim_batch sim_gui

compile:
	xrun -c $(XRUN_ARGS)

clean:
	rm -rf xcelium.d xrun.log waves.shm xrun.history xrun.key .simvision

sim_batch:
	xrun $(XRUN_ARGS) $(XRUN_SIM_ARGS)

sim_gui:
	xrun $(XRUN_ARGS) $(XRUN_SIM_ARGS) -gui -input $(AXI4_LITE_UART_PATH)/sim/probe.tcl

help:
	@echo "Available targets:"
	@echo "  compile       - Compiles RTL"
	@echo "  sim_batch     - Starts Xcelium simulator in the batch mode"
	@echo "  sim_gui       - Starts Xcelium simulator in the GUI mode"
	@echo "  clean         - Remove simulation artifacts"

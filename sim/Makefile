XRUN_ARGS+= -access +rwc 
XRUN_ARGS+= -sv
XRUN_ARGS+= -f $(AXI4_LITE_UART_PATH)/rtl/uart.f
XRUN_ARGS+= -timescale 1ns/1ps
XRUN_ARGS+= -errormax 10
XRUN_ARGS+= -nowarn CUVWSP
XRUN_ARGS+= -64bit

XRUN_SIM_ARGS+= -top axi4_lite_uart_tb_top 

.PHONY: compile clean

compile:
	xrun -c $(XRUN_ARGS)

clean:
	rm -rf xcelium.d xrun.log waves.shm xrun.history xrun.key .simvision

help:
	@echo "Available targets:"
	@echo "  compile       - Compiles RTL"
	@echo "  clean         - Remove simulation artifacts"


# 12 MHz clock
create_clock -name clk_12 -period 83.333 [get_nets clk_12]

# 6 MHz clock
create_clock -name clk_6 -period 166.667 [get_nets clk_6]

# TODO: add additional clock constraints here

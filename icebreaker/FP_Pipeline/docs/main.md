---
title: "CSEx25 Floating Point Adder Lab"
geometry: margin=1in
fontsize: 11pt
output: pdf_document
---

\

**Copyright &copy; 2025 Ethan Sifferman.**

**All rights reserved. Distribution Prohibited.**

\newpage

## Submission

* Submit your code to the Gradescope autograder. (You have unlimited submission attempts).
* Demonstrate your implementation to a TA.

## Goals

You are provided a fully working combinational floating point adder. However, the Icestorm flow only synthesizes it to 6-8 MHz. You must modify the combinational floating point adder to now run at over 50 MHz.

You must also design your own testbench that utilizes fuzzing.

Once you finish your implementation, you will program it to your Icebreaker board.

## Prelab

1. Play around with the H-Schmidt IEEE754 Visualizer: <https://www.h-schmidt.net/FloatConverter/IEEE754.html>.
    a. Build an understanding of what the biased exponent, and the mantissa represent.
    b. Understand infinity and NaN.
    c. Understand subnormal numbers.

2. Read sections 18.1, 18.2, and 18.3 from *Computer Arithmetic: Algorithms and Hardware Designs* by B. Parhami (ISBN-13 978-0-19-532848-6). It will help you understand the floating point addition algorithm, and will give hints on how to increase frequency.

3. From the IEEE 1800-2023 Standard (https://ieeexplore.ieee.org/document/10458102), read the following sections:
    * 18.13

4. Read the explanation of this project's file structure: <https://github.com/sifferman/verilog_template?tab=readme-ov-file#file-explanations>.

## Lab

Notes:

* You do not need to support infinity, NaN, or subnormals other than &plusmn;0.
* To use the Basejump_STL and Alex Forencich UART IP, you must run the following:

```bash
# to download the git submodules
git submodule update --init --recursive
# if you don't have an ssh key set up, you can run the following to use https instead of ssh
git config --global url."https://github.com/".insteadOf "git@github.com:"
```

### Testbench

First, you should create a testbench to ensure that the provided floating point adder works.

In `"dv/dv_pkg.sv"`, implement `rand_raw_float()`. Observe the provided `"DPI-C"` functions that can convert between a `float_pkg::float_t` type and a SystemVerilog `real` type. These functions will be useful for verification.

Then, in `"dv/fp_add_tb.sv"`, you will need to create a clock, implement each of the stub functions and tasks, and add any other required functionality.

When driving data into a `ready`/`valid` interface, you must first assert `valid`, then wait for `ready`. The DUT will successfully receive the valid data if `ready` and `valid` are high for 1 full cycle. When monitoring data out of a `ready`/`valid` interface, you must first assert `ready`, then wait for `valid`. The DUT will successfully send the valid data if `ready` and `valid` are high for 1 full cycle.

When you have implemented all the functions and tasks, begin fuzzing the design. This means thoughtfully passing random input to the DUT. You will not be able to just send completely random float32s, as the chance that you encounter any one edge case is likely $2^{32}$. You must think about all the different ways that rounding could fail, or that unusual output will be created.

### Floating Point Adder Optimization

It is up to you to determine how to increase the frequency of the `fp_add` module. You may use any RTL that you have written in previous labs.

### Synthesis

You are provided a script to synthesize your design with Yosys for a generic target. You may then test the synthesized design by running post-synthesis simulation, or Gate-Level Simulation (GLS). If you pass `make sim`, but fail `make gls`, then you have either found a bug in the tools, or you are using a non-synthesizable feature.

You are also provided an Icebreaker top module: `"synth/icestorm_icebreaker/icebreaker.v"`. The provided implementation drives `fp_add` with a 6 MHz clock, which passes Nextpnr timing analysis. As you improve your `fp_add` module, keep checking what frequency Nextpnr could achieve. Your goal is to reach at least 50 MHz.

```bash
# run Icestorm flow for Icebreaker board
make synth/icestorm_icebreaker/build/icebreaker.bit
```

### FPGA

When you are confident your design works, you may program your Icebreaker. The `icebreaker` top module actually instantiates a module with a UART interface to allow communication between your PC and your FPGA. You can communicate with the Icebreaker using the provided Python script: `"synth/icestorm_icebreaker/send_fp_add_serial.py"`.

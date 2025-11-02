import os
# Import the CSE 125 utilities

import sys
_REPO_ROOT = os.getenv('REPO_ROOT')
assert (_REPO_ROOT), "REPO_ROOT must be defined in environment as a non-empty string"
assert (os.path.exists(_REPO_ROOT)), "REPO_ROOT path must exist"
sys.path.append(os.path.join(_REPO_ROOT, "util"))
from utilities import *

import random
random.seed(42)

import pytest
import pytest_utils
from pytest_utils.decorators import max_score, visibility, tags  

import cocotb

from cocotb_test.simulator import run
from cocotb.clock import Clock
from cocotb.regression import TestFactory
from cocotb.utils import get_sim_time
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, with_timeout
from cocotb.types import LogicArray, Range

DIR_PATH = os.path.dirname(os.path.realpath(__file__))

timescale = "1ps/1ps"
tests = ['reset_test',
         'single_test',
         "write_limit_test",
         "read_all_test",
         "write_and_reset",
         "conflict_test"
         ]

# Admittedly test_each approach is a bit hacky. If we treat Verilog
# parameters as pytest parameters, each parameterization runs all the
# tests within one simulation (fine, but not ideal). The drawback is
# that it is impossible to identify which test failed within a
# parameterization inside the simulation. Instead, we run each test
# individually by listing them as pytest parameters (but not a verilog
# parameters) so that they get tested individually.
@pytest.mark.parametrize("DataWidth,NumEntries", [(8, 8), (11, 17)])
@pytest.mark.parametrize("test_name", tests)
def test_each_runner(test_name, DataWidth, NumEntries):
    # This line must be first
    parameters = dict(locals())
    del parameters['test_name']
    runner(timescale, DIR_PATH, test_name, parameters)

# Opposite above, run all the tests in one simulation but reset
# between tests to ensure that reset is clearing all state.
@pytest.mark.parametrize("DataWidth,NumEntries", [(8, 8), (11, 17)])
@max_score(1)
def test_all_runner(DataWidth, NumEntries):
    # This line must be first
    parameters = dict(locals())
    runner(timescale, DIR_PATH, None, parameters)

@pytest.mark.parametrize("DataWidth,NumEntries", [(11, 17)])
@pytest.mark.skipif(not os.getenv('SIM').lower().startswith("verilator"), reason="Requires Verilator")
@max_score(0.5)
def test_lint(DataWidth, NumEntries):
    # This line must be first
    parameters = dict(locals())
    lint(timescale, DIR_PATH,["--lint-only"], parameters)

@pytest.mark.parametrize("DataWidth,NumEntries", [(11, 17)])
@pytest.mark.skipif(not os.getenv('SIM').lower().startswith("verilator"), reason="Requires Verilator")
@max_score(0.5)
def test_style(DataWidth, NumEntries):
    # This line must be first
    parameters = dict(locals())
    lint(timescale, DIR_PATH,["--lint-only", "-Wwarn-style", "-Wno-lint"], parameters)

async def reset(dut, reset_i, cycles, FinishFalling=True):
    # Wait for the next rising edge
    await RisingEdge(dut.clk_i)

    # Always assign inputs on the falling edge
    await FallingEdge(dut.clk_i)
    reset_i.value = 1

    await ClockCycles(dut.clk_i, cycles)

    # Always assign inputs on the falling edge
    await FallingEdge(dut.clk_i)
    reset_i.value = 0

    reset_i._log.debug("Reset complete")

    # Always assign inputs on the falling edge
    if (not FinishFalling):
        await RisingEdge(dut.clk_i)

async def wait_for_signal(dut, signal, value):
    signal = getattr(dut, signal)
    while(signal.value.is_resolvable and signal.value != value):
        await FallingEdge(dut.clk_i)

async def pretest_sequence(dut):
    # Set the clock to Z for 10 ns. This helps separate tests.
    dut.clk_i.value = LogicArray(['z'])
    await Timer(10, 'ns')

    # Unrealistically fast clock, but nice for mental math (1 GHz)
    c = Clock(dut.clk_i, 1, 'ns')

    # Start the clock (soon). Start it low to avoid issues on the first RisingEdge
    cocotb.start_soon(c.start(start_high=False))

async def reset_sequence(dut):
    clk_i = dut.clk_i
    reset_i = dut.reset_i

    wr_valid_i = dut.wr_valid_i
    wr_data_i = dut.wr_data_i
    wr_addr_i = dut.wr_addr_i

    rd_data_o = dut.rd_data_o
    rd_addr_i = dut.rd_addr_i

    inputs = [wr_valid_i, wr_data_i, wr_addr_i, rd_addr_i]
    
    for p in inputs:
        p.value = LogicArray(['x'] * len(p))

    await reset(dut, reset_i, cycles=10, FinishFalling=True)

    for p in inputs:
        p.value = 0

    await FallingEdge(clk_i)

    assert rd_data_o.value.is_resolvable, f"Unresolvable value in rd_data_o (x or z in some or all bits) at Time {get_sim_time(units='ns')}ns."

    
@cocotb.test()
async def reset_test(dut):
    """Test for Initialization"""

    await pretest_sequence(dut)
    await reset_sequence(dut)
    
@cocotb.test()
async def read_all_test(dut):
    """Test for Reading all Memory Addresses"""

    await pretest_sequence(dut)
    await reset_sequence(dut)

    clk_i = dut.clk_i
    wr_valid_i = dut.wr_valid_i
    wr_data_i = dut.wr_data_i
    wr_addr_i = dut.wr_addr_i

    rd_data_o = dut.rd_data_o
    rd_addr_i = dut.rd_addr_i
    rd_valid_i = dut.rd_valid_i

    inputs = [wr_valid_i, wr_data_i, wr_addr_i, rd_addr_i, rd_valid_i]

    depth = dut.NumEntries.value
    width = dut.DataWidth.value
    
    for p in inputs:
        p.value = 0

    await FallingEdge(clk_i)

    for i in range(0, dut.NumEntries.value):
        wr_addr_i.value = i
        wr_valid_i.value = 1
        s = bin(i)[2:]
        s = '0'* (width-len(s)) + s
        wr_data_i.value = LogicArray(s[0:width], Range(width-1,'downto', 0))

        await FallingEdge(clk_i)

    wr_addr_i.value = 0
    wr_valid_i.value = 0

    await FallingEdge(clk_i)

    for i in range(0, dut.NumEntries.value):
        rd_addr_i.value = i
        rd_valid_i.value = 1

        await FallingEdge(clk_i)
        s = bin(i)[2:]
        s = '0'* (width-len(s)) + s
        expected = LogicArray(s[0:width], Range(width-1,'downto', 0)).integer

        assert rd_data_o.value.is_resolvable, f"Unresolvable value (x or z in some or all bits) at Time {get_sim_time(units='ns')}ns."
        assert rd_data_o.value == expected, f"Incorrect result read from memory at index {i}: Expected {expected}. Got: {rd_data_o.value} at Time {get_sim_time(units='ns')}ns."


@cocotb.test()
async def single_test(dut):
    """Test for writing a single address"""

    await pretest_sequence(dut)
    await reset_sequence(dut)

    clk_i = dut.clk_i

    wr_valid_i = dut.wr_valid_i
    wr_data_i = dut.wr_data_i
    wr_addr_i = dut.wr_addr_i

    rd_data_o = dut.rd_data_o
    rd_addr_i = dut.rd_addr_i
    rd_valid_i = dut.rd_valid_i

    inputs = [wr_valid_i, wr_data_i, wr_addr_i, rd_addr_i, rd_valid_i]

    depth = dut.NumEntries.value
    width = dut.DataWidth.value

    for p in inputs:
        p.value = 0

    await FallingEdge(clk_i)

    s = '0110' * width
    wr_addr_i.value = 0
    wr_data_i.value = LogicArray(s[0:width], Range(width-1,'downto', 0))
    wr_valid_i.value = 1

    await FallingEdge(clk_i)

    wr_addr_i.value = 0
    wr_data_i.value = 0
    wr_valid_i.value = 0

    rd_addr_i.value = 0
    rd_valid_i.value = 1
    expected = LogicArray(s[0:width]).integer

    await FallingEdge(clk_i)
    
    assert rd_data_o.value.is_resolvable, f"Unresolvable value (x or z in some or all bits) at Time {get_sim_time(units='ns')}ns."
    assert rd_data_o.value == expected, f"Incorrect result read back from address 0: Expected {expected}. Got: {rd_data_o.value} at Time {get_sim_time(units='ns')}ns."

    rd_addr_i.value = 0
    rd_valid_i.value = 0

@cocotb.test()
async def write_limit_test(dut):
    """Test for the first and last addresses"""

    await pretest_sequence(dut)
    await reset_sequence(dut)

    clk_i = dut.clk_i

    wr_valid_i = dut.wr_valid_i
    wr_data_i = dut.wr_data_i
    wr_addr_i = dut.wr_addr_i

    rd_data_o = dut.rd_data_o
    rd_addr_i = dut.rd_addr_i
    rd_valid_i = dut.rd_valid_i

    inputs = [wr_valid_i, wr_data_i, wr_addr_i, rd_addr_i, rd_valid_i]

    depth = dut.NumEntries.value
    width = dut.DataWidth.value

    for p in inputs:
        p.value = 0

    await FallingEdge(clk_i)

    s = '01' * width
    wr_addr_i.value = 0
    wr_data_i.value = LogicArray(s[0:width], Range(width-1,'downto', 0))
    wr_valid_i.value = 1

    await FallingEdge(clk_i)

    wr_addr_i.value = depth - 1
    wr_data_i.value = LogicArray(s[1:width + 1], Range(width-1,'downto', 0))
    wr_valid_i.value = 1

    await FallingEdge(clk_i)

    wr_addr_i.value = 0
    wr_data_i.value = 0
    wr_valid_i.value = 0

    # Wait a bit, to see what happens.
    await FallingEdge(clk_i)
    await FallingEdge(clk_i)
    await FallingEdge(clk_i)

    rd_addr_i.value = 0
    rd_valid_i.value = 1
    expected = LogicArray(s[0:width]).integer

    await FallingEdge(clk_i)
    
    assert rd_data_o.value.is_resolvable, f"Unresolvable value (x or z in some or all bits) at Time {get_sim_time(units='ns')}ns."
    assert rd_data_o.value == expected, f"Incorrect result read back from address 0: Expected {expected}. Got: {rd_data_o.value} at Time {get_sim_time(units='ns')}ns."

    rd_addr_i.value = depth-1
    rd_valid_i.value = 1
    expected = LogicArray(s[1:width + 1], Range(width-1,'downto', 0)).integer

    await FallingEdge(clk_i)
    
    assert rd_data_o.value.is_resolvable, f"Unresolvable value (x or z in some or all bits) at Time {get_sim_time(units='ns')}ns."
    assert rd_data_o.value == expected, f"Incorrect result read from address {NumEntries-1}: Expected {expected}. Got: {rd_data_o.value} at Time {get_sim_time(units='ns')}ns."

@cocotb.test()
async def write_and_reset(dut):
    """Test for writing while under reset"""

    await pretest_sequence(dut)
    await reset_sequence(dut)

    clk_i = dut.clk_i
    reset_i = dut.reset_i

    wr_valid_i = dut.wr_valid_i
    wr_data_i = dut.wr_data_i
    wr_addr_i = dut.wr_addr_i

    rd_data_o = dut.rd_data_o
    rd_addr_i = dut.rd_addr_i
    rd_valid_i = dut.rd_valid_i

    inputs = [wr_valid_i, wr_data_i, wr_addr_i, rd_addr_i, rd_valid_i]

    depth = dut.NumEntries.value
    width = dut.DataWidth.value

    for p in inputs:
        p.value = 0

    await FallingEdge(clk_i)

    s = '11' * width
    wr_addr_i.value = 1
    wr_data_i.value = LogicArray(s[0:width], Range(width - 1,'downto', 0))
    wr_valid_i.value = 1

    await FallingEdge(clk_i)

    wr_addr_i.value = 0
    wr_data_i.value = 0
    wr_valid_i.value = 0

    # Wait a bit, to see what happens.
    await FallingEdge(clk_i)
    await FallingEdge(clk_i)
    await FallingEdge(clk_i)

    s = '0' * width
    wr_addr_i.value = 1
    reset_i.value = 1
    wr_data_i.value = LogicArray(s[0:width], Range(width - 1,'downto', 0))
    wr_valid_i.value = 1

    await FallingEdge(clk_i)

    wr_addr_i.value = 1
    reset_i.value = 0
    wr_data_i.value = LogicArray(s[0:width], Range(width - 1,'downto', 0))
    wr_valid_i.value = 0

    await FallingEdge(clk_i)
    await FallingEdge(clk_i)
    await FallingEdge(clk_i)

    rd_addr_i.value = 1
    rd_valid_i.value = 1
    s = '1' * width
    expected = LogicArray(s[0:width]).integer

    await FallingEdge(clk_i)
    
    assert rd_data_o.value.is_resolvable, f"Unresolvable value (x or z in some or all bits) at Time {get_sim_time(units='ns')}ns."
    assert rd_data_o.value == expected, f"Incorrect result. Writing during reset should not affect memory contents. Expected {expected}. Got: {rd_data_o.value} at Time {get_sim_time(units='ns')}ns."


@cocotb.test()
async def conflict_test(dut):
    """Test for writing and reading the same address"""

    await pretest_sequence(dut)
    await reset_sequence(dut)

    clk_i = dut.clk_i
    reset_i = dut.reset_i

    wr_valid_i = dut.wr_valid_i
    wr_data_i = dut.wr_data_i
    wr_addr_i = dut.wr_addr_i

    rd_data_o = dut.rd_data_o
    rd_addr_i = dut.rd_addr_i
    rd_valid_i = dut.rd_valid_i

    inputs = [wr_valid_i, wr_data_i, wr_addr_i, rd_addr_i, rd_valid_i]

    depth = dut.NumEntries.value
    width = dut.DataWidth.value

    for p in inputs:
        p.value = 0

    await FallingEdge(clk_i)

    # Write address 1
    s = '11' * width
    wr_addr_i.value = 1
    wr_data_i.value = LogicArray(s[0:width], Range(width - 1,'downto', 0))
    wr_valid_i.value = 1

    await FallingEdge(clk_i)

    wr_addr_i.value = 0
    wr_data_i.value = 0
    wr_valid_i.value = 0

    # Wait a bit, to see what happens.
    await FallingEdge(clk_i)
    await FallingEdge(clk_i)
    await FallingEdge(clk_i)

    # Write address 1 again, with a different value
    # also read.
    s = '0' * width
    wr_addr_i.value = 1
    rd_addr_i.value = 1
    rd_valid_i.value = 1
    wr_data_i.value = LogicArray(s[0:width], Range(width - 1,'downto', 0))
    wr_valid_i.value = 1

    await FallingEdge(clk_i)

    wr_valid_i.value = 0
    # Old value
    s = '1' * width
    expected = LogicArray(s[0:width]).integer
    
    assert rd_data_o.value.is_resolvable, f"Unresolvable value (x or z in some or all bits) at Time {get_sim_time(units='ns')}ns."
    assert rd_data_o.value == expected, f"Incorrect result. Reading while writing the same address should return old data after one cycle. Expected {expected}. Got: {rd_data_o.value} at Time {get_sim_time(units='ns')}ns."

    await FallingEdge(clk_i)

    # New value
    s = '0' * width
    expected = LogicArray(s[0:width]).integer

    assert rd_data_o.value.is_resolvable, f"Unresolvable value (x or z in some or all bits) at Time {get_sim_time(units='ns')}ns."
    assert rd_data_o.value == expected, f"Incorrect result. Reading while writing the same address should return new data after two cycles. Expected {expected}. Got: {rd_data_o.value} at Time {get_sim_time(units='ns')}ns."

import pytest
import os
import pytest_utils
from pytest_utils.decorators import max_score, visibility, tags

import sys
_REPO_ROOT = os.getenv('REPO_ROOT')
assert (_REPO_ROOT), "REPO_ROOT must be defined in environment as a non-empty string"
assert (os.path.exists(_REPO_ROOT)), "REPO_ROOT path must exist"
sys.path.append(os.path.join(_REPO_ROOT, "util"))
from utilities import *

from cocotb_test.simulator import run
import cocotb
from cocotb.clock import Clock
from cocotb.regression import TestFactory
from cocotb.utils import get_sim_time
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, with_timeout
from cocotb.types import LogicArray
import json
import random
random.seed(42)

DIR_PATH = os.path.dirname(os.path.realpath(__file__))

timescale = "1ps/1ps"
tests = ['reset_test',
         'single_cycle_test_001',
         'single_cycle_test_002',
         'single_cycle_test_003',
         'single_cycle_test_004',
         'limit_test_001',
         'limit_test_002',
         'fuzz_test_001',
         'fuzz_test_002',
         'fuzz_test_003'
         ]

# Admittedly test_each approach is a bit hacky. If we treat Verilog
# parameters as pytest parameters, each parameterization runs all the
# tests within one simulation (fine, but not ideal). The drawback is
# that it is impossible to identify which test failed within a
# parameterization inside the simulation. Instead, we run each test
# individually by listing them as pytest parameters (but not a verilog
# parameters) so that they get tested individually.
@pytest.mark.parametrize("ResetValue,MaxValue", [(1, 3), (11, 67), (30, 31), (0, 11)])
@pytest.mark.parametrize("test_name", tests)
def test_each_runner(test_name, ResetValue, MaxValue):
    # This line must be first
    parameters = dict(locals())
    del parameters['test_name']
    runner(timescale, DIR_PATH, test_name, parameters)

# Opposite above, run all the tests in one simulation but reset
# between tests to ensure that reset is clearing all state.
@pytest.mark.parametrize("ResetValue,MaxValue", [(1, 3), (11, 67), (30, 31), (0, 11)])
@max_score(.5)
def test_all_runner(ResetValue, MaxValue):
    # This line must be first
    # This line must be first
    parameters = dict(locals())
    runner(timescale, DIR_PATH, None, parameters)

@pytest.mark.skipif(not os.getenv('SIM').lower().startswith("verilator"), reason="Requires Verilator")
@pytest.mark.parametrize("ResetValue, MaxValue", [(11, 67)])
@max_score(.5)
def test_lint(ResetValue, MaxValue):
    # This line must be first
    parameters = dict(locals())
    lint(timescale, DIR_PATH,["--lint-only"], parameters)

@pytest.mark.skipif(not os.getenv('SIM').lower().startswith("verilator"), reason="Requires Verilator")
@pytest.mark.parametrize("ResetValue, MaxValue", [(11, 67)])
@max_score(.5)
def test_style(ResetValue, MaxValue):
    # This line must be first
    parameters = dict(locals())
    lint(timescale, DIR_PATH,["--lint-only", "-Wwarn-style", "-Wno-lint"], parameters)

class CounterModel():
    def __init__(self, DataWidth, ResetValue, MaxValue,
                 clk_i, reset_i, up_i, down_i, count_o):
        self._DataWidth = DataWidth.value
        self._ResetValue = ResetValue.value
        self._MaxValue = MaxValue.value
        self._clk_i = clk_i
        self._reset_i = reset_i
        self._up_i = up_i
        self._down_i = down_i
        self._count_o = count_o
        self._coro_run = None
        self._count = 0

    def start(self):
        """Start model"""
        if self._coro_run is not None:
            raise RuntimeError("Model already started")
        self._coro_run = cocotb.start_soon(self._run())

    async def _run(self):
        while True:
            await RisingEdge(self._clk_i)
            if(not(self._reset_i.value.is_resolvable)):
                pass
            elif(self._reset_i.value == 1):
                self._count = self._ResetValue
            elif(not(self._up_i.value.is_resolvable and self._down_i.value.is_resolvable)):
                pass
            elif(self._up_i.value and self._down_i.value):
                pass # Do nothing
            elif(self._up_i.value and not self._down_i.value and (self._count != self._MaxValue)):
                self._count += 1
            elif(self._up_i.value and not self._down_i.value):
                self._count = 0
            elif(not self._up_i.value and self._down_i.value and (self._count != 0)):
                self._count -= 1
            elif(not self._up_i.value and self._down_i.value):
                self._count = self._MaxValue
      
    def stop(self) -> None:
        """Stop monitor"""
        if self._coro_run is None:
            raise RuntimeError("Monitor never started")
         
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
    
@cocotb.test()
async def reset_test(dut):
    """Test for Initialization"""

    # Set the clock to Z for 10 ns. This helps separate tests.
    dut.clk_i.value = LogicArray(['z'])
    await Timer(10, 'ns')

    # Unrealistically fast clock, but nice for mental math (1 GHz)
    c = Clock(dut.clk_i, 1, 'ns')

    # Start the clock (soon). Start it low to avoid issues on the first RisingEdge
    cocotb.start_soon(c.start(start_high=False))
    model = CounterModel(dut.DataWidth, dut.ResetValue, dut.MaxValue, dut.clk_i, dut.reset_i, dut.up_i, dut.down_i, dut.count_o)
    model.start()

    reset_i = dut.reset_i
    up_i = dut.up_i
    down_i = dut.down_i
    count_o = dut.count_o

    up_i.value = LogicArray(['x'])
    down_i.value = LogicArray(['x'])

    await RisingEdge(dut.clk_i)

    await reset(dut, dut.reset_i, cycles=10, FinishFalling=True)

    # Set the initial inputs
    up_i.value = 0
    down_i.value = 0

    await FallingEdge(dut.clk_i)

    assert count_o.value.is_resolvable, f"Unresolvable value (x or z in some or all bits) at Time {get_sim_time(units='ns')}ns."
    assert count_o.value == model._count , f"Incorrect Result: count_o != {model._count}. Got: {count_o.value} at Time {get_sim_time(units='ns')}ns."

async def single_cycle_test(dut, up, down):
    """Single-cycle test for basic (up/down) functionality"""

    # Set the clock to Z for 10 ns. This helps separate tests.
    dut.clk_i.value = LogicArray(['z'])
    await Timer(10, 'ns')
    
    # Unrealistically fast clock, but nice for mental math (1 ns period == 1 GHz Frequency)
    c = Clock(dut.clk_i, 1, 'ns')

    # Start the clock (soon). Start it low to avoid issues on the first RisingEdge
    cocotb.start_soon(c.start(start_high=False))
    model = CounterModel(dut.DataWidth, dut.ResetValue, dut.MaxValue, dut.clk_i, dut.reset_i, dut.up_i, dut.down_i, dut.count_o)
    model.start()

    reset_i = dut.reset_i
    up_i = dut.up_i
    down_i = dut.down_i
    count_o = dut.count_o

    up_i.value = LogicArray(['x'])
    down_i.value = LogicArray(['x'])

    await RisingEdge(dut.clk_i)

    await reset(dut, dut.reset_i, cycles=10, FinishFalling=True)

    # Always Set Inputs on the falling edge
    up_i.value = 0
    down_i.value = 0

    # Increment once.
    await FallingEdge(dut.clk_i)
    up_i.value = up
    down_i.value = down
    
    await FallingEdge(dut.clk_i)

    # Check after one cycle of up
    assert count_o.value.is_resolvable, f"Unresolvable value (x or z in some or all bits) at Time {get_sim_time(units='ns')}ns."
    assert count_o.value == model._count , f"Incorrect Result: count_o != {model._count}. Got: {count_o.value} at Time {get_sim_time(units='ns')}ns."

    # Value should remain constant.
    up_i.value = up
    down_i.value = down

    await FallingEdge(dut.clk_i)

    assert count_o.value.is_resolvable, f"Unresolvable value (x or z in some or all bits) at Time {get_sim_time(units='ns')}ns."
    assert count_o.value == model._count , f"Incorrect Result: count_o != {model._count}. Got: {count_o.value} at Time {get_sim_time(units='ns')}ns."

tf = TestFactory(test_function=single_cycle_test)
tf.add_option(name='up', optionlist=[0,1])
tf.add_option(name='down', optionlist=[0,1])
tf.generate_tests()

async def wait_for(dut, value):
    while(dut.count_o.value.is_resolvable and dut.count_o.value != value):
        await FallingEdge(dut.clk_i)

async def limit_test(dut, up, down):
    """Test for MaxValue/0 limits."""

    # Set the clock to Z for 10 ns. This helps separate tests.
    dut.clk_i.value = LogicArray(['z'])
    await Timer(10, 'ns')
    
    # Unrealistically fast clock, but nice for mental math (1 ns period == 1 GHz Frequency)
    c = Clock(dut.clk_i, 1, 'ns')

    # Start the clock (soon). Start it low to avoid issues on the first RisingEdge
    cocotb.start_soon(c.start(start_high=False))
    model = CounterModel(dut.DataWidth, dut.ResetValue, dut.MaxValue, dut.clk_i, dut.reset_i, dut.up_i, dut.down_i, dut.count_o)
    model.start()

    reset_i = dut.reset_i
    up_i = dut.up_i
    down_i = dut.down_i
    count_o = dut.count_o

    up_i.value = LogicArray(['x'])
    down_i.value = LogicArray(['x'])

    await RisingEdge(dut.clk_i)

    await reset(dut, dut.reset_i, cycles=10, FinishFalling=True)

    # Always Set Inputs on the falling edge
    up_i.value = 0
    down_i.value = 0
    
    await FallingEdge(dut.clk_i)
    up_i.value = up
    down_i.value = down

    if(up):
        value = dut.MaxValue.value
        timeout = dut.MaxValue.value - dut.ResetValue.value + 1

    elif(down):
        value = 0
        timeout = 2*dut.ResetValue.value + 1
    
    await with_timeout(wait_for(dut, value=value), timeout, 'ns')

    # Increment once more.
    await FallingEdge(dut.clk_i)

    assert count_o.value.is_resolvable, f"Unresolvable value (x or z in some or all bits) at Time {get_sim_time(units='ns')}ns."
    assert count_o.value == model._count_o , f"Incorrect Result: count_o != {model._count_o}. Got: {count_o.value} at Time {get_sim_time(units='ns')}ns."

tf = TestFactory(test_function=limit_test)
tf.add_option(('up', 'down'), [(1, 0), (0, 1)])
tf.generate_tests()

async def fuzz_test(dut, l):
    """Test for Random Input"""

    # Set the clock to Z for 10 ns. This helps separate tests.
    dut.clk_i.value = LogicArray(['z'])
    await Timer(10, 'ns')

    # Unrealistically fast clock, but nice for mental math (1 GHz)
    c = Clock(dut.clk_i, 1, 'ns')

    # Start the clock (soon). Start it low to avoid issues on the first RisingEdge
    cocotb.start_soon(c.start(start_high=False))
    model = CounterModel(dut.DataWidth, dut.ResetValue, dut.MaxValue, dut.clk_i, dut.reset_i, dut.up_i, dut.down_i, dut.count_o)
    model.start()

    reset_i = dut.reset_i
    up_i = dut.up_i
    down_i = dut.down_i
    count_o = dut.count_o

    up_i.value = LogicArray(['x'])
    down_i.value = LogicArray(['x'])

    await RisingEdge(dut.clk_i)

    await reset(dut, dut.reset_i, cycles=10, FinishFalling=True)

    # Set the initial inputs
    up_i.value = 0
    down_i.value = 0

    await FallingEdge(dut.clk_i)

    seq = [random.randint(0, 4) for i in range(l)]
    for i in seq:
        await FallingEdge(dut.clk_i)
        up_i.value = (i == 1 or i == 3)
        down_i.value = (i == 2 or i == 3)
        assert count_o.value.is_resolvable, f"Unresolvable value (x or z in some or all bits) at Time {get_sim_time(units='ns')}ns."
        assert count_o.value == model._count_o , f"Incorrect Result: count_o != {model._count_o}. Got: {count_o.value} at Time {get_sim_time(units='ns')}ns."
    

tf = TestFactory(test_function=fuzz_test)
tf.add_option(name='l', optionlist=[10, 100, 1000])
tf.generate_tests()

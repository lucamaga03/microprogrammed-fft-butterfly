-- =============================================================================
-- TB_FFT_16.vhd
-- Testbench of the 16-point FFT. Clock period: 100 ns.
-- X_OUT = DFT(x_IN) / 32.
-- The real parts go in with START, the imaginary parts one cycle later.
-- The real parts of X_OUT come out with FINAL_DONE = '1', the imaginary
-- parts one cycle later.
-- Numbers in brackets are hex values, as in the waveforms. An output of 0 can
-- also be FFFFFF (-1 LSB): a small rounding error.
--
-- Part 1 (same timing as the screenshots in the report):
--   test 1 alone (single mode), then tests 2..6 one every 6 cycles (continuous
--   mode). Only real inputs. FINAL_DONE at 5400, 6600, 7200, 7800, 8400, 9000 ns.
-- Part 2: test with complex inputs (all inputs = -1 - j). FINAL_DONE at 14100 ns.
-- Part 3: synchronous reset while a test is running. That test is lost
--   (no FINAL_DONE); the next two tests work: FINAL_DONE at 19700, 20300 ns.
-- After part 3 the test process stops.
-- =============================================================================
library IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.NUMERIC_STD.all;
USE work.my_types_pkg.all;

ENTITY TB_FFT_16 IS
END TB_FFT_16;

ARCHITECTURE Behavior OF TB_FFT_16 IS
-- 16 inputs and 16 outputs. In the aggregates below the first value is
-- index 15, the last value is index 0.
SIGNAL x_IN_val,X_OUT_val:  S_array(15 downto 0)(23 downto 0);
SIGNAL CLK_INT, FINAL_DONE: std_logic;
SIGNAL START_INT : std_logic := '0';
-- resets, active low
SIGNAL RST_INT, RST_SINC_INT: std_logic := '1';

    COMPONENT FFT_16 IS
        PORT(
            CLK,RES, RES_SINC, START: IN    std_logic;
            x_IN:   IN  S_array(15 downto 0)(23 downto 0);  -- all the inputs x
            DONE:   out std_logic;
            X_OUT:  OUT S_array(15 downto 0)(23 downto 0)); -- all the outputs X
    END COMPONENT;

BEGIN
    test: FFT_16 PORT MAP(
        CLK=> CLK_INT,RES=> RST_INT,RES_SINC=> RST_SINC_INT,START=> START_INT,
        x_IN=>x_IN_val,
        DONE=>FINAL_DONE,
        X_OUT=>x_OUT_val);


    -- clock: period 100 ns
    clock: PROCESS
    BEGIN
        CLK_INT <= '1';
        WAIT FOR 50 ns;
        CLK_INT <= '0';
        WAIT FOR 50 ns;
    END PROCESS clock;

stimuli: PROCESS
BEGIN

-- asynchronous reset at the start
Wait for 80 ns;
RST_INT <= '0';
Wait for 100 ns;
RST_INT <= '1';
Wait for 720 ns;

-----------------------------------------------------------------------
-- PART 1: the 6 tests of the report (only real inputs)
-----------------------------------------------------------------------

-- Test 1: all inputs -1 (800000).
-- Expected: X(0) = -0.5 (C00000), all the other X = 0 (000000 or FFFFFF).
Wait for 125 ns;
START_INT<='1';
x_IN_val <= (
    "100000000000000000000000",
    "100000000000000000000000",
    "100000000000000000000000",
    "100000000000000000000000",
    "100000000000000000000000",
    "100000000000000000000000",
    "100000000000000000000000",
    "100000000000000000000000",
    "100000000000000000000000",
    "100000000000000000000000",
    "100000000000000000000000",
    "100000000000000000000000",
    "100000000000000000000000",
    "100000000000000000000000",
    "100000000000000000000000",
    "100000000000000000000000"
);

-- imaginary parts: 0
Wait for 100 ns;
START_INT<='0';
x_IN_val <= (others => (others => '0'));


-- Test 2: x = -1, 0, +1, 0, -1, ... (from index 0). -1 = 800000, +1 = 7FFFFF.
-- Expected: X(4) = X(12) = -0.25 (E00000), all the other X = 0.
Wait for 1100 ns;
START_INT<='1';
x_IN_val <= (
    "000000000000000000000000",
    "011111111111111111111111",
    "000000000000000000000000",
    "100000000000000000000000",
    "000000000000000000000000",
    "011111111111111111111111",
    "000000000000000000000000",
    "100000000000000000000000",
    "000000000000000000000000",
    "011111111111111111111111",
    "000000000000000000000000",
    "100000000000000000000000",
    "000000000000000000000000",
    "011111111111111111111111",
    "000000000000000000000000",
    "100000000000000000000000"
);

-- imaginary parts: 0
Wait for 100 ns;
START_INT<='0';
x_IN_val <= (others => (others => '0'));


-- Test 3: x(0) = +1 (7FFFFF), all the other inputs 0.
-- Expected: all X = 1/32 = 0.03125 (040000; the waveforms show 03FFFF, 1 LSB less).
-- From here the tests come every 6 cycles (continuous mode).
Wait for 500 ns;
START_INT<='1';
x_IN_val <= (
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "011111111111111111111111"
);

-- imaginary parts: 0
Wait for 100 ns;
START_INT<='0';
x_IN_val <= (others => (others => '0'));


-- Test 4: x = -1, -1, +1, +1, -1, -1, ... (from index 0).
-- Expected: X(4) = -0.25 + 0.25j (real E00000, imag. 200000),
--           X(12) = -0.25 - 0.25j (real E00000, imag. E00000), all the other X = 0.
Wait for 500 ns;
START_INT<='1';
x_IN_val <= (
    "011111111111111111111111",
    "011111111111111111111111",
    "100000000000000000000000",
    "100000000000000000000000",
    "011111111111111111111111",
    "011111111111111111111111",
    "100000000000000000000000",
    "100000000000000000000000",
    "011111111111111111111111",
    "011111111111111111111111",
    "100000000000000000000000",
    "100000000000000000000000",
    "011111111111111111111111",
    "011111111111111111111111",
    "100000000000000000000000",
    "100000000000000000000000"
);

-- imaginary parts: 0
Wait for 100 ns;
START_INT<='0';
x_IN_val <= (others => (others => '0'));


-- Test 5: x(0..8) = +0.5 (400000), x(9..15) = -0.5 (C00000).
-- Expected: X(k) = 0.03125 (03FFFF) for k even.
-- For k odd X is imaginary only. Imaginary parts of X(1), X(3), ..., X(15):
--   -0.1571 (EBE402), -0.0468 (FA037A), -0.0209 (FD53C9), -0.0062 (FF3450),
--   +0.0062 (00CBAF), +0.0209 (02AC36), +0.0468 (05FC86), +0.1571 (141BFE).
Wait for 500 ns;
START_INT<='1';
x_IN_val <= (
    "110000000000000000000000", -- index 15 (-0.5 = C00000)
    "110000000000000000000000", -- index 14 (-0.5 = C00000)
    "110000000000000000000000", -- index 13 (-0.5 = C00000)
    "110000000000000000000000", -- index 12 (-0.5 = C00000)
    "110000000000000000000000", -- index 11 (-0.5 = C00000)
    "110000000000000000000000", -- index 10 (-0.5 = C00000)
    "110000000000000000000000", -- index 9 (-0.5 = C00000)
    "010000000000000000000000", -- index 8 (+0.5 = 400000)
    "010000000000000000000000", -- index 7 (+0.5 = 400000)
    "010000000000000000000000", -- index 6 (+0.5 = 400000)
    "010000000000000000000000", -- index 5 (+0.5 = 400000)
    "010000000000000000000000", -- index 4 (+0.5 = 400000)
    "010000000000000000000000", -- index 3 (+0.5 = 400000)
    "010000000000000000000000", -- index 2 (+0.5 = 400000)
    "010000000000000000000000", -- index 1 (+0.5 = 400000)
    "010000000000000000000000"  -- index 0 (+0.5 = 400000)
);

-- imaginary parts: 0
Wait for 100 ns;
START_INT<='0';
x_IN_val <= (others => (others => '0'));


-- Test 6: x(8) = +0.75 (600000), all the other inputs 0.
-- Expected: X(k) = +0.0234 (030000; the waveforms show 02FFFF) for k even,
--           X(k) = -0.0234 (FD0000) for k odd.
Wait for 500 ns;
START_INT<='1';
x_IN_val <= (
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "011000000000000000000000", -- index 8 (+0.75 = 600000)
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000"
);

-- imaginary parts: 0
Wait for 100 ns;
START_INT<='0';
x_IN_val <= (others => (others => '0'));


-- wait for the end of part 1 (last FINAL_DONE at 9000 ns)
wait for 5000 ns;

-----------------------------------------------------------------------
-- PART 2: complex inputs
-----------------------------------------------------------------------

-- Test 7: all inputs -1 - j (real and imag. 800000).
-- Expected: X(0) = -0.5 - 0.5j (real C00000, imag. C00000), all the other X = 0.
-- real parts
START_INT<='1';
x_IN_val <= (others => "100000000000000000000000");

-- imaginary parts
Wait for 100 ns;
START_INT<='0';
x_IN_val <= (others => "100000000000000000000000");

-- wait for the end of part 2
Wait for 5000 ns;
x_IN_val <= (others => (others => '0'));

-----------------------------------------------------------------------
-- PART 3: synchronous reset during a computation
-----------------------------------------------------------------------

-- Test 8: same inputs as test 4. The reset below stops it: no FINAL_DONE.
START_INT<='1';
x_IN_val <= (
    "011111111111111111111111",
    "011111111111111111111111",
    "100000000000000000000000",
    "100000000000000000000000",
    "011111111111111111111111",
    "011111111111111111111111",
    "100000000000000000000000",
    "100000000000000000000000",
    "011111111111111111111111",
    "011111111111111111111111",
    "100000000000000000000000",
    "100000000000000000000000",
    "011111111111111111111111",
    "011111111111111111111111",
    "100000000000000000000000",
    "100000000000000000000000"
);

-- imaginary parts: 0
Wait for 100 ns;
START_INT<='0';
x_IN_val <= (others => (others => '0'));

-- synchronous reset pulse (one clock cycle)
Wait for 200 ns;
RST_SINC_INT <= '0';
Wait for 100 ns;
RST_SINC_INT <= '1';
Wait for 100 ns;

-- Test 9: same inputs as test 5, after the reset. Same results as test 5.
START_INT<='1';
x_IN_val <= (
    "110000000000000000000000", -- index 15 (-0.5 = C00000)
    "110000000000000000000000", -- index 14 (-0.5 = C00000)
    "110000000000000000000000", -- index 13 (-0.5 = C00000)
    "110000000000000000000000", -- index 12 (-0.5 = C00000)
    "110000000000000000000000", -- index 11 (-0.5 = C00000)
    "110000000000000000000000", -- index 10 (-0.5 = C00000)
    "110000000000000000000000", -- index 9 (-0.5 = C00000)
    "010000000000000000000000", -- index 8 (+0.5 = 400000)
    "010000000000000000000000", -- index 7 (+0.5 = 400000)
    "010000000000000000000000", -- index 6 (+0.5 = 400000)
    "010000000000000000000000", -- index 5 (+0.5 = 400000)
    "010000000000000000000000", -- index 4 (+0.5 = 400000)
    "010000000000000000000000", -- index 3 (+0.5 = 400000)
    "010000000000000000000000", -- index 2 (+0.5 = 400000)
    "010000000000000000000000", -- index 1 (+0.5 = 400000)
    "010000000000000000000000"  -- index 0 (+0.5 = 400000)
);

-- imaginary parts: 0
Wait for 100 ns;
START_INT<='0';
x_IN_val <= (others => (others => '0'));

-- Test 10: same inputs as test 6 (continuous mode, 6 cycles after test 9)
Wait for 500 ns;
START_INT<='1';
x_IN_val <= (
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "011000000000000000000000", -- index 8 (+0.75 = 600000)
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000",
    "000000000000000000000000"
);

-- imaginary parts: 0
Wait for 100 ns;
START_INT<='0';
x_IN_val <= (others => (others => '0'));

-- end of the tests: the process stops here
wait;
END process stimuli;
END Behavior;

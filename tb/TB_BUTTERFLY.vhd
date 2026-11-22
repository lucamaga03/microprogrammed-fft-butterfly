-- =============================================================================
-- TB_BUTTERFLY.vhd
-- Testbench of one butterfly. Clock period: 100 ns.
-- Four tests with complex A, B, W, one every 6 cycles (continuous mode).
-- All the tests use SF_2H_1L = '1': A' = (A + B*W) / 4, B' = (A - B*W) / 4.
-- The real parts of A' and B' come out with DONE = '1', the imaginary parts
-- one cycle later.
-- Numbers in brackets are hex values, as in the waveforms.
-- START edges at 800, 1400, 2000, 2600 ns -> DONE at 1800, 2400, 3000, 3600 ns.
-- =============================================================================
library IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.NUMERIC_STD.all;

ENTITY TB_BUTTERFLY IS
END TB_BUTTERFLY;

ARCHITECTURE TestBench_Butterfly_Behavior OF TB_BUTTERFLY IS


    SIGNAL A_IN_INT, B_IN_INT, WI_INT, WR_INT : signed(23 downto 0);
    SIGNAL A1_Out_INT1, B1_Out_INT1 : signed(23 downto 0);   -- A' and B'
    SIGNAL CLK_INT, DONE_INT1: std_logic;
    SIGNAL SHIFT_INT : std_logic := '1';   -- SF_2H_1L, the same ('1') in all the tests
    SIGNAL START_INT : std_logic := '0';
    -- resets, active low
    SIGNAL RST_SINC_INT : std_logic := '1';
    SIGNAL RST_INT : std_logic := '1';
    COMPONENT BUTTERFLY IS
    PORT( -- Inputs
            CLK,RES,RES_SINC, START,SF_2H_1L: IN    std_logic;
            WR,WI:          IN  signed(23 downto 0);
            x1_IN,x2_IN:    IN  signed(23 downto 0);
            -- Outputs
            X1_OUT,X2_OUT:  OUT signed(23 downto 0);
            DONE:           OUT std_logic);
    END COMPONENT;

BEGIN
    ---------------------------------------------------------------------
    B1: Butterfly PORT MAP(
        RES_SINC => RST_SINC_INT,
        RES    => RST_INT,
        CLK    => CLK_INT,
        SF_2H_1L  => SHIFT_INT,
        START  => START_INT,
        DONE   => DONE_INT1,
        x1_IN  => A_IN_INT,
        x2_IN  => B_IN_INT,
        WR      => WR_INT,
        WI      => WI_INT,
        X1_OUT => A1_Out_INT1,
        X2_OUT => B1_Out_INT1
    );
    ----------------------------------------------------------------------

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
    START_INT <= '0';
    RST_INT   <= '0';

    WAIT FOR 125 ns;
    RST_INT   <= '1';

    WAIT FOR 600 ns;

    -- Test 1: A = 0.000012, B = -0.1192 + 1.0j, W = -0.6667 - 0.00003j
    -- Expected: A' = +0.0199 - 0.1667j (real 028B63, imag. EAAAB2)
    --           B' = -0.0199 + 0.1667j (real FD74CE, imag. 15554E)
    -- real parts
    START_INT <= '1';
    A_IN_INT <= "000000000000000001100100"; -- Ar = +100 (000064)
    B_IN_INT <= "111100001011110111000000"; -- Br = -1000000 (F0BDC0)
    WR_INT    <= "101010101010101010101010"; -- Wr = -5592406 (AAAAAA)
    SHIFT_INT<= '1';
    WAIT FOR 100 ns;

    -- imaginary parts
    START_INT <= '0';
    A_IN_INT <= "000000000000000000000000"; -- Ai = 0 (000000)
    B_IN_INT <= "011111111111111111111111"; -- Bi = +8388607 (7FFFFF)
    WI_INT    <= "111111111111111100000001"; -- Wi = -255 (FFFF01)

    WAIT FOR 500 ns;

    -- Test 2: A = 0.1472 - 0.0000001j, B = -0.6623 - 1.0j, W = 0.000005 + 1.0j
    -- Expected: A' = +0.2868 - 0.1656j (real 24B59A, imag. EACE9C)
    --           B' = -0.2132 + 0.1656j (real E4B5A9, imag. 153163)
    -- real parts
    START_INT <= '1';
    A_IN_INT <= to_signed(1234567, 24); -- Ar (12D687)
    B_IN_INT <= to_signed(-5555555, 24); -- Br (AB3A9D)
    WR_INT <= to_signed(42, 24);-- Wr (00002A)
    SHIFT_INT<= '1';

    WAIT FOR 100 ns;

    -- imaginary parts
    START_INT <= '0';
    A_IN_INT <= to_signed(-1, 24); -- Ai (FFFFFF)
    B_IN_INT <= to_signed(-8388608, 24); -- Bi (800000)
    WI_INT <= to_signed(8388607, 24); -- Wi (7FFFFF)

    WAIT FOR 500 ns;


    -- Test 3: A = 0.0625 + 0.1875j, B = 0, W = 1
    -- Expected: A' = B' = +0.0156 + 0.0469j (real 01FFFF, imag. 060000)
    -- real parts
    START_INT <= '1';
    A_IN_INT <= "000001111111111111111101"; -- Ar (07FFFD)
    B_IN_INT <= "000000000000000000000000"; -- Br (000000)
    WR_INT <= "011111111111111111111111";-- Wr (7FFFFF)
    SHIFT_INT<= '1';

    WAIT FOR 100 ns;

    -- imaginary parts
    START_INT <= '0';
    A_IN_INT <= "000110000000000000000000"; -- Ai (180000)
    B_IN_INT <= "000000000000000000000000"; -- Bi (000000)
    WI_INT <= (others => '0');

    WAIT FOR 500 ns;



    -- Test 4: as test 3, but B = -2 - 1j LSB (very small negative values)
    -- Expected: A' = B' = +0.0156 + 0.0469j
    --   A' = real 01FFFF, imag. 05FFFF; B' = real 01FFFF, imag. 060000 (1 LSB of difference)
    -- real parts
    START_INT <= '1';
    A_IN_INT <= "000001111111111111111101"; -- Ar (07FFFD)
    B_IN_INT <= "111111111111111111111110"; -- Br (FFFFFE)
    WR_INT <= "011111111111111111111111";-- Wr (7FFFFF)
    SHIFT_INT<= '1';
    WAIT FOR 100 ns;

    -- imaginary parts
    START_INT <= '0';
    A_IN_INT <= "000110000000000000000000"; -- Ai (180000)
    B_IN_INT <= "111111111111111111111111"; -- Bi (FFFFFF)
    WI_INT <= (others => '0');


    WAIT FOR 500 ns;


    WAIT FOR 500 ns;

    -- end of the tests: the process stops here
    WAIT;
END PROCESS stimuli;

END TestBench_Butterfly_Behavior;

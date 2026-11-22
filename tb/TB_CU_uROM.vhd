-- =============================================================================
-- TB_CU_uROM.vhd
-- Testbench of the microprogrammed Control Unit alone. Clock period: 100 ns.
--  - START edge at 200 ns: the CU leaves IDLE (STATE 1 ... STATE 6).
--  - START edge at 800 ns, while the CU is in STATE 6: continuous mode.
--  - START edge at 2000 ns, in STATE 6 again, after a run with no new data:
--    Y is reset, so the next run goes through STATE 5_NODONE.
-- FINAL_DONE (bit 0 of VETT_OUT) is high in STATE 5_DONE: at 1200, 1800, 3000 ns.
-- =============================================================================
library IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.NUMERIC_STD.all;
USE work.my_types_pkg.all;

ENTITY TB_CU_uROM IS
END TB_CU_uROM;

ARCHITECTURE Behavior OF TB_CU_uROM IS

SIGNAL VETT_OUT_INT : STD_LOGIC_VECTOR(18 DOWNTO 0);   -- controls + DONE
SIGNAL CLK_INT, FINAL_DONE: std_logic;
SIGNAL START_INT : std_logic := '0';
-- resets, active low
SIGNAL RST_INT: std_logic := '1';
SIGNAL RST_SINC_INT: std_logic := '1';   -- not used by the test: always '1'


    COMPONENT CU_uROM IS
    PORT(   CLK, START, RESET_ASINC, RESET_SINC:    IN  STD_LOGIC;
            VETT_OUT : OUT STD_LOGIC_VECTOR(18 DOWNTO 0));
    END COMPONENT ;
BEGIN
    test: CU_uROM PORT map(CLK=> CLK_INT, START=>START_INT, RESET_ASINC=> RST_INT,
                           RESET_SINC=> RST_SINC_INT, VETT_OUT => VETT_OUT_INT );

    FINAL_DONE <= VETT_OUT_INT(0);


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

-- asynchronous reset
Wait for 115 ns;
RST_INT <= '0';
Wait for 50 ns;
RST_INT <= '1';

-- first START (seen on the edge at 200 ns)
Wait for 10 ns;
START_INT<='1';

Wait for 100 ns;
START_INT<='0';

-- second START (edge at 800 ns): the CU is in STATE 6, so it goes on
-- without passing through IDLE (continuous mode)
wait for 500 ns;
START_INT<='1';

Wait for 100 ns;
START_INT<='0';

-- third START (edge at 2000 ns): the CU is in STATE 6 again
Wait for 1100 ns;
START_INT<='1';

Wait for 100 ns;
START_INT<='0';

-- end of the tests: the process stops here
wait for 5000 ns;
wait;
END process stimuli;
END Behavior;

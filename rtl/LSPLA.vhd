-- =============================================================================
-- LSPLA.vhd
-- Late Status PLA of the CU. It gives the LSB of the next state code, so it
-- chooses the EVEN or the ODD uROM word. It works as a 4-to-1 mux with select CC:
--   CC = 00 -> no jump: OUT_LSB = LSB from the uIR (normal sequence)
--   CC = 01 -> IDLE:    OUT_LSB = START (1: go to STATE 1, 0: stay in IDLE)
--   CC = 10 -> STATE 4: OUT_LSB = Y (1: STATE 5_DONE, 0: STATE 5_NODONE)
--   CC = 11 -> STATE 6: OUT_LSB = START OR PREV_START (1: STATE 1, 0: IDLE)
-- =============================================================================
LIBRARY ieee ;
USE ieee.std_logic_1164.all ;
USE ieee.numeric_std.all ;
USE work.my_types_pkg.all;

ENTITY LSPLA IS
    PORT(   LSB, Y, START, PREV_START:  IN      STD_LOGIC;   -- status inputs
            CC:     IN      STD_LOGIC_VECTOR(1 DOWNTO 0);    -- Condition Code
            OUT_LSB:    OUT     STD_LOGIC                    -- LSB of the next state
            );
    END LSPLA;

ARCHITECTURE Behavior OF LSPLA IS


BEGIN

-- Sum of products: each term is one input of the 4-to-1 mux (see the table above)
OUT_LSB <= (LSB and not CC(1) and not CC(0)) or
           (START and not CC(1) and CC(0)) or
           (Y and CC(1) and not CC(0)) or
           ((START OR PREV_START) and CC(1) and CC(0));


END ARCHITECTURE;

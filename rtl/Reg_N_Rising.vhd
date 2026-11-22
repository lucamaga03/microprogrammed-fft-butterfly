-- =============================================================================
-- Reg_N_Rising.vhd
-- N_BIT register on the rising edge, with load enable and two resets.
-- The CU uses it as uIR: both resets load the IDLE microinstruction.
-- =============================================================================
LIBRARY ieee ;
USE ieee.std_logic_1164.all ;

ENTITY Reg_N_Rising IS
    GENERIC ( N_BIT : INTEGER :=  23);   -- register width, in bits
    PORT (D :   IN      STD_LOGIC_VECTOR(N_BIT-1 downto 0);
          CLK:  IN      STD_LOGIC;
          -- LD: load enable; RES_NOSYNC: asynchronous reset; RES_SYNC: synchronous reset
          LD, RES_NOSYNC, RES_SYNC:     IN      STD_LOGIC;
          Q :   OUT     STD_LOGIC_VECTOR(N_BIT-1 downto 0)) ;
END Reg_N_Rising;


ARCHITECTURE Behavior OF Reg_N_Rising  IS

BEGIN
-- Both resets are active low.
-- The reset value is the IDLE microinstruction (EVEN uROM, address 00).

PROCESS(CLK,RES_NOSYNC)
    BEGIN
        IF(RES_NOSYNC = '0') THEN
            -- asynchronous reset: it works at once, without the clock
            Q <= "01000000000000000000010";
        ELSIF(Rising_edge(CLK)) THEN
            IF (RES_SYNC='0') THEN
                -- synchronous reset: it works only on the rising edge
                Q <= "01000000000000000000010";
            ELSIF(LD='1') THEN
                Q<=D;
            END IF;
        END IF;

END PROCESS;


END Behavior;

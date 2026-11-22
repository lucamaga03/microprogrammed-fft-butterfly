-- =============================================================================
-- Reg_N_Falling.vhd
-- N_BIT register on the falling edge, with load enable and asynchronous reset.
-- The CU uses it as uAR (address of the next microinstruction).
-- =============================================================================
LIBRARY ieee ;
USE ieee.std_logic_1164.all ;

ENTITY Reg_N_Falling IS
    GENERIC ( N_BIT : INTEGER :=  3);    -- register width, in bits
    PORT (D :   IN      STD_LOGIC_VECTOR(N_BIT-1 downto 0);
          CLK:  IN      STD_LOGIC;
          -- LD: load enable; RES_NOSYNC: asynchronous reset
          LD, RES_NOSYNC :  IN      STD_LOGIC;
          Q :   OUT     STD_LOGIC_VECTOR(N_BIT-1 downto 0)) ;
END Reg_N_Falling;


ARCHITECTURE Behavior OF Reg_N_Falling  IS

BEGIN
-- The asynchronous reset is active low and clears the register.

Process(CLK, RES_NOSYNC)
    BEGIN
        IF(RES_NOSYNC = '0') THEN
            Q <= (OTHERS => '0');

        ELSIF(Falling_edge(CLK)) THEN

            -- the register is loaded on the falling edge, not on the rising edge
            IF(LD='1') THEN
                Q<=D;
            END IF;


        END IF;
END PROCESS;
END Behavior;

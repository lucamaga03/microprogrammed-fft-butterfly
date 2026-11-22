-- =============================================================================
-- Reg.vhd
-- Single flip-flop with load enable: Q takes D on the rising edge if LD = '1'.
-- =============================================================================
LIBRARY ieee ;
USE ieee.std_logic_1164.all ;

ENTITY Reg IS
    PORT (D :   IN      STD_LOGIC;   -- data in
          CLK:  IN      STD_LOGIC;
          LD :  IN      STD_LOGIC;   -- load enable, active high
          Q :   OUT     STD_LOGIC) ; -- data out
END Reg ;


ARCHITECTURE Behavior OF Reg IS

BEGIN

Process(CLK)
    BEGIN

    If(Rising_edge(CLK)) THen

        -- without LD the flip-flop keeps its old value
        if(LD='1') THEN
            Q<=D;
        END IF;


    END IF;
 END PROCESS;
END Behavior ;

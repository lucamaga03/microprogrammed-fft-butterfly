-- =============================================================================
-- SUBTRACTOR.vhd
-- 49-bit subtractor with one pipeline stage: O = A - B, ready one clock cycle later.
-- =============================================================================
LIBRARY ieee ;
USE ieee.std_logic_1164.all ;
USE ieee.numeric_std.all;

ENTITY   SUBTRACTOR IS
    PORT( A, B: IN  signed(48 downto 0);    -- A = minuend, B = subtrahend (Q3.46 format)
          CLK:  IN  std_logic;
          O:    OUT signed(48 downto 0));   -- difference, saved on the rising edge
    END SUBTRACTOR ;

ARCHITECTURE Behavior OF SUBTRACTOR IS



BEGIN

-- The difference is computed at once and saved in O on the rising edge of CLK.
SUB_PROCESS: process(A,B,clk)
    variable DIFFERENCE: signed(48 downto 0);
BEGIN
    DIFFERENCE:= A - B;
    IF (rising_edge(CLK) ) THEN
        O<=  DIFFERENCE;
    END if;
END process SUB_PROCESS;

END Behavior;

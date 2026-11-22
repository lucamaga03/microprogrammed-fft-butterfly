-- =============================================================================
-- ADDER.vhd
-- 49-bit adder with one pipeline stage: O = A + B, ready one clock cycle later.
-- =============================================================================
LIBRARY ieee ;
USE ieee.std_logic_1164.all ;
USE ieee.numeric_std.all;

ENTITY ADDER IS
    PORT( A, B: IN  signed(48 downto 0);    -- operands (Q3.46 format)
          CLK:  IN  std_logic;
          O:    OUT signed(48 downto 0));   -- sum, saved on the rising edge
    END ADDER ;

ARCHITECTURE Behavior OF ADDER IS
BEGIN

-- The sum is computed at once and saved in O on the rising edge of CLK.
ADD_PROCESS: process(A,B,clk)
    variable SUM: signed(48 downto 0);
BEGIN

    SUM:= A + B;
    IF (rising_edge(CLK) ) THEN
        O<=  SUM;
    END if;

END process ADD_PROCESS;

END Behavior;

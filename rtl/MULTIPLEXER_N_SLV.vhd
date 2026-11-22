-- =============================================================================
-- MULTIPLEXER_N_SLV.vhd
-- Generic multiplexer for std_logic_vector data: 2**N_Base inputs of data_width
-- bits, all packed in one vector. Input k is in bits (k+1)*data_width-1 .. k*data_width.
-- The CU uses it (2-to-1, 23 bits) to choose the EVEN or the ODD uROM word.
-- =============================================================================
LIBRARY ieee ;
USE ieee.std_logic_1164.all ;
USE ieee.numeric_std.all;
USE work.my_types_pkg.all;

entity MULTIPLEXER_N_SLV is
    generic(
        N_Base : integer := 1;       -- number of select bits (2**N_Base inputs)
        data_width: integer := 23);  -- width of each input, in bits
    port(
        -- select: input k is chosen when S = k
        S: in std_logic_vector(N_Base-1 downto 0);
        -- all the inputs, one after the other (input 0 in the lowest bits)
        data : in std_logic_vector (((data_width*(2**N_base))-1)downto 0);
        -- output = input number S
        DOUT : out std_logic_vector(data_width-1 downto 0));
    end MULTIPLEXER_N_SLV;

ARCHITECTURE Behavior OF MULTIPLEXER_N_SLV IS

BEGIN

PROCESS(S,data)
    variable v_sel : integer;

BEGIN
    -- A variable changes at once, so the next line already uses the new value.
    v_sel := to_integer(unsigned(S));
    -- take the bits of input number v_sel
    DOUT <= data((((v_sel+1)*data_width)-1) downto ((v_sel)*data_width));
END PROCESS;

END Behavior;

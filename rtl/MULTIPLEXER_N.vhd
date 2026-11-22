-- =============================================================================
-- MULTIPLEXER_N.vhd
-- Generic multiplexer for signed data: 2**N_Base inputs of data_width bits each.
-- With the default generics it is a 2-to-1 multiplexer on 49 bits.
-- =============================================================================
LIBRARY ieee ;
USE ieee.std_logic_1164.all ;
USE ieee.numeric_std.all;
USE work.my_types_pkg.all;

entity MULTIPLEXER_N is
    generic(
        N_Base : integer := 1;       -- number of select bits (2**N_Base inputs)
        data_width: integer :=49);   -- width of each input, in bits
    port(
        -- select: input k is chosen when S = k
        S: in std_logic_vector( N_Base-1 downto 0);
        -- inputs, data(0) to data(2**N_Base - 1)
        data : in S_array((2**N_Base)-1 downto 0)(data_width-1 downto 0);
        -- output = data(S)
        DOUT : out signed( data_width-1 downto 0));
    end MULTIPLEXER_N;



ARCHITECTURE Behavior OF MULTIPLEXER_N IS
BEGIN

PROCESS(S,data)
    variable v_sel : integer;

BEGIN
    -- A variable changes at once, so the next line already uses the new value.
    v_sel := to_integer(unsigned(S));
    DOUT <= data(v_sel);
END PROCESS;

END Behavior;

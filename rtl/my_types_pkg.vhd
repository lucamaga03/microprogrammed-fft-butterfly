-- =============================================================================
-- my_types_pkg.vhd
-- Array types shared by the datapath and by the FFT top level.
-- =============================================================================
LIBRARY ieee ;
USE ieee.std_logic_1164.all ;
USE ieee.numeric_std.all;

package my_types_pkg is
    -- Array of signed vectors. The width of each element is chosen where the
    -- type is used (VHDL-2008). Used for register groups and multiplexer inputs.
    type S_array is array (natural range <>) of signed;
    -- Array of integers (used for the twiddle-factor indexes of the FFT).
    type INT_array is array (natural range <>) of integer;
end package;

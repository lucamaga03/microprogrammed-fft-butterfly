-- =============================================================================
-- REG_NxM.vhd
-- Group of N_Line registers of data_width bits, each with its own load enable.
-- Register i takes DIN(i) on the rising edge if LOAD_EN(i) = '1'.
-- =============================================================================
LIBRARY ieee ;
USE ieee.std_logic_1164.all ;
USE ieee.numeric_std.all;
USE work.my_types_pkg.all;

entity REG_NxM is
    generic(
        N_Line : integer := 6;        -- number of registers
        data_width: integer :=49);    -- width of each register, in bits
    port(
        CLK: in std_logic;
        -- one load enable for each register, active high
        LOAD_EN: in std_logic_vector((N_Line-1) downto 0);
        DIN :  in   S_array(N_Line-1 downto 0)(data_width-1 downto 0) ;  -- data in
        DOUT : out  S_array(N_Line-1 downto 0)(data_width-1 downto 0));  -- data out
    end REG_NxM;



ARCHITECTURE Behavior OF REG_NxM IS
SIGNAL selector: std_logic_vector( (N_Line-1) downto 0);   -- copy of LOAD_EN
BEGIN
selector<=LOAD_EN;
LOAD_PROCESS: process(CLK)
BEGIN
    If(Rising_edge(CLK)) THEN
        -- each register is loaded only if its own enable is high
        FOR i in 0 to (N_Line-1) LOOP
            if( selector(i)='1' ) THEN
                DOUT(i)<=DIN(i);
            END IF;
        END LOOP;
    END IF;
END PROCESS;

END Behavior;

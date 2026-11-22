-- =============================================================================
-- BUTTERFLY.vhd
-- Radix-2 butterfly: A' = A + B*W, B' = A - B*W, then shift right by 1 or 2.
-- It joins the Control Unit (CU_uROM) and the datapath (BUTTERFLY_DATAPATH).
-- Inputs: the real parts with START, the imaginary parts one clock cycle later.
-- Outputs: the real parts of A' and B' with DONE, the imaginary parts one cycle later.
-- =============================================================================
LIBRARY ieee ;
USE ieee.std_logic_1164.all ;
USE ieee.numeric_std.all;
USE work.my_types_pkg.all;

ENTITY BUTTERFLY IS
    PORT( -- Inputs
            -- RES: asynchronous reset, RES_SINC: synchronous reset (both active low).
            -- SF_2H_1L: final shift right, '1' = by 2 positions, '0' = by 1 position
            CLK,RES,RES_SINC,START,SF_2H_1L: IN  std_logic;
            WR,WI:          IN  signed(23 downto 0);    -- twiddle factor W (Q1.23)
            x1_IN,x2_IN:    IN  signed(23 downto 0);    -- x1_IN = A, x2_IN = B (Q1.23)
            -- Outputs
            X1_OUT,X2_OUT:  OUT signed(23 downto 0);    -- X1_OUT = A', X2_OUT = B'
            DONE:           OUT std_logic);             -- real parts of A', B' are valid
    END BUTTERFLY;

ARCHITECTURE Behavior OF BUTTERFLY IS


-- Control vector from the CU: bits 18..1 go to the datapath, bit 0 is DONE
signal VETT_OUT: std_logic_vector(18 downto 0);


Component CU_uROM IS
    PORT(   CLK, START, RESET_ASINC, RESET_SINC:    IN  STD_LOGIC;
            VETT_OUT : OUT STD_LOGIC_VECTOR(18 DOWNTO 0));
    END Component ;


Component BUTTERFLY_DATAPATH IS
    PORT(   -- From the CU
            VETT_OUT : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
            -- From outside the butterfly
            CLK,SF_2H_1L:   IN      STD_LOGIC;
            WR,WI:          IN      signed(23 downto 0);
            x1_IN,x2_IN:    IN      signed(23 downto 0);
            -- Outputs
            X1_OUT,X2_OUT:  OUT     signed(23 downto 0));
    END Component ;

BEGIN

-- Control Unit
CU  : CU_uROM PORT MAP(CLK=> CLK, START=> START, RESET_ASINC=> RES, RESET_SINC=>RES_SINC,
                       VETT_OUT=>VETT_OUT);


DONE<=VETT_OUT(0);

-- Datapath
DP : BUTTERFLY_DATAPATH PORT MAP(
            -- From the CU
            VETT_OUT=>VETT_OUT(18 downto 1),
            -- From outside the butterfly
            CLK=> CLK,SF_2H_1L=>SF_2H_1L,
            WR=>WR,WI=>WI,
            x1_IN=>x1_IN,x2_IN=>x2_IN,
            -- Outputs
            X1_OUT=>X1_OUT,X2_OUT=>X2_OUT);


END Behavior;

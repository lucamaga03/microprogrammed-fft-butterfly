-- =============================================================================
-- BUTTERFLY_DATAPATH.vhd
-- Datapath of the butterfly: A' = A + B*W, B' = A - B*W = 2A - A'.
-- Units: one multiplier/shifter (2 pipeline stages for A*B, 1 for 2*A),
--        one adder and one subtractor (1 pipeline stage each).
-- Formats: inputs and outputs are 24 bits, Q1.23. Inside, the adder and the
--          subtractor work on 49 bits, Q3.46, with no truncation.
-- At the end the result is shifted right by 1 or 2 (SF_2H_1L) and rounded to 24 bits.
-- All the controls come from the CU through VETT_OUT.
-- =============================================================================
LIBRARY ieee ;
USE ieee.std_logic_1164.all ;
USE ieee.numeric_std.all;
USE work.my_types_pkg.all;


ENTITY BUTTERFLY_DATAPATH IS
    PORT(   -- From the CU (bit 0 of the CU vector, DONE, does not come here)
            VETT_OUT : IN STD_LOGIC_VECTOR(18 DOWNTO 1);
            -- From outside the butterfly
            -- SF_2H_1L: final shift right, '1' = by 2 positions, '0' = by 1 position
            CLK,SF_2H_1L:   IN      STD_LOGIC;
            -- WR, WI: twiddle factor W (WR is loaded first, WI one cycle later)
            WR,WI:          IN      signed(23 downto 0);
            -- x1_IN = A, x2_IN = B (real part first, imaginary part one cycle later)
            x1_IN,x2_IN:    IN      signed(23 downto 0);
            -- Outputs: X1_OUT = A', X2_OUT = B' (real part first, then imaginary part)
            X1_OUT,X2_OUT:  OUT     signed(23 downto 0));
    END BUTTERFLY_DATAPATH ;

ARCHITECTURE Behavior OF BUTTERFLY_DATAPATH IS

-- Control signals (taken from VETT_OUT)
SIGNAL SEL_X_IN1, SEL_SUB_IN2 : STD_LOGIC_VECTOR(1 DOWNTO 0);
SIGNAL SEL_A, SEL_X_IN2, SEL_SH_OUT, SEL_SUB_IN1, SEL_ADD_IN2 : STD_LOGIC;
SIGNAL SEL_ADD_OUT, SEL_SUB_OUT, SEL_ROUND, SEL_OUT_B: STD_LOGIC;
SIGNAL FF_INR_EN, FF_INI_EN, FF_SH_EN1, FF_SH_EN2,SHN_MUL: STD_LOGIC;

-- Input registers for A, B, W (6 registers of 24 bits) and for SF_2H_1L
SIGNAL INPUT_REG_EN: std_logic_vector(5 downto 0);
SIGNAL INPUT_REG_DIN, INPUT_REG_DOUT: S_array(5 downto 0)(23 downto 0);
-- Outputs of the input registers
SIGNAL Q_A_REAL, Q_A_IMAG, Q_W_REAL, Q_W_IMAG, Q_B_REAL, Q_B_IMAG : signed(23 downto 0);
SIGNAL MUX_A_DATA_IN: S_array(1 downto 0)(23 downto 0);   -- inputs of MUX_A
SIGNAL A_SELECTED_49BIT: signed(48 downto 0);   -- output of MUX_A on 49 bits (Q3.46)
SIGNAL Q_SF_2H_1L_STAGE1, Q_SF_2H_1L_STAGE2 :std_logic;   -- SF_2H_1L, saved twice

-- Inputs of the multiplexer on multiplier input 1 (MUX_X_IN1)
SIGNAL MUX_X_IN1_DATA_IN: S_array(3 downto 0)(23 downto 0);

-- Inputs of the multiplexer on multiplier input 2 (MUX_X_IN2)
SIGNAL MUX_X_IN2_DATA_IN: S_array(1 downto 0)(23 downto 0);

-- Multiplier / shifter
SIGNAL X_IN1, X_IN2 : signed(23 downto 0);    -- multiplier inputs
SIGNAL MUL_OUT,Q_MUL: signed(47 downto 0);    -- product (Q2.46) and its register
-- SH_OUT = 2*A (25 bits); Q_SH1, Q_SH2: two registers in series after it
SIGNAL SH_OUT,Q_SH1,Q_SH2 : signed(24 downto 0);
SIGNAL MUX_SH_OUT_DATA_IN:  S_array(1 downto 0)(24 downto 0);   -- inputs of MUX_SH_OUT
SIGNAL Q_SH1_DIN:   signed(24 downto 0);   -- output of MUX_SH_OUT = input of Q_SH1


-- Inputs of the multiplexer on adder input 2 (MUX_ADD_IN2)
SIGNAL MUX_ADD_IN2_DATA_IN : S_array(1 downto 0)(48 downto 0);

-- Adder
SIGNAL ADD_IN1, ADD_IN2, ADD_OUT : signed(48 downto 0);    -- inputs and output
SIGNAL MUX_ADD_OUT_DATA_IN:  S_array(1 downto 0)(48 downto 0);   -- inputs of MUX_ADD_OUT
SIGNAL Q_ADD_DIN:   signed(48 downto 0);   -- output of MUX_ADD_OUT = input of Q_ADD
SIGNAL Q_ADD : signed(48 downto 0);        -- adder register


-- Subtractor
SIGNAL SUB_IN1, SUB_IN2, SUB_OUT : signed(48 downto 0);    -- inputs and output
SIGNAL MUX_SUB_IN1_DATA_IN : S_array(1 downto 0)(48 downto 0);   -- inputs of MUX_SUB_IN1
SIGNAL MUX_SUB_OUT_DATA_IN: S_array(1 downto 0)(48 downto 0);    -- inputs of MUX_SUB_OUT
SIGNAL MUX_SUB_IN2_DATA_IN : S_array(3 downto 0)(48 downto 0);   -- inputs of MUX_SUB_IN2

SIGNAL Q_SUB_DIN : signed(48 downto 0);    -- output of MUX_SUB_OUT = input of Q_SUB
SIGNAL Q_SUB : signed(48 downto 0);        -- subtractor register

-- Internal registers
SIGNAL INTERNAL_REG_EN: std_logic_vector(4 downto 0);   -- enables (see below)
SIGNAL Q_MUL_DIN:signed(47 downto 0);                   -- input of Q_MUL
-- index (1) = Q_SH1, index (0) = Q_SH2
SIGNAL SH_REG_DIN, SH_REG_DOUT: S_array(1 downto 0)(24 downto 0);
-- index (1) = Q_ADD, index (0) = Q_SUB
SIGNAL ADD_SUB_REG_DIN, ADD_SUB_REG_DOUT: S_array(1 downto 0)(48 downto 0);


-- Multiplexer before the final shift (MUX_ROUND)
SIGNAL MUX_ROUND_DATA_IN: S_array(1 downto 0)(48 downto 0);   -- inputs of MUX_ROUND
SIGNAL FINAL_SHIFT_IN: signed(48 downto 0);   -- value to shift and round

-- Final shift and rounding
SIGNAL MUX_FINAL_SHIFT_DATA_IN : S_array(1 downto 0)(48 downto 0);  -- (1): by 2, (0): by 1
SIGNAL SHIFT_mux_OUT: signed(48 downto 0);    -- output of the final shift
SIGNAL ROUND_OUT : signed(23 downto 0);       -- rounded result (Q1.23)

SIGNAL ROUND_OUT_SLV: std_logic_vector(23 downto 0);   -- ROUND_OUT as std_logic_vector


-- Output B'

SIGNAL MUX_OUT_B_DATA_IN: S_array(1 downto 0)(23 downto 0);   -- inputs of MUX_OUT_B

-- Components
Component   SUBTRACTOR IS
    PORT( A, B: IN  signed(48 downto 0);
          CLK:  IN  std_logic;
          O:    OUT signed(48 downto 0));
    END Component ;


Component MULTIPLIER IS
    PORT( A, B: IN  signed(23 downto 0);
          CLK,S_SH: IN  std_logic;
          M_OUT :   OUT signed(47 downto 0);
          SH_OUT:   OUT signed(24 downto 0));
    END Component ;


Component ADDER IS
    PORT( A, B: IN  signed(48 downto 0);
          CLK:  IN  std_logic;
          O:    OUT signed(48 downto 0));
    END Component ;


-- group of registers with one load enable each
Component REG_NxM is
    generic(
        N_Line : integer := 6;
        data_width: integer :=49);
    port(
        CLK: in std_logic;
        LOAD_EN: in std_logic_vector((N_Line-1) downto 0);
        DIN :  in   S_array(N_Line-1 downto 0)(data_width-1 downto 0) ;  -- data in
        DOUT : out  S_array(N_Line-1 downto 0)(data_width-1 downto 0));  -- data out
    end Component;

Component Reg IS -- single flip-flop with load enable
 PORT ( D :     IN      STD_LOGIC;
        CLK:    IN      STD_LOGIC;
        LD :    IN      STD_LOGIC;
        Q :     OUT     STD_LOGIC);
END Component ;


-- generic multiplexer: 2**N_Base inputs of data_width bits
Component MULTIPLEXER_N is
    generic(
        N_Base : integer := 1;       -- default: 2 inputs
        data_width: integer :=49);   -- default: 49 bits
    port(
        S: in std_logic_vector( N_Base-1 downto 0);
        data : in S_array((2**N_Base)-1 downto 0)(data_width-1 downto 0);
        DOUT : out signed( data_width-1 downto 0)); -- data out
    end Component;

Component ROM_ROUNDING_COMP is
    generic(
        L : integer := 5;
        D : integer := 2);
    port(
        CLK:    in std_logic;
        IN_L: in std_logic_vector(L-1 downto 0); -- bits to round
        IN_D: in std_logic_vector(D-1 downto 0); -- guard bits
        DOUT : out  std_logic_vector(L-1 DOWNTO 0)); -- rounded bits
    end Component;



-- START OF THE DATAPATH
BEGIN

-----------------------------------------------------------------------
    -- CONTROL SIGNALS FROM VETT_OUT
-----------------------------------------------------------------------
 SHN_MUL        <=VETT_OUT(18);         -- '1' = multiply, '0' = shift (2*A)
 SEL_A          <=VETT_OUT(17);         -- MUX_A:       0 = Ar,    1 = Ai
 SEL_OUT_B      <=VETT_OUT(16);         -- MUX_OUT_B:   0 = Q_ADD, 1 = Q_SUB
 SEL_ADD_OUT    <=VETT_OUT(15);         -- MUX_ADD_OUT: 0 = adder, 1 = rounded result
 SEL_ADD_IN2    <=VETT_OUT(14);         -- MUX_ADD_IN2: 0 = A,     1 = Q_ADD
 SEL_SUB_OUT    <=VETT_OUT(13);         -- MUX_SUB_OUT: 0 = subtr., 1 = rounded result
 SEL_SUB_IN1    <=VETT_OUT(12);         -- MUX_SUB_IN1: 0 = Q_SH2, 1 = Q_ADD
 SEL_X_IN2      <=VETT_OUT(11);         -- MUX_X_IN2:   0 = Wr,    1 = Wi
 SEL_SH_OUT     <=VETT_OUT(10);         -- MUX_SH_OUT:  0 = 2*A,   1 = rounded result
 SEL_ROUND      <=VETT_OUT(9);          -- MUX_ROUND:   0 = Q_SUB, 1 = Q_ADD
 SEL_X_IN1      <=VETT_OUT(8 downto 7); -- MUX_X_IN1: 00 = Ai, 01 = Ar, 10 = Bi, 11 = Br
 SEL_SUB_IN2    <=VETT_OUT(6 downto 5); -- MUX_SUB_IN2: 00 = Q_ADD, 01 = Q_MUL, 10 = Q_SUB
 FF_SH_EN2      <=VETT_OUT(4);          -- enable of Q_SH2
 FF_SH_EN1      <=VETT_OUT(3);          -- enable of Q_SH1
 FF_INR_EN      <=VETT_OUT(2);          -- enable of the input registers, real parts
 FF_INI_EN      <=VETT_OUT(1);          -- enable of the input registers, imag. parts

-----------------------------------------------------------------------


-----------------------------------------------------------------------
    -- INPUT REGISTERS FOR A, B, W
-----------------------------------------------------------------------
-- Real parts are loaded with FF_INR_EN, imaginary parts with FF_INI_EN (one cycle later)
INPUT_REG_EN(5)<= FF_INR_EN; INPUT_REG_DIN(5)<= x1_IN;  -- Ar
INPUT_REG_EN(4)<= FF_INI_EN; INPUT_REG_DIN(4)<= x1_IN;  -- Ai
Q_A_REAL <= INPUT_REG_DOUT(5); Q_A_IMAG <= INPUT_REG_DOUT(4);

INPUT_REG_EN(3)<= FF_INR_EN; INPUT_REG_DIN(3)<= x2_IN;  -- Br
INPUT_REG_EN(2)<= FF_INI_EN; INPUT_REG_DIN(2)<= x2_IN;  -- Bi
Q_B_REAL <=INPUT_REG_DOUT(3); Q_B_IMAG <=INPUT_REG_DOUT(2);


INPUT_REG_EN(1)<= FF_INR_EN; INPUT_REG_DIN(1)<= WR;     -- Wr
INPUT_REG_EN(0)<= FF_INI_EN; INPUT_REG_DIN(0)<= WI;     -- Wi
Q_W_REAL <= INPUT_REG_DOUT(1); Q_W_IMAG <=INPUT_REG_DOUT(0);

-- 6 registers of 24 bits (N_Line keeps its default value, 6)
INPUT_REGISTERS: REG_NxM
        generic map(data_width=>24)
        port map(LOAD_EN=> INPUT_REG_EN, DIN => INPUT_REG_DIN ,
                 DOUT=> INPUT_REG_DOUT, CLK=> CLK);

-- Two flip-flops in series for SF_2H_1L, both loaded with FF_INR_EN.
-- In continuous mode new inputs are loaded while the old data are still rounded:
-- so STAGE2 keeps the value of the old data for the final shift.
FF_SF_2H_1L_STAGE1 : Reg PORT MAP(  D => SF_2H_1L,          CLK=> CLK,
                                    LD => FF_INR_EN, Q => Q_SF_2H_1L_STAGE1);

FF_SF_2H_1L_STAGE2 : Reg PORT MAP(  D => Q_SF_2H_1L_STAGE1, CLK=> CLK,
                                    LD => FF_INR_EN, Q => Q_SF_2H_1L_STAGE2);


-----------------------------------------------------------------------
    -- MULTIPLIER / SHIFTER
-----------------------------------------------------------------------

-- Inputs of MUX_X_IN1 (select SEL_X_IN1)
MUX_X_IN1_DATA_IN(3)<=Q_B_REAL; -- 11
MUX_X_IN1_DATA_IN(2)<=Q_B_IMAG; -- 10

MUX_X_IN1_DATA_IN(1)<=Q_A_REAL; -- 01
MUX_X_IN1_DATA_IN(0)<=Q_A_IMAG; -- 00

-- 4 inputs of 24 bits: both N_Base and data_width are set
MUX_X_IN1 : MULTIPLEXER_N
    generic map(N_Base=>2, data_width=>24)
    port map(S=> SEL_X_IN1 , data=> MUX_X_IN1_DATA_IN ,DOUT => X_IN1);


-- Inputs of MUX_X_IN2 (select SEL_X_IN2)
MUX_X_IN2_DATA_IN(1)<=Q_W_IMAG; -- 1
MUX_X_IN2_DATA_IN(0)<=Q_W_REAL; -- 0

-- 2 inputs of 24 bits: only data_width is set
MUX_X_IN2 : MULTIPLEXER_N
    generic map(data_width=>24)
    port map(S(0)=> SEL_X_IN2 , data=> MUX_X_IN2_DATA_IN ,DOUT => X_IN2);

-- Multiplier: MUL_OUT = X_IN1 * X_IN2 (SHN_MUL = '1'), SH_OUT = 2 * X_IN1 (SHN_MUL = '0')
MUL_SHIFT_UNIT : MULTIPLIER port map( A=> X_IN1, B=> X_IN2, CLK=> CLK, S_SH=>SHN_MUL ,
                                      M_OUT=> MUL_OUT, SH_OUT=> SH_OUT);



-- Inputs of MUX_SH_OUT (select SEL_SH_OUT).
-- 1: rounded result with a '0' added at the end, to fill the 25 bits of Q_SH1
 MUX_SH_OUT_DATA_IN(1)<= signed(std_logic_vector(ROUND_OUT) & "0"); -- 1
 MUX_SH_OUT_DATA_IN(0)<=SH_OUT; -- 0: 2*A from the shifter

-- 2 inputs of 25 bits
MUX_SH_OUT : MULTIPLEXER_N
        generic map (data_width=>25)
        port map(S(0)=> SEL_SH_OUT , data=> MUX_SH_OUT_DATA_IN, DOUT => Q_SH1_DIN);






-----------------------------------------------------------------------
    -- ADDER
-----------------------------------------------------------------------

-- Inputs of MUX_A (select SEL_A)
MUX_A_DATA_IN(1)<=Q_A_IMAG; -- 1
MUX_A_DATA_IN(0)<=Q_A_REAL; -- 0

-- 2 inputs of 24 bits. A goes in bits 46..23 of A_SELECTED_49BIT
MUX_A: MULTIPLEXER_N
    generic map (data_width=>24)
    port map(S(0)=> SEL_A , data=> MUX_A_DATA_IN ,DOUT => A_SELECTED_49BIT(46 downto 23));

    -- From Q1.23 to Q3.46: two copies of the sign bit on the left, 23 zeros on the right
    A_SELECTED_49BIT(48 downto 47) <= (A_SELECTED_49BIT(46) & A_SELECTED_49BIT(46));
    A_SELECTED_49BIT(22 downto 0) <= (others=>'0');

-- Inputs of MUX_ADD_IN2 (select SEL_ADD_IN2)
    MUX_ADD_IN2_DATA_IN(1)<=Q_ADD; -- 1

    MUX_ADD_IN2_DATA_IN(0)<=A_SELECTED_49BIT; -- 0


-- 2 inputs of 49 bits: the default generics are used
MUX_ADD_IN2 : MULTIPLEXER_N port map(S(0)=> SEL_ADD_IN2 , data=> MUX_ADD_IN2_DATA_IN,
                                     DOUT => ADD_IN2);

-- Adder input 1 is always Q_MUL, with sign extension from 48 to 49 bits
ADD_IN1<= signed(Q_MUL(47) & std_logic_vector(Q_MUL));


-- Adder: ADD_OUT = ADD_IN1 + ADD_IN2, one clock cycle later
ADDER_UNIT: ADDER port map( A=> ADD_IN1, B=> ADD_IN2, CLK=> CLK, O=> ADD_OUT);


-- Inputs of MUX_ADD_OUT (select SEL_ADD_OUT).
-- 1: rounded result in bits 48..25, where MUX_OUT_B reads it
 MUX_ADD_OUT_DATA_IN(1)<= signed(std_logic_vector(ROUND_OUT)
                                 & std_logic_vector'(24 downto 0 => '0')); -- 1
 MUX_ADD_OUT_DATA_IN(0)<=ADD_OUT; -- 0

-- 2 inputs of 49 bits: the default generics are used
MUX_ADD_OUT : MULTIPLEXER_N port map(S(0)=> SEL_ADD_OUT , data=> MUX_ADD_OUT_DATA_IN,
                                     DOUT => Q_ADD_DIN);




-----------------------------------------------------------------------
    -- SUBTRACTOR
-----------------------------------------------------------------------

-- Inputs of MUX_SUB_IN1 (select SEL_SUB_IN1)

    MUX_SUB_IN1_DATA_IN(1)<=Q_ADD; -- 1
    -- 0: Q_SH2 (2*A, Q2.23) to Q3.46: extra sign bit on the left, 23 zeros on the right
    MUX_SUB_IN1_DATA_IN(0)<= signed(std_logic(Q_SH2(24)) & std_logic_vector(Q_SH2)
                                    & std_logic_vector'(22 downto 0 => '0')); -- 0

-- 2 inputs of 49 bits: the default generics are used
MUX_SUB_IN1 : MULTIPLEXER_N port map(S(0)=> SEL_SUB_IN1 , data=> MUX_SUB_IN1_DATA_IN,
                                     DOUT => SUB_IN1);


-- Inputs of MUX_SUB_IN2 (select SEL_SUB_IN2). Input 3 (code 11) is not used.
MUX_SUB_IN2_DATA_IN(2)<=Q_SUB; -- 10

-- 01: Q_MUL with sign extension from 48 to 49 bits
MUX_SUB_IN2_DATA_IN(1)<=signed(Q_MUL(47) & std_logic_vector(Q_MUL)); -- 01
MUX_SUB_IN2_DATA_IN(0)<=Q_ADD; -- 00

-- 4 inputs of 49 bits: only N_Base is set
MUX_SUB_IN2 : MULTIPLEXER_N
    generic map(N_Base=>2)
    port map(S=> SEL_SUB_IN2 , data=> MUX_SUB_IN2_DATA_IN, DOUT => SUB_IN2);

-- Subtractor: SUB_OUT = SUB_IN1 - SUB_IN2, one clock cycle later
SUBTRACTOR_UNIT : SUBTRACTOR port map( A=> SUB_IN1, B=> SUB_IN2, CLK=> CLK, O=> SUB_OUT);

-- Inputs of MUX_SUB_OUT (select SEL_SUB_OUT).
-- 1: rounded result in bits 48..25, where MUX_OUT_B reads it
 MUX_SUB_OUT_DATA_IN(1)<= signed(std_logic_vector(ROUND_OUT)
                                 & std_logic_vector'(24 downto 0 => '0')); -- 1
 MUX_SUB_OUT_DATA_IN(0)<=SUB_OUT; -- 0

-- 2 inputs of 49 bits: the default generics are used
MUX_SUB_OUT : MULTIPLEXER_N port map(S(0)=> SEL_SUB_OUT , data=> MUX_SUB_OUT_DATA_IN,
                                     DOUT => Q_SUB_DIN);




-----------------------------------------------------------------------
    -- INTERNAL REGISTERS
-----------------------------------------------------------------------
-- Bits of INTERNAL_REG_EN:
--   4: Q_MUL, always enabled
--   3: Q_SH1, enabled by FF_SH_EN1
--   2: Q_SH2, enabled by FF_SH_EN2
--   1: Q_ADD, always enabled
--   0: Q_SUB, always enabled


-- Q_MUL: one register of 48 bits after the multiplier
INTERNAL_REG_EN(4)<= '1';           Q_MUL_DIN<= MUL_OUT;
REG_Q_MUL: REG_NxM
        generic map(N_Line => 1, data_width=> 48)
        port map(LOAD_EN(0)=> INTERNAL_REG_EN(4), DIN(0)=> Q_MUL_DIN ,
                 DOUT(0)=> Q_MUL, CLK=> CLK);

-- Q_SH1 and Q_SH2: two registers of 25 bits in series, after MUX_SH_OUT
INTERNAL_REG_EN(3)<= FF_SH_EN1;     SH_REG_DIN(1)<= Q_SH1_DIN;
Q_SH1 <= SH_REG_DOUT(1);

INTERNAL_REG_EN(2)<= FF_SH_EN2;     SH_REG_DIN(0)<= Q_SH1;
Q_SH2 <= SH_REG_DOUT(0);

REG_Q_SH1_Q_SH2: REG_NxM
        generic map(N_Line => 2, data_width=> 25)
        port map(LOAD_EN=> INTERNAL_REG_EN(3 downto 2), DIN => SH_REG_DIN ,
                 DOUT=> SH_REG_DOUT, CLK=> CLK);

-- Q_ADD and Q_SUB: two registers of 49 bits, after MUX_ADD_OUT and MUX_SUB_OUT
INTERNAL_REG_EN(1)<= '1';           ADD_SUB_REG_DIN(1)<= Q_ADD_DIN;
Q_ADD <= ADD_SUB_REG_DOUT(1);

INTERNAL_REG_EN(0)<= '1';           ADD_SUB_REG_DIN(0)<= Q_SUB_DIN;
Q_SUB <= ADD_SUB_REG_DOUT(0);


-- data_width keeps its default value, 49
REG_Q_ADD_Q_SUB: REG_NxM
        generic map(N_Line => 2)
        port map(LOAD_EN=> INTERNAL_REG_EN(1 downto 0), DIN => ADD_SUB_REG_DIN ,
                 DOUT=> ADD_SUB_REG_DOUT, CLK=> CLK);



-----------------------------------------------------------------------
    -- FINAL SHIFT
-----------------------------------------------------------------------

-- Inputs of MUX_ROUND (select SEL_ROUND): the value to shift and round

    MUX_ROUND_DATA_IN(1)<=Q_ADD; -- 1
    MUX_ROUND_DATA_IN(0)<=Q_SUB; -- 0

-- 2 inputs of 49 bits: the default generics are used
MUX_ROUND : MULTIPLEXER_N port map(S(0)=> SEL_ROUND , data=> MUX_ROUND_DATA_IN,
                                   DOUT => FINAL_SHIFT_IN);

-- The final shift is a multiplexer: arithmetic shift right by 2 or by 1 position
-- (the sign bit is copied on the left)
        -- 1: shift by 2
        MUX_FINAL_SHIFT_DATA_IN(1)<= FINAL_SHIFT_IN(48) & FINAL_SHIFT_IN(48)
                                     & FINAL_SHIFT_IN(48 downto 2) ;
        -- 0: shift by 1
        MUX_FINAL_SHIFT_DATA_IN(0)<= FINAL_SHIFT_IN(48) & FINAL_SHIFT_IN(48 downto 1);


-- Select: SF_2H_1L of the data that are rounded now ('1' = by 2, '0' = by 1)
MUX_FINAL_SHIFT : MULTIPLEXER_N port map(S(0)=> Q_SF_2H_1L_STAGE2,
                                         data=> MUX_FINAL_SHIFT_DATA_IN,
                                         DOUT =>SHIFT_mux_OUT);




-----------------------------------------------------------------------
    -- ROUNDING
-----------------------------------------------------------------------
-- From Q3.46 to Q1.23: the result is SHIFT_mux_OUT(46 downto 23), rounded.
-- Bits 46..28 go to the output as they are (the ROM never gives a carry).
ROUND_OUT_SLV(23 downto 5) <= std_logic_vector(SHIFT_mux_OUT(46 downto 28)) ;

-- The ROM rounds the 5 bits 27..23 with the 2 guard bits 22..21
ROM_ROUNDING  : ROM_ROUNDING_COMP port map(CLK=> CLK,
                    IN_L=> std_logic_vector(SHIFT_mux_OUT(27 downto 23)),
                    IN_D=> std_logic_vector(SHIFT_mux_OUT(22 downto 21)),
                    DOUT=> ROUND_OUT_SLV(4 downto 0));

ROUND_OUT<=signed(ROUND_OUT_SLV);




-----------------------------------------------------------------------
    -- OUTPUTS
-----------------------------------------------------------------------
-- A' (X1_OUT): Q_SH2 without the '0' added by MUX_SH_OUT
X1_OUT<=signed(std_logic_vector(Q_SH2(24 downto 1)));

-- B' (X2_OUT): rounded result in bits 48..25 of Q_SUB or Q_ADD (select SEL_OUT_B)

MUX_OUT_B_DATA_IN(1)<=signed(std_logic_vector(Q_SUB(48 downto 25))); -- 1
MUX_OUT_B_DATA_IN(0)<=signed(std_logic_vector(Q_ADD(48 downto 25))); -- 0

-- 2 inputs of 24 bits
MUX_OUT_B : MULTIPLEXER_N
        generic map (data_width=>24)
        port map(S(0)=> SEL_OUT_B , data=> MUX_OUT_B_DATA_IN, DOUT => X2_OUT);



END Behavior;

-- =============================================================================
-- CU_uROM.vhd
-- Microprogrammed Control Unit (CU) of the butterfly, with Late Status.
--  - uAR (3 bits, falling edge): code of the next state.
--  - uROM: EVEN and ODD banks, both read at row uAR(2 DOWNTO 1).
--  - uIR (23 bits, rising edge): microinstruction of the present state.
--  - Late Status PLA (LSPLA): gives the LSB of the next state, so it chooses
--    the EVEN or the ODD word.
-- The output VETT_OUT has the datapath controls and DONE.
-- =============================================================================
LIBRARY ieee ;
USE ieee.std_logic_1164.all ;
USE ieee.numeric_std.all ;
USE work.my_types_pkg.all;

ENTITY CU_uROM IS
    PORT(   -- RESET_ASINC and RESET_SINC are active low
            CLK, START, RESET_ASINC, RESET_SINC:    IN  STD_LOGIC;
            VETT_OUT : OUT STD_LOGIC_VECTOR(18 DOWNTO 0));   -- controls + DONE
    END CU_uROM ;

ARCHITECTURE Behavior OF CU_uROM IS

-----------------------------------------------------------------------
-----------------------------------------------------------------------
    -- SIGNALS
-----------------------------------------------------------------------
-----------------------------------------------------------------------

-- Datapath controls (explained in BUTTERFLY_DATAPATH.vhd)
SIGNAL SEL_X_IN1, SEL_SUB_IN2 : STD_LOGIC_VECTOR(1 DOWNTO 0);
SIGNAL SEL_A, SEL_X_IN2, SEL_SH_OUT, SEL_SUB_IN1, SEL_ADD_IN2 : STD_LOGIC;
SIGNAL SEL_ADD_OUT, SEL_SUB_OUT, SEL_ROUND, SEL_OUT_B: STD_LOGIC;
SIGNAL FF_INR_EN, FF_INI_EN, FF_SH_EN1, FF_SH_EN2: STD_LOGIC;
-- SHN_MUL, DONE and the signals for the status flags Y and PREV_START
SIGNAL SHN_MUL, EN_DONE, DONE, START_INT, PREV_START, Y, SET_Y, RESET_Y,
       FF_PREV_START_EN: STD_LOGIC;


-- Next_Addr: row of the next word; CC: Condition Code for the LSPLA
SIGNAL Next_Addr, CC: STD_LOGIC_VECTOR(1 DOWNTO 0);
SIGNAL D_uAR, Q_uAR: STD_LOGIC_VECTOR(2 DOWNTO 0);      -- uAR input and output
-- uIR input and output, and the two words read from the uROM
SIGNAL D_uIR, Q_uIR,  DOUT_EVEN, DOUT_ODD: STD_LOGIC_VECTOR(22 DOWNTO 0);
-- SEL_MUX_DOUT: '0' = EVEN word, '1' = ODD word.
-- SEL_MUX_LSPLA_OUT: select of the mux that makes SEL_MUX_DOUT.
SIGNAL SEL_MUX_DOUT, SEL_MUX_LSPLA_OUT: STD_LOGIC;
-- LSB: from the uIR; OUT_LSPLA: from the LSPLA
SIGNAL LSB, OUT_LSPLA: STD_LOGIC;





-----------------------------------------------------------------------
-----------------------------------------------------------------------
    -- COMPONENTS
-----------------------------------------------------------------------
-----------------------------------------------------------------------

-- COMPONENT uROM (two banks, EVEN and ODD)

COMPONENT uROM
        GENERIC (
            ADDR_NUM_BIT : integer := 2;
            DATA_NUM_BIT : integer := 23
        );
        PORT (
            A        : IN  std_logic_vector(ADDR_NUM_BIT - 1 DOWNTO 0);
            OUT_EVEN, OUT_ODD : OUT std_logic_vector(DATA_NUM_BIT - 1 DOWNTO 0)
        );
    END COMPONENT;

-- COMPONENT multiplexer for std_logic_vector

COMPONENT MULTIPLEXER_N_SLV is
    generic(
        N_Base : integer := 1;
        data_width: integer :=23);
    port(
        S: in std_logic_vector( N_Base-1 downto 0);
        data : in std_logic_vector (((data_width*(2**N_base))-1)downto 0);
        DOUT : out std_logic_vector(data_width-1 downto 0));
    end COMPONENT;

-- COMPONENT Reg_N_Rising (used as uIR)

COMPONENT Reg_N_Rising
    GENERIC ( N_BIT : integer := 23);
    PORT (
        D   : IN  STD_LOGIC_VECTOR(N_BIT-1 downto 0);
        CLK : IN  STD_LOGIC;
        LD, RES_NOSYNC, RES_SYNC : IN  STD_LOGIC;
        Q   : OUT STD_LOGIC_VECTOR(N_BIT-1 downto 0)
    );
END COMPONENT;

-- COMPONENT Reg_N_Falling (used as uAR)

COMPONENT Reg_N_Falling
    GENERIC ( N_BIT : integer := 3);
    PORT (
        D   : IN  STD_LOGIC_VECTOR(N_BIT-1 downto 0);
        CLK : IN  STD_LOGIC;
        LD, RES_NOSYNC: IN  STD_LOGIC;
        Q   : OUT STD_LOGIC_VECTOR(N_BIT-1 downto 0)
    );
END COMPONENT;

-- COMPONENT LSPLA (Late Status PLA)

COMPONENT LSPLA
    PORT(   LSB, Y, START, PREV_START:  IN      STD_LOGIC;
            CC:     IN      STD_LOGIC_VECTOR(1 DOWNTO 0);
            OUT_LSB:    OUT     STD_LOGIC);
END COMPONENT;



-----------------------------------------------------------------------
-----------------------------------------------------------------------

BEGIN




-----------------------------------------------------------------------
    -- LOGIC GATES
-----------------------------------------------------------------------

-- DONE is high only if the uIR enables it (STATE 5) and the results are valid (Y = '1')
DONE <= EN_DONE AND Y;
-- Y is set in STATE 5: it is the only state with SEL_A = '1'
SET_Y <= SEL_A;
-- Y is reset: 1) in IDLE (the only state with FF_INR_EN = '1' and FF_SH_EN1 = '0');
--             2) on a new START (START = '1', PREV_START = '0') while FF_INR_EN = '1'
RESET_Y <= (FF_INR_EN AND (NOT(FF_SH_EN1)))OR(FF_INR_EN AND START AND (NOT(PREV_START)));
-- PREV_START is saved only in STATE 1 (the only state with SEL_ADD_IN2 = SHN_MUL = '1')
FF_PREV_START_EN <= SEL_ADD_IN2 AND SHN_MUL;



-----------------------------------------------------------------------
    -- PROCESSES FOR Y, START_INT, PREV_START, FF_INI_EN AND SEL_MUX_LSPLA_OUT
-----------------------------------------------------------------------
-- SEL_MUX_LSPLA_OUT is a copy of CLK
PROCESS(CLK)
    BEGIN
        SEL_MUX_LSPLA_OUT <= CLK;
END PROCESS;


PROCESS(SET_Y, RESET_Y, CLK, FF_PREV_START_EN)
    BEGIN
        IF(RISING_EDGE(CLK)) THEN

            -- FF_INI_EN is FF_INR_EN one clock cycle later: the imaginary parts
            -- are loaded one cycle after the real parts
            FF_INI_EN <= FF_INR_EN;
            -- START_INT is START one clock cycle later
            START_INT <= START;
            -- PREV_START: value of START when the FSM went into STATE 1.
            -- In STATE 6, PREV_START = '1' means: this run loaded new data.
            IF(FF_PREV_START_EN = '1') THEN
                PREV_START <= START_INT;
            END IF;
            -- Y = '1': the data of the previous run are ready to go out (see STATE 4).
            -- Set/reset flip-flop: reset wins, because it is written last.
            IF(SET_Y = '1') THEN
                Y <= '1';
            END IF;
            IF(RESET_Y = '1') THEN
                Y <= '0';
            END IF;
        END IF;
    END PROCESS;

-----------------------------------------------------------------------
    -- uAR AND uIR
-----------------------------------------------------------------------
    -- uAR: 3-bit register on the falling edge, always loaded, never reset
    u_AR: Reg_N_Falling PORT MAP(
        CLK         => CLK,
        LD          => '1',
        RES_NOSYNC  => '1',
        D           => D_uAR,
        Q           => Q_uAR

    );
    -- bits 2-1 of the next state code: Next_Addr from the uIR
    D_uAR(2) <= Next_Addr(1);
    D_uAR(1) <= Next_Addr(0);

    -- uIR: 23-bit register on the rising edge, always loaded.
    -- Both resets load the IDLE microinstruction.
    u_IR: Reg_N_Rising PORT MAP(
        CLK         => CLK,
        LD          => '1',
        RES_NOSYNC  => RESET_ASINC,
        RES_SYNC    => RESET_SINC,
        D           => D_uIR,
        Q           => Q_uIR
    );


-----------------------------------------------------------------------
    -- uROM
-----------------------------------------------------------------------
    -- Both banks are read at the row given by uAR(2 DOWNTO 1)
    u_ROM: uROM PORT MAP (
        A        => Q_uAR(2 DOWNTO 1),
        OUT_EVEN => DOUT_EVEN,
        OUT_ODD  => DOUT_ODD
    );


-----------------------------------------------------------------------
    -- MULTIPLEXERS
-----------------------------------------------------------------------
    -- Mux that sends the ODD word (S = '1') or the EVEN word (S = '0') to the uIR
    MUX_DOUT: MULTIPLEXER_N_SLV PORT MAP (
        S(0)    => SEL_MUX_DOUT,
        data    => DOUT_ODD & DOUT_EVEN , -- ODD word: high bits, EVEN word: low bits
        dout    => D_uIR
    );

    -- Second mux: it makes SEL_MUX_DOUT, the select of the mux above.
    --   CLK = '1' (rising edge -> falling edge): Q_uAR(0), the LSB saved in the uAR;
    --   CLK = '0' (falling edge -> rising edge): OUT_LSPLA, straight from the LSPLA.
    -- So, on the rising edge, the uIR gets the word chosen with the latest status.
    SEL_MUX_DOUT <=  (Q_uAR(0) AND (SEL_MUX_LSPLA_OUT))
                     OR (OUT_LSPLA AND (NOT(SEL_MUX_LSPLA_OUT)));


-----------------------------------------------------------------------
    -- LATE STATUS PLA
-----------------------------------------------------------------------
    Late_Status_PLA: LSPLA PORT MAP(
    CC              => CC,
    LSB             => LSB,
    Y               => Y,
    START           => START,
    PREV_START      => PREV_START,
    OUT_LSB         => OUT_LSPLA
    );

    -- The LSPLA output is also bit 0 of the next state code, saved in the uAR
    D_uAR(0) <= OUT_LSPLA;




-----------------------------------------------------------------------
-----------------------------------------------------------------------
    -- FIELDS OF THE MICROINSTRUCTION (Q_uIR, 23 bits)
-----------------------------------------------------------------------
-----------------------------------------------------------------------
    -- bits 22-21: CC, Condition Code for the LSPLA
    CC(1)           <= Q_uIR(23-1);
    CC(0)           <= Q_uIR(22-1);
    -- bits 20-19: Next_Addr, row of the next word in the uROM
    Next_Addr(1)    <= Q_uIR(21-1);
    Next_Addr(0)    <= Q_uIR(20-1);
    -- bit 18: LSB of the next state code when there is no jump (CC = 00)
    LSB             <= Q_uIR(19-1);
    -- bits 17-1: datapath controls (FF_INI_EN is not here: it is made from FF_INR_EN)
    SHN_MUL         <= Q_uIR(18-1);
    SEL_A           <= Q_uIR(17-1);
    SEL_OUT_B       <= Q_uIR(16-1);
    SEL_ADD_OUT     <= Q_uIR(15-1);
    SEL_ADD_IN2     <= Q_uIR(14-1);
    SEL_SUB_OUT     <= Q_uIR(13-1);
    SEL_SUB_IN1     <= Q_uIR(12-1);
    SEL_X_IN2       <= Q_uIR(11-1);
    SEL_SH_OUT      <= Q_uIR(10-1);
    SEL_ROUND       <= Q_uIR(9-1);
    SEL_X_IN1(1)    <= Q_uIR(8-1);
    SEL_X_IN1(0)    <= Q_uIR(7-1);
    SEL_SUB_IN2(1)  <= Q_uIR(6-1);
    SEL_SUB_IN2(0)  <= Q_uIR(5-1);
    FF_SH_EN2       <= Q_uIR(4-1);
    FF_SH_EN1       <= Q_uIR(3-1);
    FF_INR_EN       <= Q_uIR(2-1);
    -- bit 0: enable of DONE
    EN_DONE         <= Q_uIR(1-1);







-----------------------------------------------------------------------
    -- OUTPUT VECTOR VETT_OUT
-----------------------------------------------------------------------
   -- Bit order of VETT_OUT (19 bits):
   -- [18]    SHN_MUL
   -- [17]    SEL_A
   -- [16]    SEL_OUT_B
   -- [15]    SEL_ADD_OUT
   -- [14]    SEL_ADD_IN2
   -- [13]    SEL_SUB_OUT
   -- [12]    SEL_SUB_IN1
   -- [11]    SEL_X_IN2
   -- [10]    SEL_SH_OUT
   -- [9]     SEL_ROUND
   -- [8-7]   SEL_X_IN1 (2 bits)
   -- [6-5]   SEL_SUB_IN2 (2 bits)
   -- [4]     FF_SH_EN2
   -- [3]     FF_SH_EN1
   -- [2]     FF_INR_EN
   -- [1]     FF_INI_EN
   -- [0]     DONE (it goes out of the butterfly, not to the datapath)
-----------------------------------------------------------------------

   VETT_OUT <= SHN_MUL &
                SEL_A &
                SEL_OUT_B &
                SEL_ADD_OUT &
                SEL_ADD_IN2 &
                SEL_SUB_OUT &
                SEL_SUB_IN1 &
                SEL_X_IN2 &
                SEL_SH_OUT &
                SEL_ROUND &
                SEL_X_IN1 &     -- 2 bits
                SEL_SUB_IN2 &   -- 2 bits
                FF_SH_EN2 &
                FF_SH_EN1 &
                FF_INR_EN &
                FF_INI_EN &
                DONE;




END Behavior;

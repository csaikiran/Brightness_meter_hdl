library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity BRIGHTNESS_METER is
  port (
    -- AXI stream signals.
    S_AXI_CLK      : in  std_logic;                     -- AXI clock
    S_AXI_CEN      : in  std_logic;                     -- AXI clock enable
    S_AXI_RESETN   : in  std_logic;                     -- AXI reset, activ low
    S_AXI_TDATA    : in std_logic_vector(23 downto 0); -- DATA
    S_AXI_TVALID   : in std_logic;                     -- VALID
    S_AXI_TREADY   : in  std_logic;                     -- READY
    S_AXI_USER     : in std_logic;                     -- Start Of Frame
    S_AXI_TLAST    : in std_logic;                     -- End Of Line
    -- Autoreg
    H_SIZE         : in  std_logic_vector(11 downto 0);
    V_SIZE         : in  std_logic_vector(11 downto 0);
    REF_VALUE      : in  std_logic_vector(11 downto 0); -- End Of Line
    RAM_ADDR       : in  std_logic_vector(10 downto 0);
    RAM_DATAWe     : in  std_logic;
    RAM_DATACe     : in  std_logic;
    RAM_DATA_I     : in  std_logic_vector(7 downto 0);
    RAM_DATA_O     : out std_logic_vector(7 downto 0);
    DIVIDE         : in  std_logic_vector(3 downto 0);
   
    AVERAGE        : out std_logic_vector(31 downto 0);
    NEW_VALUE      : out std_logic;
    SIZE_FAULT     : out std_logic
  );
end entity;

architecture RTL of BRIGHTNESS_METER is

component FRAME_COUNTER 
  port (
  S_AXI_CLK      : in  std_logic;                     -- AXI clock
  S_AXI_CEN      : in  std_logic;                     -- AXI clock enable
  S_AXI_RESETN   : in  std_logic;                     -- AXI reset, activ low
  S_AXI_TDATA    : in std_logic_vector(23 downto 0); -- DATA
  S_AXI_TVALID   : in std_logic;                     -- VALID
  S_AXI_TREADY   : in  std_logic;                     -- READY
  S_AXI_USER     : in std_logic;                     -- Start Of Frame
  S_AXI_TLAST    : in std_logic;                     -- End Of Line
  -- Autoreg
  H_SIZE         : in  std_logic_vector(11 downto 0);
  V_SIZE         : in  std_logic_vector(11 downto 0);
  REF_VALUE      : in  std_logic_vector(11 downto 0);
  RAM_ADDR       : in  std_logic_vector(10 downto 0);
  RAM_DATAWe     : in  std_logic;
  RAM_DATACe     : in  std_logic;
  RAM_DATA_I     : in  std_logic_vector(7 downto 0);
  RAM_DATA_O     : out std_logic_vector(7 downto 0);
 
  SIZE_FAULT     : out std_logic;
  CE             : in  std_logic;
  DATA_OUT_B     : out std_logic_vector(7 downto 0);
  EOF            : out std_logic
  );
end component;


  type t_FSM is (IDLE, SHIFT, NEW_IMAGE);
  
  signal fsm_state                                                                                      : t_FSM := IDLE;
  signal shift_cnt                                                                                      : unsigned(3 downto 0):= (others => '0');
  signal CE                                                                                             : std_logic; -- AND of S_AXI_CEN, S_AXI_TVALID and S_AXI_TREADY
  signal CE_FRAME_COUNTER                                                                               : std_logic; -- AND of S_AXI_CEN, S_AXI_TVALID and S_AXI_TREADY for FRAME_COUNTER
  signal WEIGHTS                                                                                        : std_logic_vector(7 downto 0):= (others => '0'); --BRAM PORT A OUTPUT
  signal EOF                                                                                            : std_logic; -- End of Frame
  signal S_AXI_CEN_nT, S_AXI_TVALID_nT, S_AXI_TREADY_nT, S_AXI_USER_nT, S_AXI_TLAST_nT                  : std_logic_vector(5 downto 0);  --Delayed AXI signals
  signal S_AXI_TDATA_1T, S_AXI_TDATA_2T, S_AXI_TDATA_3T, S_AXI_TDATA_4T, S_AXI_TDATA_5T, S_AXI_TDATA_6T : std_logic_vector(23 downto 0); --Delayed input data 
  signal SUBTRACT_RESULT_0                                                                              : signed(12 downto 0):= (others => '0'); -- result after subtraction for pixel #0
  signal SUBTRACT_RESULT_1                                                                              : signed(12 downto 0):= (others => '0'); -- result after subtraction for pixel #1
  signal ADDER_RESULT                                                                                   : signed(13 downto 0):= (others => '0'); -- result after addition for pixel #0 and pixel #1
  signal MULTIPLIER_RESULT                                                                              : signed(21 downto 0):= (others => '0'); -- result after Multiplication
  signal ACCUMULATOR_TEMP                                                                               : signed(44 downto 0):= (others => '0');  -- Temporary storage for Accumulatorn
  signal ACCUMULATOR_RESULT                                                                             : signed(44 downto 0):= (others => '0');  -- result after Accumulator
  signal CE_1T, CE_2T, CE_3T                                                                            : std_logic;    --Delayed CE signals
  signal EOF_1T, EOF_2T, EOF_3T, EOF_4T, EOF_5T, EOF_6T, EOF_7T, EOF_8T                                 : std_logic;    --Delayed EOF signals
  signal AVERAGE_TEMP                                                                                   : std_logic_vector(44 downto 0):= (others => '0');
  
  
begin

  -- Make clock enable to simplify code afterwards
  CE  <= S_AXI_CEN_nT(2) and S_AXI_TVALID_nT(2) and S_AXI_TREADY_nT(2);
  CE_FRAME_COUNTER  <= S_AXI_CEN and S_AXI_TVALID and S_AXI_TREADY;
  
  pAXI_LATENCY: process(S_AXI_CLK) begin
        if rising_edge(S_AXI_CLK) then
            S_AXI_CEN_nT(0)     <= S_AXI_CEN;
            S_AXI_TVALID_nT(0)  <= S_AXI_TVALID;
            S_AXI_TREADY_nT(0)  <= S_AXI_TREADY;
            S_AXI_USER_nT(0)    <= S_AXI_USER;
            S_AXI_TLAST_nT(0)   <= S_AXI_TLAST;
            S_AXI_TDATA_1T      <= S_AXI_TDATA;
            S_AXI_TDATA_2T      <= S_AXI_TDATA_1T;
            S_AXI_TDATA_3T      <= S_AXI_TDATA_2T;
            S_AXI_TDATA_4T      <= S_AXI_TDATA_3T;
            S_AXI_TDATA_5T      <= S_AXI_TDATA_4T;
            S_AXI_TDATA_6T      <= S_AXI_TDATA_5T;
         for i in 1 to 5 loop
            S_AXI_CEN_nT(i)     <= S_AXI_CEN_nT(i - 1);
            S_AXI_TVALID_nT(i)  <= S_AXI_TVALID_nT(i - 1);
            S_AXI_TREADY_nT(i)  <= S_AXI_TREADY_nT(i - 1);
            S_AXI_USER_nT(i)    <= S_AXI_USER_nT(i - 1);
            S_AXI_TLAST_nT(i)   <= S_AXI_TLAST_nT(i - 1);
         end loop;
        end if;    
   end process;
  
  pCE_LATENCY: process(S_AXI_CLK)
  begin
        if rising_edge(S_AXI_CLK) then
            CE_1T <= CE;
            CE_2T <= CE_1T;
            CE_3T <= CE_2T;
        end if;
   end process;
   
  pEOF_LATENCY: process(S_AXI_CLK)
   begin
         if rising_edge(S_AXI_CLK) then
             EOF_1T <= EOF;
             EOF_2T <= EOF_1T;
             EOF_3T <= EOF_2T;
             EOF_4T <= EOF_3T;
             EOF_5T <= EOF_4T;
             EOF_6T <= EOF_5T;
             EOF_7T <= EOF_6T;
             EOF_8T <= EOF_7T;
         end if;
    end process;

  pSUBTRACT: process(S_AXI_CLK)
  begin
--    if S_AXI_RESETN = '0' then
--        ACCUMULATOR_TEMP <= (others => '0');
--        ACCUMULATOR_RESULT <= (others => '0');
--        SUBTRACT_RESULT_0 <= (others => '0');
--        SUBTRACT_RESULT_1 <= (others => '0');
--        ADDER_RESULT <= (others => '0');
--        MULTIPLIER_RESULT <= (others => '0');
--    els
    if rising_edge(S_AXI_CLK) then
        if (EOF_7T = '1') then
            ACCUMULATOR_TEMP <= (others => '0');
            ACCUMULATOR_RESULT <= ACCUMULATOR_TEMP;  
        elsif CE = '1' then
            SUBTRACT_RESULT_0 <= signed('0' & S_AXI_TDATA_3T(11 downto 0)) - signed('0' & REF_VALUE);
            SUBTRACT_RESULT_1 <= signed('0' & S_AXI_TDATA_3T(23 downto 12)) - signed('0' & REF_VALUE);
        end if;
        if CE_1T = '1' then
            ADDER_RESULT <= (SUBTRACT_RESULT_0(12) & SUBTRACT_RESULT_0) + SUBTRACT_RESULT_1;
        end if;
        if CE_2T = '1' then
            MULTIPLIER_RESULT <= signed(ADDER_RESULT) * signed(WEIGHTS);
        end if;
        if CE_3T = '1' then
            ACCUMULATOR_TEMP <= ACCUMULATOR_TEMP + MULTIPLIER_RESULT;
        end if;
     end if;
  end process ;
  
  pSHIFT_REGISTER: process(S_AXI_CLK)
  begin
   if rising_edge(S_AXI_CLK) then
     if EOF = '1' then
        fsm_state <= IDLE;
--        shift_cnt <= (others => '0');
--        AVERAGE_TEMP <= (others => '0');
--        AVERAGE <= (others => '0');
--        NEW_VALUE <= '0';
     else
        case fsm_state is
            when IDLE =>
                NEW_VALUE <= '0';
                if EOF_8T = '1' then
                    AVERAGE_TEMP <= std_logic_vector(ACCUMULATOR_RESULT);
                    shift_cnt <= unsigned(DIVIDE);
                    fsm_state <= SHIFT;
                end if;
            when SHIFT => 
                if shift_cnt = 0 then
                    fsm_state <= NEW_IMAGE;
                else
                    shift_cnt <= shift_cnt - 1;
                    AVERAGE_TEMP <= AVERAGE_TEMP(44) & AVERAGE_TEMP(44 downto 1);
                end if;
            when NEW_IMAGE =>
                AVERAGE <= AVERAGE_TEMP(31 downto 0);
                NEW_VALUE <= '1';
                fsm_state <= IDLE;
            when others =>
                fsm_state <= IDLE;
                NEW_VALUE <= '0';
        end case;
      end if;
    end if;
  end process;
  
--AVERAGE_TEMP <= std_logic_vector(shift_right(signed(ACCUMULATOR_RESULT), to_integer(unsigned(DIVIDE)))); 
--AVERAGE <= AVERAGE_TEMP(31 downto 0);
  
--pAccumulator: process (S_AXI_CLK, EOF)
--    begin
--      if S_AXI_RESETN = '0' then
--            ACCUMULATOR_TEMP <= (others => '0');
--        elsif rising_edge(S_AXI_CLK) then
--            if (EOF = '1') then
--                ACCUMULATOR_TEMP <= (others => '0');
--            elsif CE = '1' then
--              ACCUMULATOR_TEMP <= ACCUMULATOR_TEMP + MULTIPLIER_RESULT;
--            end if;
--       end if;
--  end process;

   iFRAME_COUNTER : FRAME_COUNTER
      port map (
      S_AXI_CLK              =>  S_AXI_CLK,        -- AXI clock
      S_AXI_CEN              =>  S_AXI_CEN,    
      S_AXI_RESETN           =>  S_AXI_RESETN, 
      S_AXI_TDATA            =>  S_AXI_TDATA,  
      S_AXI_TVALID           =>  S_AXI_TVALID, 
      S_AXI_TREADY           =>  S_AXI_TREADY, 
      S_AXI_USER             =>  S_AXI_USER,   
      S_AXI_TLAST            =>  S_AXI_TLAST,  
      -- Autoreg              
      H_SIZE                 =>  H_SIZE,       
      V_SIZE                 =>  V_SIZE,       
      REF_VALUE              =>  REF_VALUE,    
      RAM_ADDR               =>  RAM_ADDR,
      RAM_DATAWe             =>  RAM_DATAWe,
      RAM_DATACe             =>  RAM_DATACe,
      RAM_DATA_I             =>  RAM_DATA_I,
      RAM_DATA_O             =>  RAM_DATA_O,
                                 
      SIZE_FAULT             =>  SIZE_FAULT,
      CE                     =>  CE_FRAME_COUNTER,
      DATA_OUT_B             =>  WEIGHTS,
      EOF                    =>  EOF   
      );

end RTL;
-- 
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity BRIGHTNESS_METER is
  port (
    -- AXI stream signals.
    M_AXI_CLK      : in  std_logic;                     -- AXI clock
    M_AXI_CEN      : in  std_logic;                     -- AXI clock enable
    M_AXI_RESETN   : in  std_logic;                     -- AXI reset, activ low
    M_AXI_TDATA    : in std_logic_vector(23 downto 0); -- DATA
    M_AXI_TVALID   : in std_logic;                     -- VALID
    M_AXI_TREADY   : in  std_logic;                     -- READY
    M_AXI_USER     : in std_logic;                     -- Start Of Frame
    M_AXI_TLAST    : in std_logic;                     -- End Of Line
    -- Autoreg
    DIVIDE         : in  std_logic_vector(3 downto 0);
    REF_VALUE      : in  std_logic_vector(11 downto 0);
   
    AVERAGE        : out std_logic_vector(31 downto 0);
    NEW_VALUE      : out std_logic;
    SIZE_FAULT     : out std_logic;
    WEIGHTS        : in  std_logic_vector(7 downto 0);
    EOF            : in  std_logic
  );
end entity;

architecture RTL of BRIGHTNESS_METER is

  type t_FSM is (IDLE, SHIFT, NEW_IMAGE);
  
  signal fsm_state : t_FSM;
  signal shift_cnt : unsigned(3 downto 0);
  signal CE                  : std_logic; -- AND of M_AXI_CEN, M_AXI_TVALID and M_AXI_TREADY
  signal SUBTRACT_RESULT_0   : signed(12 downto 0); -- result after subtraction for pixel #0
  signal SUBTRACT_RESULT_1   : signed(12 downto 0); -- result after subtraction for pixel #1
  signal ADDER_RESULT        : signed(13 downto 0); -- result after addition for pixel #0 and pixel #1
  signal MULTIPLIER_RESULT   : signed(21 downto 0); -- result after Multiplication
  signal ACCUMULATOR_TEMP    : signed(44 downto 0);
  signal ACCUMULATOR_RESULT  : signed(44 downto 0);
  signal AVERAGE_TEMP        : std_logic_vector(44 downto 0):= (others => '0');
  signal CE_1T, CE_2T, CE_3T : std_logic;
  signal EOF_1T, EOF_2T, EOF_3T, EOF_4T, EOF_5T, EOF_6T, EOF_7T, EOF_8T : std_logic;
  
begin
  
  process(M_AXI_CLK, M_AXI_RESETN)
  begin
    if M_AXI_RESETN = '0' then
        fsm_state <= IDLE;
        shift_cnt <= (others => '0');
        AVERAGE_TEMP <= (others => '0');
        AVERAGE <= (others => '0');
        NEW_VALUE <= '0';
    elsif rising_edge(M_AXI_CLK) then
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
  end process;
  
  
  -- Make clock enable to simplify code afterwards
  CE  <= M_AXI_CEN and M_AXI_TVALID and M_AXI_TREADY;
  
  pCE_LATENCY: process(M_AXI_CLK)
  begin
        if rising_edge(M_AXI_CLK) then
            CE_1T <= CE;
            CE_2T <= CE_1T;
            CE_3T <= CE_2T;
        end if;
   end process;
   
  pEOF_LATENCY: process(M_AXI_CLK)
   begin
         if rising_edge(M_AXI_CLK) then
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

  pSUBTRACT: process(M_AXI_CLK)
  begin
    if M_AXI_RESETN = '0' then
      ACCUMULATOR_TEMP <= (others => '0');
      ACCUMULATOR_RESULT <= (others => '0');
      SUBTRACT_RESULT_0 <= (others => '0');
      SUBTRACT_RESULT_1 <= (others => '0');
      ADDER_RESULT <= (others => '0');
      MULTIPLIER_RESULT <= (others => '0');
    elsif rising_edge(M_AXI_CLK) then
        if (EOF_7T = '1') then
            ACCUMULATOR_TEMP <= (others => '0');
            ACCUMULATOR_RESULT <= ACCUMULATOR_TEMP;  
        elsif CE = '1' then
            SUBTRACT_RESULT_0 <= signed('0' & M_AXI_TDATA(11 downto 0)) - signed('0' & REF_VALUE);
            SUBTRACT_RESULT_1 <= signed('0' & M_AXI_TDATA(23 downto 12)) - signed('0' & REF_VALUE);
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
  
-- AVERAGE_TEMP <= std_logic_vector(shift_right(signed(ACCUMULATOR_RESULT), to_integer(unsigned(DIVIDE)))); 
-- AVERAGE <= AVERAGE_TEMP(31 downto 0);
 
--pAccumulator: process (M_AXI_CLK, EOF)
--    begin
--      if M_AXI_RESETN = '0' then
--            ACCUMULATOR_TEMP <= (others => '0');
--        elsif rising_edge(M_AXI_CLK) then
--            if (EOF = '1') then
--                ACCUMULATOR_TEMP <= (others => '0');
--            elsif CE = '1' then
--              ACCUMULATOR_TEMP <= ACCUMULATOR_TEMP + MULTIPLIER_RESULT;
--            end if;
--       end if;
--  end process;

end RTL;
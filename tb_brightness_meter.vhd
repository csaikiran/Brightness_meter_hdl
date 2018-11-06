-- 
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity TB_BRIGHTNESS_METER is
end entity;

architecture RTL of TB_BRIGHTNESS_METER is

component TOP_MODULE is
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
    H_SIZE         : in  std_logic_vector(11 downto 0);
    V_SIZE         : in  std_logic_vector(11 downto 0);
    REF_VALUE      : in  std_logic_vector(11 downto 0);
  RAM_ADDR                       : in  std_logic_vector(10 downto 0);
    RAM_DATAWe                     : in  std_logic;
    RAM_DATACe                     : in  std_logic;
    RAM_DATA_I                     : in  std_logic_vector(7 downto 0);
    RAM_DATA_O                     : out std_logic_vector(7 downto 0);
   
    AVERAGE        : out std_logic_vector(31 downto 0);
    NEW_VALUE      : out std_logic;
    SIZE_FAULT     : out std_logic
  );
end component;

  signal M_AXI_RESETN      :   std_logic := '0';                    -- AXI reset, activ low
  signal M_AXI_RESETN_1T   :   std_logic := '0';                    -- AXI reset, activ low

  signal M_AXI_TDATA_LSB   : unsigned(11 downto 0);
  signal M_AXI_TDATA       : std_logic_vector(23 downto 0);
  
  signal M_AXI_CLK         : std_logic := '0';
  
  signal RAM_DATAWe        :  std_logic;
--  signal RAM_MEMENB     :  std_logic;
  signal RAM_DATACe        : std_logic := '0';
  
  signal RAM_ADDR      :  std_logic_vector(10 downto 0);
  signal RAM_DATA_I       :  std_logic_vector(7 downto 0);
  
  
  signal M_AXI_TVALID :  std_logic;
  signal M_AXI_TREADY :  std_logic;
  signal M_AXI_USER   :  std_logic;
  signal M_AXI_TLAST  :  std_logic;
  
begin

M_AXI_CLK <= NOT M_AXI_CLK AFTER 3.367 NS;

  -- Reset = ,1, (active) at start of simulation
  -- Strech reset for one clk period  and deassert
  pRESET: process(M_AXI_CLK)
  begin
    if rising_edge(M_AXI_CLK) then
      M_AXI_RESETN    <= '1' ;
      M_AXI_RESETN_1T <= M_AXI_RESETN;
    end if;
  end process ;
  

  -- Make an incrementing value to be used as pixel data
  pMAINSTIMULUS: process
  begin
      RAM_DATAWe <= '0';
--      RAM_MEMENB <= '0';
      RAM_ADDR <= (others => '0');
      RAM_DATA_I <= (others => '0');
      M_AXI_TDATA_LSB <= (others => '0');
      M_AXI_TLAST <= '0';
      M_AXI_TVALID <= '0';
      M_AXI_TREADY <= '0';
      M_AXI_USER <= '0';
      wait until rising_edge(M_AXI_RESETN);
      wait until rising_edge(M_AXI_CLK);
      for i in 0 to 2047 loop
          RAM_DATAWe <= '1';
--          RAM_MEMENB <= '1';
          RAM_ADDR <= std_logic_vector(to_unsigned(i, 11));
          RAM_DATA_I <= std_logic_vector(to_unsigned(i, 8));
          wait until rising_edge(M_AXI_CLK);
      end loop;
      RAM_DATAWe <= '0';
--      RAM_MEMENB <= '0';
      
      for i in 0 to 2047 loop
          if i = 0 then
              M_AXI_USER <= '1';
          end if;
          for j in 0 to 2448/2 - 1 loop
              M_AXI_TVALID <= '1';
              M_AXI_TREADY <= '1';
              if j = 2448/2 - 1 then
                  M_AXI_TLAST <= '1';
              end if;
              M_AXI_TDATA_LSB <= to_unsigned(i + j, 12);
              wait until rising_edge(M_AXI_CLK);
              M_AXI_TLAST <= '0';
              M_AXI_TVALID <= '0';
              M_AXI_TREADY <= '0';
              M_AXI_USER <= '0';
          end loop;
          wait until rising_edge(M_AXI_CLK);
      end loop;
  end process ;
  
  -- combine two pixels into one data
  M_AXI_TDATA <= std_logic_vector(M_AXI_TDATA_LSB) & std_logic_vector(M_AXI_TDATA_LSB);

-- Map DUT  
I_TOP_MODULE : TOP_MODULE
  port map (
    M_AXI_CLK      => M_AXI_CLK,--: in  std_logic;                     -- AXI clock
    M_AXI_CEN      => '1',--: in  std_logic;                     -- AXI clock enable
    M_AXI_RESETN   => M_AXI_RESETN_1T,--: in  std_logic;                     -- AXI reset, activ low
    M_AXI_TDATA    => M_AXI_TDATA,--: in std_logic_vector(23 downto 0); -- DATA
    M_AXI_TVALID   => M_AXI_TVALID,--: in std_logic;                     -- VALID
    M_AXI_TREADY   => M_AXI_TREADY,--: in  std_logic;                     -- READY
    M_AXI_USER     => M_AXI_USER,--: in std_logic;                     -- Start Of Frame
    M_AXI_TLAST    => M_AXI_TLAST,--: in std_logic;                     -- End Of Line
    -- Autoreg
    DIVIDE         => "1100",--: in  std_logic_vector(3 downto 0);
    H_SIZE         => std_logic_vector(to_unsigned(2448, 12)),--: in  std_logic_vector(11 downto 0);
    V_SIZE         => std_logic_vector(to_unsigned(2048, 12)),--: in  std_logic_vector(12 downto 0);
    REF_VALUE      => "000000010100" ,--: in  std_logic_vector(11 downto 0);
    RAM_ADDR      => RAM_ADDR,--: in  std_logic_vector(10 downto 0);
    RAM_DATAWe        => RAM_DATAWe,--: in  std_logic;
    RAM_DATACe     => RAM_DATACe,--: in  std_logic;
    RAM_DATA_I       => RAM_DATA_I,--: in  std_logic_vector(7 downto 0);
    RAM_DATA_O      => open  ,--: out std_logic_vector(7 downto 0);

    AVERAGE        => open,--: out std_logic_vector(31 downto 0);
    NEW_VALUE      => open,--: out std_logic;
    SIZE_FAULT     => open --: out std_logic
      );
end RTL;

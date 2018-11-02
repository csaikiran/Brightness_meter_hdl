----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/25/2018 09:08:52 AM
-- Design Name: 
-- Module Name: FRAME_COUNTER - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity FRAME_COUNTER is
  Port ( 
    M_AXI_CLK      : in  std_logic;                     -- AXI clock
    M_AXI_CEN      : in  std_logic;                     -- AXI clock enable
    M_AXI_RESETN   : in  std_logic;                     -- AXI reset, activ low
    M_AXI_TDATA    : in std_logic_vector(23 downto 0); -- DATA
    M_AXI_TVALID   : in std_logic;                     -- VALID
    M_AXI_TREADY   : in  std_logic;                     -- READY
    M_AXI_USER     : in std_logic;                     -- Start Of Frame
    M_AXI_TLAST    : in std_logic;                     -- End Of Line
    -- Autoreg
    H_SIZE                         : in  std_logic_vector(11 downto 0);
    V_SIZE                         : in  std_logic_vector(11 downto 0);
    REF_VALUE                      : in  std_logic_vector(11 downto 0);
    RAM_ADDR                       : in  std_logic_vector(10 downto 0);
    RAM_DATAWe                     : in  std_logic;
    RAM_DATACe                     : in  std_logic;
    RAM_DATA_I                     : in  std_logic_vector(7 downto 0);
    RAM_DATA_O                     : out std_logic_vector(7 downto 0);
    
    AVERAGE                        : out std_logic_vector(31 downto 0);
    NEW_VALUE                      : out std_logic;
    SIZE_FAULT                     : out std_logic;
    CE                             : in  std_logic;
    DATA_OUT_B                     : out std_logic_vector(7 downto 0);
    EOF                            : out std_logic
);
end FRAME_COUNTER;


architecture Behavioral of FRAME_COUNTER is


component dual_port_ram is
generic (
   C_AWIDTH : integer := 17;
   C_DWIDTH : integer := 256;
   C_NBPIPE : integer := 1;
   C_NUM_COL : integer := 32;
   C_WIDTH : integer := 8;  -- C_DWIDTH/C_NUM_COL
   C_STYLE : string(1 to 5) := "ultra"
);
port (
   CLK : in  std_logic;                                   -- Clock 
   RSTA : in  std_logic;                                  -- Reset
   WEA : in  std_logic_vector(C_NUM_COL-1 downto 0);      -- Write Enable
   MEMENA : in  std_logic;                               -- Memory Enable
   DINA : in  std_logic_vector(C_DWIDTH-1 downto 0);      -- Data Input  
   ADDRA : in  std_logic_vector(C_AWIDTH-1 downto 0);     -- Address Input
   DOUTA : out std_logic_vector(C_DWIDTH-1 downto 0);     -- Data Output
   RSTB : in  std_logic;                                  -- Reset
   WEB : in  std_logic_vector(C_NUM_COL-1 downto 0);      -- Write Enable
   MEMENB : in  std_logic;                               -- Memory Enable
   DINB : in  std_logic_vector(C_DWIDTH-1 downto 0);      -- Data Input  
   ADDRB : in  std_logic_vector(C_AWIDTH-1 downto 0);     -- Address Input
   DOUTB : out std_logic_vector(C_DWIDTH-1 downto 0)      -- Data Output
);
end component;


  signal ADDR_B             : std_logic_vector(10 downto 0);
  signal H_COUNT            : std_logic_vector(11 downto 0); --Horizantal pixel counter
  signal V_COUNT            : std_logic_vector(10 downto 0); --Vertical pixel counter
  signal H_CENTER           : std_logic_vector(11 downto 0);
  signal V_CENTER           : std_logic_vector(10 downto 0);
--  signal EOF                : std_logic; -- End of Frame
  signal reset              : std_logic; --inverted M_AXI_RESET
  
   signal M_AXI_TVALID_1T, M_AXI_TREADY_1T, M_AXI_TLAST_1T, CE_1T : std_logic;

begin

   pBlock_RAM : dual_port_ram
    generic map( 
    C_AWIDTH    => 11,
    C_DWIDTH    => 8,
    C_NBPIPE    => 1,
    C_NUM_COL   => 1,
    C_WIDTH     => 8,  -- C_DWIDTH/C_NUM_COL
    C_STYLE     => "BLOCK"
    )
    port map (
    CLK         => M_AXI_CLK,                                  
    RSTA        => reset,
    WEA(0)      => RAM_DATAWe,
    MEMENA      => '1',
    DINA        => RAM_DATA_I, 
    ADDRA       => RAM_ADDR,
    DOUTA       => RAM_DATA_O,
    RSTB        => reset,
    WEB(0)      => '0',
    MEMENB      => '1',
    DINB        => "00000000",
    ADDRB       => ADDR_B,
    DOUTB       => DATA_OUT_B
    );

reset <= not M_AXI_RESETN;

ADDR_B <= V_CENTER(10 downto 6) & H_CENTER(11 downto 6);

 pH_COUNTER: process(M_AXI_CLK, M_AXI_RESETN)
  begin
      if M_AXI_RESETN = '0' then
        H_COUNT <= (others => '0');
        M_AXI_TVALID_1T <= '0';
        M_AXI_TREADY_1T <= '0';
        M_AXI_TLAST_1T <= '0';
      elsif rising_edge(M_AXI_CLK) then
          M_AXI_TVALID_1T <= M_AXI_TVALID;
          M_AXI_TREADY_1T <= M_AXI_TREADY;
          M_AXI_TLAST_1T <= M_AXI_TLAST;
          if (M_AXI_TLAST_1T = '1' or M_AXI_USER = '1') and M_AXI_TVALID_1T = '1' and M_AXI_TREADY_1T = '1' then
            H_COUNT <= (others => '0');
          elsif M_AXI_TVALID_1T = '1' and M_AXI_TREADY_1T = '1' then
            H_COUNT <= H_COUNT + 2;
          end if;
      end if;
  end process ;


 pV_COUNTER: process(M_AXI_CLK, M_AXI_RESETN)
  begin
      if M_AXI_RESETN = '0' then
        V_COUNT <= (others => '0');
        CE_1T <= '0';
      elsif rising_edge(M_AXI_CLK) then
         CE_1T <= CE;
         if M_AXI_USER = '1' and CE = '1' then
            V_COUNT <= (others => '0');
          elsif M_AXI_TLAST_1T = '1' and CE_1T = '1' then
            V_COUNT <= V_COUNT + 1;
          end if;
      end if;
  end process ;
  
 pH_CENTER: process(M_AXI_CLK, M_AXI_RESETN)
   begin
       if M_AXI_RESETN = '0' then
         H_CENTER <= (others => '0');
       elsif rising_edge(M_AXI_CLK) then
            H_CENTER <= H_COUNT(11 downto 0) - H_SIZE(11 downto 1);
       end if;
   end process ;
   
 pV_CENTER: process(M_AXI_CLK, M_AXI_RESETN)
     begin
         if M_AXI_RESETN = '0' then
            V_CENTER <= (others => '0');
         elsif rising_edge(M_AXI_CLK) then
            V_CENTER <= V_COUNT(10 downto 0) - V_SIZE(11 downto 1);
         end if;
     end process ;

 pEOF: process(M_AXI_TLAST,CE)
 begin
    if((M_AXI_TLAST = '1') and (CE = '1') and (V_COUNT = V_SIZE-1)) then
        EOF <= '1';
    else
        EOF <= '0';
    end if;
 end process;
 
-- pSIZE_FAULT: process(M_AXI_TLAST,M_AXI_TVALID, M_AXI_TREADY)
-- begin
--    if((M_AXI_TVALID = '1') and (M_AXI_TREADY = '1') and (M_AXI_TLAST = '1') and (H_COUNT_MAXVALUE = H_SIZE-1)) then        
--        SIZE_FAULT <= '0';
--    else
--        SIZE_FAULT <= '1';
--    end if;
-- end process;
     
 pSIZE_FAULT: process(M_AXI_TLAST,CE)
 begin
    if((CE = '1') and (M_AXI_TLAST = '1') and (H_COUNT /= H_SIZE-1)) then        
        SIZE_FAULT <= '1';
    else
        SIZE_FAULT <= '0';
    end if;
 end process;

end Behavioral;
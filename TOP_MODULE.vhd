----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/24/2018 01:13:48 PM
-- Design Name: 
-- Module Name: TOP_MODULE - Behavioral
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
--use IEEE.STD_LOGIC_unsigned.ALL;
--use IEEE.STD_LOGIC_signed.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TOP_MODULE is
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
end TOP_MODULE;

architecture Behavioral of TOP_MODULE is

component BRIGHTNESS_METER 
  port (
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
end component;

component FRAME_COUNTER 
  port (
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
end component;

  signal CE                  : std_logic; -- AND of M_AXI_CEN, M_AXI_TVALID and M_AXI_TREADY
  signal WEIGHTS             : std_logic_vector(7 downto 0); --BRAM PORT A OUTPUT
  signal EOF                 : std_logic; -- End of Frame
  signal M_AXI_CEN_nT, M_AXI_TVALID_nT, M_AXI_TREADY_nT, M_AXI_USER_nT, M_AXI_TLAST_nT : std_logic_vector(5 downto 0);
  signal M_AXI_TDATA_1T, M_AXI_TDATA_2T, M_AXI_TDATA_3T, M_AXI_TDATA_4T, M_AXI_TDATA_5T, M_AXI_TDATA_6T : std_logic_vector(23 downto 0);

begin

  -- Make clock enable to simplify code afterwards
  CE  <= M_AXI_CEN and M_AXI_TVALID and M_AXI_TREADY;

    process(M_AXI_CLK) begin
        if rising_edge(M_AXI_CLK) then
            M_AXI_CEN_nT(0) <= M_AXI_CEN;
            M_AXI_TVALID_nT(0) <= M_AXI_TVALID;
            M_AXI_TREADY_nT(0) <= M_AXI_TREADY;
            M_AXI_USER_nT(0) <= M_AXI_USER;
            M_AXI_TLAST_nT(0) <= M_AXI_TLAST;
            M_AXI_TDATA_1T <= M_AXI_TDATA;
            M_AXI_TDATA_2T <= M_AXI_TDATA_1T;
            M_AXI_TDATA_3T <= M_AXI_TDATA_2T;
            M_AXI_TDATA_4T <= M_AXI_TDATA_3T;
            M_AXI_TDATA_5T <= M_AXI_TDATA_4T;
            M_AXI_TDATA_6T <= M_AXI_TDATA_5T;
            for i in 1 to 5 loop
                M_AXI_CEN_nT(i) <= M_AXI_CEN_nT(i - 1);
                M_AXI_TVALID_nT(i) <= M_AXI_TVALID_nT(i - 1);
                M_AXI_TREADY_nT(i) <= M_AXI_TREADY_nT(i - 1);
                M_AXI_USER_nT(i) <= M_AXI_USER_nT(i - 1);
                M_AXI_TLAST_nT(i) <= M_AXI_TLAST_nT(i - 1);
            end loop;
        end if;    
    end process;

   iBRIGHTNESS_METER : BRIGHTNESS_METER
      port map (
      M_AXI_CLK              =>  M_AXI_CLK,        -- AXI clock
      M_AXI_CEN              =>  M_AXI_CEN_nT(2),    
      M_AXI_RESETN           =>  M_AXI_RESETN, 
      M_AXI_TDATA            =>  M_AXI_TDATA_3T,  
      M_AXI_TVALID           =>  M_AXI_TVALID_nT(2), 
      M_AXI_TREADY           =>  M_AXI_TREADY_nT(2), 
      M_AXI_USER             =>  M_AXI_USER_nT(2),   
      M_AXI_TLAST            =>  M_AXI_TLAST_nT(2),  
      -- Autoreg              
      DIVIDE                 =>  DIVIDE,       
      REF_VALUE              =>  REF_VALUE,    
                                 
      AVERAGE                =>  AVERAGE,      
      NEW_VALUE              =>  NEW_VALUE,    
      SIZE_FAULT             =>  open,
      WEIGHTS                =>  WEIGHTS,
      EOF                    =>  EOF   
      );


   iFRAME_COUNTER : FRAME_COUNTER
      port map (
      M_AXI_CLK              =>  M_AXI_CLK,        -- AXI clock
      M_AXI_CEN              =>  M_AXI_CEN,    
      M_AXI_RESETN           =>  M_AXI_RESETN, 
      M_AXI_TDATA            =>  M_AXI_TDATA,  
      M_AXI_TVALID           =>  M_AXI_TVALID, 
      M_AXI_TREADY           =>  M_AXI_TREADY, 
      M_AXI_USER             =>  M_AXI_USER,   
      M_AXI_TLAST            =>  M_AXI_TLAST,  
      -- Autoreg              
      H_SIZE                 =>  H_SIZE,       
      V_SIZE                 =>  V_SIZE,       
      REF_VALUE              =>  REF_VALUE,    
      RAM_ADDR               =>  RAM_ADDR,
      RAM_DATAWe             =>  RAM_DATAWe,
      RAM_DATACe             =>  RAM_DATACe,
      RAM_DATA_I             =>  RAM_DATA_I,
      RAM_DATA_O             =>  RAM_DATA_O,
                                 
      AVERAGE                =>  open,      
      NEW_VALUE              =>  NEW_VALUE,    
      SIZE_FAULT             =>  SIZE_FAULT,
      CE                     =>  CE,
      DATA_OUT_B             =>  WEIGHTS,
      EOF                    =>  EOF   
      );
  

end Behavioral;
--  Xilinx UltraRAM True Dual Port Mode with Byte-write.  This code implements 
--  a parameterizable UltraRAM or BRAM block with write/read on both ports in 
--  No change behavior on both the ports . The behavior of this RAM is 
--  when data is written, the output of RAM is unchanged w.r.t each port. 
--  Only when write is inactive data corresponding to the address is 
--  presented on the output port.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity dual_port_ram is
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
end entity;

architecture RTL of dual_port_ram is

-- Internal Signals
type tMEM is array(natural range<>) of std_logic_vector(C_DWIDTH-1 downto 0);
type PIPE_DATA_T is array(natural range<>) of std_logic_vector(C_DWIDTH-1 downto 0);
type PIPE_EN_T is array(natural range<>) of std_logic;

signal MEM : tMEM(2**C_AWIDTH-1 downto 0) := (others => (others => '0'));  -- Memory Declaration

signal MEMREGA : std_logic_vector(C_DWIDTH-1 downto 0);              
signal MEM_PIPE_REGA : PIPE_DATA_T(C_NBPIPE-1 downto 0);    -- Pipelines for memory
signal MEM_EN_PIPE_REGA : PIPE_EN_T(C_NBPIPE downto 0);     -- Pipelines for memory enable  

signal MEMREGB : std_logic_vector(C_DWIDTH-1 downto 0);              
signal MEM_PIPE_REGB : PIPE_DATA_T(C_NBPIPE-1 downto 0);    -- Pipelines for memory
signal MEM_EN_PIPE_REGB : PIPE_EN_T(C_NBPIPE downto 0);     -- Pipelines for memory enable 

constant ZERO_VECTOR : std_logic_vector(C_NUM_COL-1 downto 0) := (others => '0');
attribute ram_style : string;
attribute ram_style of MEM : signal is C_STYLE;

begin

-- Insert the following in the architecture after the begin keyword

-- RAM : Read has one latency, Write has one latency as well.
process(CLK)
begin
  if (rising_edge (CLK)) then
    if(MEMENA = '1') then
    for i in 0 to C_NUM_COL-1 loop
      if(WEA(i) = '1') then
        MEM(to_integer(unsigned(ADDRA)))((i+1)*C_WIDTH-1 downto i*C_WIDTH) <= DINA((i+1)*C_WIDTH-1 downto i*C_WIDTH);
      end if;
     end loop;
    end if;
  end if;
end process;

process(CLK)
begin
 if (rising_edge (CLK)) then
  if(MEMENA = '1') then
    if( WEA = ZERO_VECTOR) then
      MEMREGA <= MEM(to_integer(unsigned(ADDRA)));
    end if;
  end if;
 end if;
end process;
-- The enable of the RAM goes through a pipeline to produce a
-- series of pipelined enable signals required to control the data
-- pipeline.
process(CLK)
begin
  if(CLK'event and CLK = '1') then
    MEM_EN_PIPE_REGA(0) <= MEMENA;
    for i in 0 to C_NBPIPE-1 loop
      MEM_EN_PIPE_REGA(i+1) <= MEM_EN_PIPE_REGA(i);
    end loop;
  end if;
end process;

-- RAM output data goes through a pipeline.
process(CLK)
begin
  if(CLK'event and CLK = '1') then
    if(MEM_EN_PIPE_REGA(0) = '1') then
      MEM_PIPE_REGA(0) <= MEMREGA;
    end if;
    for i in 0 to C_NBPIPE-2 loop
      if(MEM_EN_PIPE_REGA(i+1) = '1') then
        MEM_PIPE_REGA(i+1) <= MEM_PIPE_REGA(i);
      end if;
    end loop;
  end if;
end process;

-- Final output register gives user the option to add a reset and
-- an additional enable signal just for the data ouptut

process(CLK)
begin
  if(CLK'event and CLK = '1') then
    if(RSTA = '1' or MEM_EN_PIPE_REGA(C_NBPIPE) = '0') then
      DOUTA <= (others => '0');
    else
      DOUTA <= MEM_PIPE_REGA(C_NBPIPE-1);
    end if;
  end if;    
end process;


-- RAM : Read has one latency, Write has one latency as well.
--process(CLK)
--begin
--  if(CLK'event and clk='1')then
--    if(MEMENB = '1') then
--     for i in 0 to C_NUM_COL-1 loop
--      if(WEB(i) = '1') then
--        MEM(to_integer(unsigned(ADDRB)))((i+1)*C_WIDTH-1 downto i*C_WIDTH) <= DINB((i+1)*C_WIDTH-1 downto i*C_WIDTH);
--      end if;
--     end loop;
--    end if;
--  end if;
--end process;

process(CLK)
begin
 if(CLK'event and clk='1')then
  if(MEMENB = '1') then
    if(WEB = ZERO_VECTOR) then
      MEMREGB <= MEM(to_integer(unsigned(ADDRB)));
    end if;
  end if;
 end if;
end process;

-- The enable of the RAM goes through a pipeline to produce a
-- series of pipelined enable signals required to control the data
-- pipeline.
process(CLK)
begin
  if(CLK'event and CLK = '1') then
    MEM_EN_PIPE_REGB(0) <= MEMENB;
    for i in 0 to C_NBPIPE-1 loop
      MEM_EN_PIPE_REGB(i+1) <= MEM_EN_PIPE_REGB(i);
    end loop;
  end if;
end process;

-- RAM output data goes through a pipeline.
process(CLK)
begin
  if(CLK'event and CLK = '1') then
    if(MEM_EN_PIPE_REGB(0) = '1') then
      MEM_PIPE_REGB(0) <= MEMREGB;
    end if;
    for i in 0 to C_NBPIPE-2 loop
      if(MEM_EN_PIPE_REGB(i+1) = '1') then
        MEM_PIPE_REGB(i+1) <= MEM_PIPE_REGB(i);
      end if;
    end loop;
  end if;
end process;

-- Final output register gives user the option to add a reset and
-- an additional enable signal just for the data ouptut

process(CLK)
begin
  if(CLK'event and CLK = '1') then
    if(RSTB = '1' or MEM_EN_PIPE_REGB(C_NBPIPE) = '0') then
      DOUTB <= (others => '0');
    else
      DOUTB <= MEM_PIPE_REGB(C_NBPIPE-1);
    end if;
  end if;    
end process;

end RTL;
LIBRARY ieee;
USE ieee.std_logic_1164.all;
--USE ieee.std_logic_arith.all;
use ieee.numeric_std.all;

ENTITY bram2port IS
    GENERIC( 
        C_DWIDTH : integer := 8;
        C_AWIDTH : integer := 11
    );
    PORT( 
        CLK     : in     std_logic;                                            --Clock
        RSTA    : in     std_logic;
        RSTB    : in     std_logic;
        WEA     : in     std_logic;
        WEB     : in     std_logic;
        ADDRA : IN     std_logic_vector (C_AWIDTH - 1 DOWNTO 0);
        ADDRB : IN     std_logic_vector (C_AWIDTH - 1 DOWNTO 0);
        DINA : IN     std_logic_vector (C_DWIDTH - 1 DOWNTO 0);
        DINB : IN     std_logic_vector (C_DWIDTH - 1 DOWNTO 0);
--        MEMENA : in std_logic; -- Write enable for port A
--        MEMENB: in std_logic;
        DOUTA       : OUT    std_logic_vector (C_DWIDTH - 1 DOWNTO 0);
        DOUTB       : OUT    std_logic_vector (C_DWIDTH - 1 DOWNTO 0)
    );
END bram2port ;

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
USE ieee.STD_LOGIC_UNSIGNED.all;


ARCHITECTURE struct OF bram2port IS
-- Architecture declarations
type t_mem is array(natural range<>) of std_logic_vector(C_DWIDTH - 1 downto 0);

-- Internal signal declarations
SIGNAL ADDRA_z : std_logic_vector(C_AWIDTH - 1 DOWNTO 0);
SIGNAL ADDRB_z : std_logic_vector(C_AWIDTH - 1 DOWNTO 0);
SIGNAL DINA_z : std_logic_vector(C_DWIDTH - 1 DOWNTO 0);
SIGNAL DINB_z : std_logic_vector(C_DWIDTH - 1 DOWNTO 0);
SIGNAL MEM       : t_MEM(2**C_AWIDTH-1 DOWNTO 0):= (others => (others => '0'));  -- Memory Declaration
SIGNAL DOUTA_ta       : std_logic_vector(C_DWIDTH - 1 DOWNTO 0);
SIGNAL DOUTB_tb       : std_logic_vector(C_DWIDTH - 1 DOWNTO 0);
SIGNAL WEA_z    : std_logic;
SIGNAL WEB_z    : std_logic;
--signal MEMENA_z : std_logic;
--signal MEMENB_z : std_logic;


BEGIN
        DOUTA <= DOUTA_ta;
        DOUTB <= DOUTB_tb;
    
process(CLK, RSTA)
begin
    if rising_edge(CLK) then
        if RSTA = '1' then
            ADDRA_z <= (others => '0');
            ADDRB_z <= (others => '0');
            DOUTA_ta       <= (others => '0');
            DOUTB_tb      <= (others => '0');
            DINA_z <= (others => '0');
            DINB_z <= (others => '0');
            WEA_z     <= '0';
            WEB_z     <= '0';
--            MEMENA_z <= '0';
--            MEMENB_z <= '0';
        else
            WEA_z <= WEA;
            WEB_z <= WEB;
            ADDRA_z <= ADDRA;
            DINA_z <= DINA;
            DINB_z <= DINB;
            ADDRB_z <= ADDRB;
--            MEMENA_z <= MEMENA;
--            MEMENB_z <= MEMENB;
                
--         if MEMENA_z  = '1' then
            DOUTA_ta <= MEM(conv_integer(ADDRA_z));
--         end if;
--         if MEMENB_z = '1' then
            DOUTB_tb <= MEM(conv_integer(ADDRB_z));
--         end if;
--          if WEA_z = '1' and memena_z = '1' then
          if WEA_z = '1' then
             MEM(conv_integer(ADDRA_z)) <= DINA_z;
          end if;
--          if WEB_z = '1' and memenb_z = '1' then
          if WEB_z = '1' then
             MEM(conv_integer(ADDRB_z)) <= DINB_z;
          end if;
        end if;
   end if;
end process;

END struct;

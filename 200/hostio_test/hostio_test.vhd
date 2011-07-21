----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    01:01:58 01/18/2011 
-- Design Name: 
-- Module Name:    hostio_test - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use UNISIM.vcomponents.all;
use work.CommonPckg.all;
use work.ClkgenPckg.all;
use work.HostIoPckg.all;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity hostio_test is
  port (
    clk_p       : in  std_logic;
    heartBeat_p : out std_logic;
    diag_p      : out std_logic_vector(7 downto 0)
    );
end hostio_test;


architecture Behavioral of hostio_test is
  
  signal inShiftDr_s                : std_logic;
  signal drck_s                     : std_logic;
  signal tdi_s                      : std_logic;
  signal tdo_s                      : std_logic;
  signal tdo0_s                     : std_logic;
  signal tdo1_s                     : std_logic;
  signal tdo2_s                     : std_logic;
  signal test_reg                   : std_logic_vector(31 downto 0) := "11011110101011011011111011101111";
  signal clk100_s                   : std_logic;
  signal wr0, rd0                   : std_logic;
  signal wr1, rd1                   : std_logic;
  signal done                       : std_logic;
  signal data_to_reg, data_from_reg : std_logic_vector(test_reg'range);
  signal data_to_mem, data_from_mem : std_logic_vector(15 downto 0);
  signal address0                   : std_logic_vector(3 downto 0);
  signal address1                   : std_logic_vector(9 downto 0);
  signal cnt_r                      : std_logic_vector(31 downto 0);
  signal cntr_r                     : std_logic_vector(3 downto 0) := "1011";
  signal cntrCtrl_s                 : std_logic_vector(0 downto 0);
  signal cntrClk_s                  : std_logic;

begin
  
  Uclkgen : clkgen generic map (CLK_MUL_G => 3, CLK_DIV_G => 3) port map (I => clk_p, O => clk100_s);

  UBscanToHostIo : BscanToHostIo
    port map (
      inShiftDr_p => inShiftDr_s,
      drck_p      => drck_s,
      tdi_p       => tdi_s,
      tdo_p       => tdo_s
      );

  tdo_s <= tdo0_s or tdo1_s or tdo2_s;

  UHostIoToMemory0 : HostIoToRam
    generic map (
      ID_G => "00001100"
      )
    port map (
      inShiftDr_p      => inShiftDr_s,
      drck_p           => drck_s,
      tdi_p            => tdi_s,
      tdo_p            => tdo0_s,
      -- Interface to the memory.
      clk_p            => clk100_s,
      addrToMemory_p   => address0,
      wrToMemory_p     => wr0,
      dataToMemory_p   => data_to_reg,
      rdFromMemory_p   => rd0,
      dataFromMemory_p => data_from_reg,
      memoryOpDone_p   => HI
      );

  UHostIoToMemory1 : HostIoToRam
    generic map (
      ID_G => "00001101"
      )
    port map (
      inShiftDr_p      => inShiftDr_s,
      drck_p           => drck_s,
      tdi_p            => tdi_s,
      tdo_p            => tdo1_s,
      -- Interface to the memory.
      clk_p            => clk100_s,
      addrToMemory_p   => address1,
      wrToMemory_p     => wr1,
      dataToMemory_p   => data_to_mem,
      rdFromMemory_p   => rd1,
      dataFromMemory_p => data_from_mem,
      memoryOpDone_p   => HI
      );

  done <= wr1 or rd1;

  UHostIoToDut : HostIoToDut
    generic map (
      ID_G => "00001110"
      )
    port map (
      inShiftDr_p     => inShiftDr_s,
      drck_p          => drck_s,
      tdi_p           => tdi_s,
      tdo_p           => tdo2_s,
      -- Test vector I/O.
      clkToDut_p      => cntrClk_s,
      vectorToDut_p   => cntrCtrl_s,
      vectorFromDut_p => cntr_r
      );

  process(cntrClk_s)
  begin
    if rising_edge(cntrClk_s) then
      case cntrCtrl_s is
        when "1" =>
          cntr_r <= cntr_r + 1;
        when others =>
          cntr_r <= cntr_r - 1;
      end case;
    end if;
  end process;


  process(clk100_s)
  begin
    if rising_edge(clk100_s) then
      if wr0 = HI then
        test_reg <= data_to_reg;
      end if;
    end if;
  end process;

  data_from_reg <= test_reg;

  diag_p <= test_reg(diag_p'range);

  URAMB16_S18 : RAMB16_S18
    generic map (
      INIT       => X"000000000",  --  Value of output RAM registers at startup
      SRVAL      => X"000000000",       --  Ouput value upon SSR assertion
      write_mode => "WRITE_FIRST"  --  WRITE_FIRST, READ_FIRST or NO_CHANGE
      )
    port map (
      DO   => data_from_mem,            -- 32-bit Data Output
      ADDR => address1,                 -- 9-bit Address Input
      CLK  => clk100_s,                 -- Clock
      DI   => data_to_mem,              -- 32-bit Data Input
      DIP  => "00",
      EN   => HI,                       -- RAM Enable Input
      SSR  => LO,                       -- Synchronous Set/Reset Input
      WE   => wr1                       -- Write Enable Input
      );

  process(clk100_s)
  begin
    if rising_edge(clk100_s) then
      cnt_r <= cnt_r + 1;
    end if;
  end process;

  heartBeat_p <= cnt_r(23);

end Behavioral;

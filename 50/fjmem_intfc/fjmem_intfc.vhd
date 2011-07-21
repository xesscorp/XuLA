----------------------------------------------------------------------------------
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 2
-- of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
-- 02111-1307, USA.
--
-- ©1997-2010 - X Engineering Software Systems Corp. (www.xess.com)
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- SDRAM & flash upload/download via JTAG.
--------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use work.CommonPckg.all;
use work.fjmem_config_pack.all;         -- SDRAM & flash parameters
use work.fjmem_pack.all;
use work.fjmem.all;
use work.SdramCntlPckg.all;

library UNISIM;
use UNISIM.VComponents.all;


entity fjmem_intfc is
  generic(
    BASE_FREQ_G : real    := 12.0;        -- base frequency in MHz
    CLK_MUL_G   : natural := 25;          -- multiplier for base frequency
    CLK_DIV_G   : natural := 3            -- divider for base frequency
    );
  port(
    fpgaClk     : in    std_logic;     -- main clock input
    ------------------- SDRAM interface --------------------
    sdramClk    : out   std_logic;     -- clock to SDRAM
    sdramClkFb : in    std_logic;     -- SDRAM clock comes back in
    ras_b        : out   std_logic;     -- SDRAM RAS
    cas_b        : out   std_logic;     -- SDRAM CAS
    we_b         : out   std_logic;     -- SDRAM write-enable
    bs           : out   std_logic;     -- SDRAM bank-address
    a            : out   std_logic_vector(11 downto 0);  -- SDRAM address bus
    d            : inout std_logic_vector(sdram_data_width_c-1 downto 0)  -- data bus to/from SDRAM
    );
end entity;


architecture arch of fjmem_intfc is

  constant FREQ_G : real := (BASE_FREQ_G * real(CLK_MUL_G)) / real(CLK_DIV_G);

  -- clock and reset signals
  signal clk   : std_logic;
  signal reset : std_logic;

  -- signals to/from the JTAG BSCAN module
  signal bscan_drck   : std_logic;      -- JTAG clock from BSCAN module
  signal bscan_reset  : std_logic;      -- true when BSCAN module is reset
  signal bscan_sel    : std_logic;      -- true when BSCAN module selected
  signal bscan_shift  : std_logic;  -- true when TDI & TDO are shifting data
  signal bscan_update : std_logic;      -- BSCAN TAP is in update-dr state
  signal bscan_tdi    : std_logic;      -- data received on TDI pin
  signal bscan_tdo    : std_logic;      -- scan data sent to TDO pin

  -- Signals to/from the fjmem JTAG interface
  signal fjmem_strobe : std_logic;
  signal fjmem_rd     : std_logic;
  signal fjmem_wr     : std_logic;
  signal fjmem_ack    : std_logic;
  signal fjmem_cs     : std_logic_vector(num_blocks_c-1 downto 0);
  signal fjmem_addr   : std_logic_vector(max_addr_width_c-1 downto 0);
  signal fjmem_din    : std_logic_vector(max_data_width_c-1 downto 0);
  signal fjmem_dout   : std_logic_vector(fjmem_din'range);

  -- signals to/from the SDRAM controller
  signal sdram_hrd          : std_logic;  -- host read enable
  signal sdram_hwr          : std_logic;  -- host write enable
  signal sdram_earlyOpBegun : std_logic;  -- true when current read/write has begun
  signal sdram_done         : std_logic;  -- true when current read/write is done
  signal sdram_haddr        : std_logic_vector(sdram_addr_width_c-1 downto 0);  -- host address
  signal sdram_hdin         : std_logic_vector(sdram_data_width_c-1 downto 0);  -- data input from host
  signal sdram_hdout        : std_logic_vector(sdram_hdin'range);  -- host data output to host
  
begin

  CORE_DCM : DCM_SP
    generic map (
      CLKDV_DIVIDE          => 2.0,
      CLKFX_DIVIDE          => CLK_DIV_G,  --  Can be any interger from 1 to 32
      CLKFX_MULTIPLY        => CLK_MUL_G,  --  Can be any integer from 1 to 32
      CLKIN_DIVIDE_BY_2     => false,  --  TRUE/FALSE to enable CLKIN divide by two feature
      CLKIN_PERIOD          => 1000.0 / BASE_FREQ_G,  --  Specify period of input clock
      CLKOUT_PHASE_SHIFT    => "NONE",  --  Specify phase shift of NONE, FIXED or VARIABLE
      CLK_FEEDBACK          => "NONE",  --  Specify clock feedback of NONE, 1X or 2X
      DESKEW_ADJUST         => "SYSTEM_SYNCHRONOUS",
      DLL_FREQUENCY_MODE    => "LOW",   --  HIGH or LOW frequency mode for DLL
      DUTY_CYCLE_CORRECTION => true,   --  Duty cycle correction, TRUE or FALSE
      PHASE_SHIFT           => 0,  --  Amount of fixed phase shift from -255 to 255
      STARTUP_WAIT          => false)  --  Delay configuration DONE until DCM LOCK, TRUE/FALSE
    port map (
      RST   => '0',                     -- DCM asynchronous reset input
      CLKIN => fpgaClk,           -- Clock input (from IBUFG, BUFG or DCM)
      CLKFX => sdramClk                -- Clock to SDRAM
      );

  clk <= sdramClkFb;  -- main clock is SDRAM clock fed back into FPGA

  -- generate a reset signal  
  process(clk)
    constant reset_dly_c : natural               := 10;
    variable rst_cntr    : natural range 0 to 15 := 0;
  begin
    if rising_edge(clk) then
      reset <= NO;
      if rst_cntr < reset_dly_c then
        reset    <= YES;
        rst_cntr := rst_cntr + 1;
      end if;
    end if;
  end process;

  -- boundary-scan interface to FPGA JTAG port
  u_bscan : BSCAN_SPARTAN3
    port map(
      DRCK1  => bscan_drck,             -- JTAG clock
      RESET  => bscan_reset,            -- true when JTAG TAP FSM is reset
      SEL1   => bscan_sel,  -- USER1 instruction enables execution of the RAM interface
      SHIFT  => bscan_shift,  -- true when JTAG TAP FSM is in the SHIFT-DR state
      TDI    => bscan_tdi,  -- data bits from the PC arrive through here
      UPDATE => bscan_update,
      TDO1   => bscan_tdo,  -- LSbit of the tdo register outputs onto TDO pin and to the PC
      TDO2   => '0'         -- not using this input, so just hold it low
      );

  -- JTAG/memory-bus interface
  u1 : fjmem_core
    port map(
      -- JTAG Interface ---------------------------------------------------------
      clkdr_i  => bscan_drck,
      trst_i   => '0',
      shift_i  => bscan_shift,
      update_i => bscan_update,
      tdi_i    => bscan_tdi,
      tdo_o    => bscan_tdo,
      -- Memory Bus Interface -------------------------------------------------------
      clk_i    => clk,
      res_i    => reset,
      strobe_o => fjmem_strobe,
      read_o   => fjmem_rd,
      write_o  => fjmem_wr,
      ack_i    => fjmem_ack,
      cs_o     => fjmem_cs,
      addr_o   => fjmem_addr,
      din_i    => fjmem_din,
      dout_o   => fjmem_dout
      );

  fjmem_ack <= sdram_done;
  fjmem_din <= sdram_hdout;

  -- Generate the SDRAM R/W control signals.
  process(clk)
  begin
    if rising_edge(clk) then
      if fjmem_strobe = '1' then
        if fjmem_cs(0) = '1' then
          -- Read/write the SDRAM once it is selected and the strobe occurs.
          -- (The strobe should only last for 1 clock cycle.)
          sdram_hwr   <= fjmem_wr;
          sdram_hrd   <= fjmem_rd;
          sdram_hdin  <= fjmem_dout(sdram_hdin'range);
          sdram_haddr <= fjmem_addr(sdram_haddr'range);
        end if;
      end if;
      if sdram_earlyOpBegun = '1' then
        -- Remove the latched R/W signals once the R/W operation begins.
        sdram_hwr <= '0';
        sdram_hrd <= '0';
      end if;
    end if;
  end process;

  -- SDRAM controller
  u2 : SdramCntl
    generic map(
      FREQ_G        => FREQ_G,
      PIPE_EN_G     => true,
      DATA_WIDTH_G  => sdram_data_width_c,
      HADDR_WIDTH_G => sdram_addr_width_c
      )
    port map(
      clk          => clk,
      lock         => YES,
      rst          => reset,
      rd           => sdram_hrd,
      wr           => sdram_hwr,
      rdPending    => open,
      opBegun      => open,
      earlyOpBegun => sdram_earlyOpBegun,
      rdDone       => sdram_done,
      done         => open,
      hAddr        => sdram_haddr,
      hDIn         => sdram_hdin,
      hDOut        => sdram_hdout,
      status       => open,
      cke          => open,
      ce_n         => open,
      ras_b        => ras_b,
      cas_b        => cas_b,
      we_b         => we_b,
      ba(0)        => bs,
      ba(1)        => open,
      sAddr        => a,
      sData        => d,
      dqmh         => open,
      dqml         => open
      );

end architecture;

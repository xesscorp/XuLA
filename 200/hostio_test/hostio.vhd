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
-- ©2011 - X Engineering Software Systems Corp.
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Modules for passing bits back and forth from the host PC
-- over the USB link and through the JTAG port of the FPGA.
--
-- Rev 1.0, 1/17/2011, Initial release, Dave Vandenbout/XESS.
----------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;

package HostIoPckg is

  component HostIoCore is
    generic (
      opcodeLength_g    : natural := 8;
      oprndCntrLength_g : natural := 32
      );
    port (
      reset_p       : in  std_logic;    -- Active-high reset signal.
      clk_p         : in  std_logic;  -- Fast clock from FPGA application logic. 
      -- Interface to BSCAN primitive.
      drck_p        : in  std_logic;    -- Slow clock from JTAG TAP.
      sel_p         : in  std_logic;  -- True when TAP has received USER instruction.
      shift_p       : in  std_logic;    -- True when TAP is in Shift-DR state.
      tdi_p         : in  std_logic;  -- Data bits from host enter through BSCAN TDI pin.
      update_p      : in  std_logic;    -- Not used.
      tdo_p         : out std_logic;  -- Data bits to host exit through BSCAN TDO pin.
      -- Interface to FPGA application logic.
      opcode_p      : out std_logic_vector;  -- Opcode of instruction received from host.
      oprndCntr_p   : out std_logic_vector;  -- Number of remaining operand bits that follow instruction.
      enable_p      : out std_logic;  -- True when an instruction has been received and while operand bits are arriving.
      bitStrobe_p   : out std_logic;  -- True when a bit is available from the host.
      bitFromHost_p : out std_logic;  -- Bit from the host to the FPGA application logic.
      bitToHost_p   : in  std_logic  -- Bit from the FPGA application logic to the host.
      );
  end component;

  component HostIo is
    generic (
      opcodeLength_g    : natural := 8;
      oprndCntrLength_g : natural := 32
      );
    port (
      reset_p       : in  std_logic;    -- Active-high reset signal.
      clk_p         : in  std_logic;  -- Fast clock from FPGA application logic. 
      opcode_p      : out std_logic_vector;  -- Opcode of instruction received from host.
      oprndCntr_p   : out std_logic_vector;  -- Number of remaining operand bits that follow instruction.
      enable_p      : out std_logic;  -- True when an instruction has been received and while operand bits are arriving.
      bitStrobe_p   : out std_logic;  -- True when a bit is available from the host.
      bitFromHost_p : out std_logic;  -- Bit from the host to the FPGA application logic.
      bitToHost_p   : in  std_logic  -- Bit from the FPGA application logic to the host.
      );
  end component;

  component HostIoToRamCore is
    generic (
      opcode_g : std_logic_vector := "11111111"  -- The opcode this module responds to.
      );
    port (
      reset_p       : in  std_logic;    -- Active-high reset signal.
      clk_p         : in  std_logic;  -- Fast clock from FPGA application logic. 
      -- Interface to HostIo.
      opcode_p      : in  std_logic_vector;  -- Opcode of instruction received from host.
      oprndCntr_p   : in  std_logic_vector;  -- Number of remaining operand bits that follow instruction.
      enable_p      : in  std_logic;  -- True when an instruction has been received and while operand bits are arriving.
      bitStrobe_p   : in  std_logic;  -- True when a bit is available from the host.
      bitFromHost_p : in  std_logic;  -- Bit from the host to the FPGA application logic.
      bitToHost_p   : out std_logic;  -- Bit from the FPGA application logic to the host.
      -- Interface to RAM.
      addrToRam_p   : out std_logic_vector;  -- Address to RAM.
      wrToRam_p     : out std_logic;    -- Write data to RAM when high.
      dataToRam_p   : out std_logic_vector;  -- Data written to RAM.
      rdFromRam_p   : out std_logic;    -- Read data from RAM when high.
      dataFromRam_p : in  std_logic_vector;  -- Data read from RAM.
      ramOpDone_p   : in  std_logic  -- High when read/write operation is done.
      );
  end component;

end package;


library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use UNISIM.VComponents.all;
use work.common.all;
use work.SyncToClockPckg.all;
use work.HostIoPckg.all;

entity HostIoCore is
  generic (
    opcodeLength_g    : natural := 8;
    oprndCntrLength_g : natural := 32
    );
  port (
    reset_p       : in  std_logic;      -- Active-high reset signal.
    clk_p         : in  std_logic;  -- Fast clock from FPGA application logic. 
    -- Interface to BSCAN primitive.
    drck_p        : in  std_logic;      -- Slow clock from JTAG TAP.
    sel_p         : in  std_logic;  -- True when TAP has received USER instruction.
    shift_p       : in  std_logic;      -- True when TAP is in Shift-DR state.
    tdi_p         : in  std_logic;  -- Data bits from host enter through BSCAN TDI pin.
    update_p      : in  std_logic;      -- Not used.
    tdo_p         : out std_logic;  -- Data bits to host exit through BSCAN TDO pin.
    -- Interface to FPGA application logic.
    opcode_p      : out std_logic_vector(opcodeLength_g-1 downto 0);  -- Opcode of instruction received from host.
    oprndCntr_p   : out std_logic_vector(oprndCntrLength_g-1 downto 0);  -- # of remaining operand bits following instruction.
    enable_p      : out std_logic;  -- True after instruction has arrived and while operand bits are arriving.
    bitStrobe_p   : out std_logic;  -- True when a bit is available from the host.
    bitFromHost_p : out std_logic;  -- Bit from the host to the FPGA application logic.
    bitToHost_p   : in  std_logic  -- Bit from the FPGA application logic to the host.
    );
end entity;

architecture arch of HostIoCore is
  -- Signals from BSCAN primitive after being sync'ed to FPGA app. logic clock domain.
  signal drck_s               : std_logic;
  signal reset_s              : std_logic;
  signal sel_s                : std_logic;
  signal shift_s              : std_logic;
  signal tdi_s                : std_logic;
  signal update_s             : std_logic;
  -- The instruction register contains the opcode field, a field with the # of operand bits that follow, plus a bit to indicate the receipt of an instruction.
  constant opcdLen_c          : natural                                  := opcode_p'length;  -- Opcode length set by opcode_p bus width.
  constant opcdLo_c           : natural                                  := 1;  -- Starts at 1, not 0; bit 0 is used to indicate receipt of instruction.
  constant opcdHi_c           : natural                                  := opcdLo_c + opcdLen_c - 1;
  constant oprndCntrLen_c     : natural                                  := oprndCntr_p'length;  -- # of bits field length is set by oprndBitCntr_p bus width.
  constant oprndCntrLo_c      : natural                                  := opcdHi_c + 1;
  constant oprndCntrHi_c      : natural                                  := oprndCntrLo_c + oprndCntrLen_c - 1;
  signal instr_r              : std_logic_vector(oprndCntrHi_c downto 0) := (others => ZERO);
  alias oprndCntr_r           : std_logic_vector(oprndCntr_p'range) is instr_r(oprndCntrHi_c downto oprndCntrLo_c);
  alias opcode_r              : std_logic_vector(opcdLen_c-1 downto 0) is instr_r(opcdHi_c downto opcdLo_c);
  alias instrRcvd_r           : std_logic is instr_r(0);  -- bit 0 of the instruction is used to indicate when a complete instruction has been received.
  signal prevDrck_r           : std_logic;  -- previous level on DRCK used for detecting edges.
  signal risingEdgeOnDrck_s   : boolean;
  signal inUserShiftDrState_s : boolean;  -- True when instructions or operands are being received.
begin

  -- Sync signals from BSCAN to the clock domain of the FPGA application logic.
  USyncDrck   : SyncToClockDomain port map(clk_p => clk_p, unsynced_p => drck_p, synced_p => drck_s);
  USyncReset  : SyncToClockDomain port map(clk_p => clk_p, unsynced_p => reset_p, synced_p => reset_s);
  USyncSel    : SyncToClockDomain port map(clk_p => clk_p, unsynced_p => sel_p, synced_p => sel_s);
  USyncShift  : SyncToClockDomain port map(clk_p => clk_p, unsynced_p => shift_p, synced_p => shift_s);
  USyncTdi    : SyncToClockDomain port map(clk_p => clk_p, unsynced_p => tdi_p, synced_p => tdi_s);
  USyncUpdate : SyncToClockDomain port map(clk_p => clk_p, unsynced_p => update_p, synced_p => update_s);

  -- Detect when a USER JTAG instruction is active and the TAP FSM is in the Shift-DR state.
  inUserShiftDrState_s <= reset_s = LO and shift_s = HI and sel_s = HI;

  -- Detect a rising edge on the JTAG clock.
  risingEdgeOnDrck_s <= prevDrck_r = LO and drck_s = HI;

  -- Scan in the instruction and any following operand bits.
  process(clk_p)
  begin
    if rising_edge(clk_p) then

      -- Reset the instruction register if BSCAN is reset or drops out of SHIFT-DR state in USER instruction mode or if the current instruction is done.
      if (not inUserShiftDrState_s) or (oprndCntr_r = 0 and instrRcvd_r = ONE) then
        -- Clear the instruction register and set MSbit.  An instruction has been received
        -- when this bit has been shifted all the way through the register and into the LSbit.
        instr_r               <= (others => ZERO);
        instr_r(instr_r'high) <= ONE;
      -- Otherwise, shift in instruction bits on the rising edge of DRCK.
      elsif risingEdgeOnDrck_s then
        -- Shift bits into the instruction register until a complete instruction is received. 
        if instrRcvd_r = ZERO then
          instr_r <= tdi_s & instr_r(instr_r'high downto 1);
        -- After an instruction has been received, count down the number of operand bits following the instruction.
        else
          oprndCntr_r <= oprndCntr_r - 1;
        end if;
      end if;

      prevDrck_r <= drck_s;  -- Save current JTAG clock level so the rising edge can be detected.

    end if;
  end process;

  -- Send the instruction fields to the FPGA application circuitry.
  opcode_p      <= opcode_r;
  oprndCntr_p   <= oprndCntr_r;  -- This counts down the number of operand bits still to be received.
  enable_p      <= instrRcvd_r;  -- Tell the external circuitry an instruction is available.
  -- Bits to and from the host are attached to the external circuitry along with the bit strobe.
  bitStrobe_p   <= HI when risingEdgeOnDrck_s else LO;
  bitFromHost_p <= tdi_s;        -- Data bit from host to external circuitry.
  tdo_p         <= bitToHost_p;  -- Data bit from external circuitry to host is not sync'ed to JTAG DRCK clock.
end architecture;


library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use UNISIM.VComponents.all;
use work.common.all;
use work.HostIoPckg.all;

entity HostIo is
  generic (
    opcodeLength_g    : natural := 8;
    oprndCntrLength_g : natural := 32
    );
  port (
    reset_p       : in  std_logic;      -- Active-high reset signal.
    clk_p         : in  std_logic;  -- Fast clock from FPGA application logic. 
    opcode_p      : out std_logic_vector(opcodeLength_g-1 downto 0);  -- Opcode of instruction received from host.
    oprndCntr_p   : out std_logic_vector(oprndCntrLength_g-1 downto 0);  -- Number of remaining operand bits that follow instruction.
    enable_p      : out std_logic;  -- True when an instruction has been received and while operand bits are arriving.
    bitStrobe_p   : out std_logic;  -- True when a bit is available from the host.
    bitFromHost_p : out std_logic;  -- Bit from the host to the FPGA application logic.
    bitToHost_p   : in  std_logic  -- Bit from the FPGA application logic to the host.
    );
end entity;


architecture arch of HostIo is
  -- Signals from BSCAN primitive.
  signal bscanDrck_s   : std_logic;
  signal bscanReset_s  : std_logic;
  signal bscanSel_s    : std_logic;
  signal bscanShift_s  : std_logic;
  signal bscanTdi_s    : std_logic;
  signal bscanUpdate_s : std_logic;
  signal bscanTdo_s    : std_logic;
  -- Combination of BSCAN reset and FPGA application logic reset.
  signal totalReset_s  : std_logic;
begin
  -- Boundary-scan interface to FPGA JTAG port.
  UBscanSpartan3A : BSCAN_SPARTAN3A
    port map(
      DRCK1  => bscanDrck_s,   -- JTAG clock after USER1 instruction received.
      DRCK2  => open,                   -- Not using USER2 instruction.
      RESET  => bscanReset_s,           -- JTAG TAP FSM reset.
      SEL1   => bscanSel_s,             -- USER1 instruction enables user-I/O.
      SEL2   => open,                   -- Not using USER2 instruction.
      SHIFT  => bscanShift_s,  -- True when JTAG TAP FSM is in the SHIFT-DR state.
      TDI    => bscanTdi_s,  -- Data bits from the host arrive through here.
      UPDATE => bscanUpdate_s,
      TDO1   => bscanTdo_s,  -- This goes to the TDO pin and back to the host.
      TDO2   => '0'          -- Not using this input, so just hold it low.
      );

  -- Reset the circuit if the JTAG resets or if a reset comes from somewhere in the FPGA. 
  totalReset_s <= bscanReset_s or reset_p;

  -- Connect the sync'ed BSCAN signals to the logic that extracts instructions and data from the JTAG bitstream.
  UHostIoCore : HostIoCore
    generic map (
      opcodeLength_g    => opcodeLength_g,
      oprndCntrLength_g => oprndCntrLength_g
      )
    port map (
      clk_p         => clk_p,
      drck_p        => bscanDrck_s,
      reset_p       => totalReset_s,
      sel_p         => bscanSel_s,
      shift_p       => bscanShift_s,
      tdi_p         => bscanTdi_s,
      update_p      => bscanUpdate_s,
      tdo_p         => bscanTdo_s,
      opcode_p      => opcode_p,
      oprndCntr_p   => oprndCntr_p,
      enable_p      => enable_p,
      bitStrobe_p   => bitStrobe_p,
      bitFromHost_p => bitFromHost_p,
      bitToHost_p   => bitToHost_p
      );
end architecture;


library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use UNISIM.VComponents.all;
use work.common.all;
use work.HostIoPckg.all;

entity HostIoToRamCore is
  generic (
    opcode_g : std_logic_vector := "11111111"  -- The opcode this module responds to.
    );
  port (
    reset_p       : in  std_logic;      -- Active-high reset signal.
    clk_p         : in  std_logic;  -- Fast clock from FPGA application logic. 
    -- Interface to HostIo.
    opcode_p      : in  std_logic_vector;  -- Opcode of instruction received from host.
    oprndCntr_p   : in  std_logic_vector;  -- Number of remaining operand bits that follow instruction.
    enable_p      : in  std_logic;  -- True when an instruction has been received and while operand bits are arriving.
    bitStrobe_p   : in  std_logic;  -- True when a bit is available from the host.
    bitFromHost_p : in  std_logic;  -- Bit from the host to the FPGA application logic.
    bitToHost_p   : out std_logic;  -- Bit from the FPGA application logic to the host.
    -- Interface to RAM.
    addrToRam_p   : out std_logic_vector;  -- Address to RAM.
    wrToRam_p     : out std_logic;      -- Write data to RAM when high.
    dataToRam_p   : out std_logic_vector;  -- Data written to RAM.
    rdFromRam_p   : out std_logic;      -- Read data from RAM when high.
    dataFromRam_p : in  std_logic_vector;  -- Data read from RAM.
    ramOpDone_p   : in  std_logic   -- High when read/write operation is done.
    );
end entity;


architecture arch of HostIoToRamCore is
  signal readOp_s           : boolean;
  signal writeOp_s          : boolean;
  signal selected_s         : boolean;
  signal addrFromHost_r     : std_logic_vector(addrToRam_p'range);
  signal addrFromHostRcvd_r : boolean;
  signal dataFromHost_r     : std_logic_vector(dataToRam_p'range);
  signal dataFromHostRcvd_r : boolean;
  signal dataToHost_r       : std_logic_vector(dataFromRam_p'range);
  signal bitCntr_r          : natural range 0 to dataToHost_r'length;
  signal wrToRam_r          : std_logic;
  signal dataToRam_r        : std_logic_vector(dataToRam_p'range);
  signal rdFromRam_r        : std_logic;
  signal dataFromRam_r      : std_logic_vector(dataFromRam_p'range);
  signal dataFromRamRcvd_r  : boolean;
begin
  readOp_s   <= opcode_p(0) = ONE;
  writeOp_s  <= opcode_p(0) = ZERO;
  selected_s <= (opcode_p(opcode_p'high downto 1) = opcode_g(0 to opcode_g'high-1)) and (enable_p = HI);

  process(clk_p)
  begin
    if rising_edge(clk_p) then
      if (selected_s or wrToRam_r = HI) and (reset_p = LO) then
        if addrFromHostRcvd_r then  -- Address received, so now it's all data transfers to/from RAM.
          
          if writeOp_s then  -- Operation is writing data to RAM that was received from the host.
            if dataFromHostRcvd_r then  -- Initiate writing of data received from the host into the RAM.
              dataToRam_r                         <= dataFromHost_r;  -- Store host data so it doesn't change if more bits arrive from host.
              wrToRam_r                           <= HI;  -- Initiate write of host data to RAM.
              -- Clear shift register so it can receive more data from the host.
              dataFromHost_r                      <= (others => ZERO);
              dataFromHost_r(dataFromHost_r'high) <= ONE;
              dataFromHostRcvd_r                  <= false;
            else  -- Shifting in data from host before writing it to RAM. 
              if bitStrobe_p = HI then
                dataFromHost_r     <= bitFromHost_p & dataFromHost_r(dataFromHost_r'high downto 1);
                dataFromHostRcvd_r <= dataFromHost_r(0) = ONE;
              end if;
              if ramOpDone_p = HI then  -- The write to RAM has finished. 
                wrToRam_r      <= LO;  -- Stop any further writes till another complete data word arrives from host.
                addrFromHost_r <= addrFromHost_r + 1;  -- Point to next RAM location to be written.
              end if;
            end if;

          else  -- Operation is reading data from RAM and sending it to host.
            if dataFromRamRcvd_r then
              if bitCntr_r = 0 then  -- Load the shift register to the host if it's empty.
                dataToHost_r      <= dataFromRam_r;  -- Load the data from RAM into the host shift register.
                bitCntr_r         <= dataToHost_r'length;  -- Set the number of data bits to send.
                addrFromHost_r    <= addrFromHost_r + 1;  -- Point to next RAM location to read from.
                rdFromRam_r       <= HI;  -- Initiate the next read from the RAM.
                dataFromRamRcvd_r <= false;  -- New data from RAM is not available yet.
              elsif bitStrobe_p = HI then  -- Shift data to the host if the register is not empty.
                dataToHost_r <= ZERO & dataToHost_r(dataToHost_r'high downto 1);  -- Shift register contents.
                bitCntr_r    <= bitCntr_r - 1;  -- One more bit has been sent to the host.
              end if;
            else                        -- No data is available from the RAM.
              rdFromRam_r <= HI;  -- By default, keep RAM read operation going.
              if ramOpDone_p = HI then  -- Data is available from RAM.
                rdFromRam_r       <= LO;  -- Stop the current RAM read operation.
                dataFromRam_r     <= dataFromRam_p;  -- Store the data from RAM.
                dataFromRamRcvd_r <= true;
              end if;
              if bitCntr_r /= 0 and bitStrobe_p = HI then  -- Shift data to the host if the register is not empty.
                dataToHost_r <= ZERO & dataToHost_r(dataToHost_r'high downto 1);  -- Shift register contents.
                bitCntr_r    <= bitCntr_r - 1;  -- One more bit has been sent to the host.
              end if;
            end if;
          end if;
          
        else                            -- Address from host is still arriving.
          addrFromHost_r     <= bitFromHost_p & addrFromHost_r(addrFromHost_r'high downto 1);
          addrFromHostRcvd_r <= addrFromHost_r(0) = ONE;  -- Address complete once LSB is set.
        end if;

      else  -- This module has not been selected, so reset everything.
        addrFromHost_r                      <= (others => ZERO);
        addrFromHost_r(addrFromHost_r'high) <= ONE;
        addrFromHostRcvd_r                  <= false;
        dataFromHost_r                      <= (others => ZERO);
        dataFromHost_r(dataFromHost_r'high) <= ONE;
        dataFromHostRcvd_r                  <= false;
        bitCntr_r                           <= dataToHost_r'length;
        wrToRam_r                           <= LO;
        rdFromRam_r                         <= LO;
        dataFromRamRcvd_r                   <= false;
      end if;
    end if;
  end process;

--  bitToHost_p <= dataToHost_r(0) when selected_s else LO;
  bitToHost_p <= ONE when addrFromHostRcvd_r else ZERO;
  addrToRam_p <= addrFromHost_r;
  wrToRam_p   <= wrToRam_r;
  dataToRam_p <= dataToRam_r;
  rdFromRam_p <= rdFromRam_r;
end architecture;

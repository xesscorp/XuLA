# 
# set_process_props
# 
# This procedure sets properties as requested during script generation (either
# all of the properties, or only those modified from their defaults).
# 
project set "Unused IOB Pins" "Float" -process "Generate Programming File"
project set "FPGA Start-Up Clock" "JTAG Clock" -process "Generate Programming File"
project set "Allow Unmatched LOC Constraints" "true" -process "Translate"
project set "Allow Unmatched Timing Group Constraints" "true" -process "Translate"


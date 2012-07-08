// system calls ///////////////////////////////////////////
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>


// 3rd party stuff ////////////////////////////////////////
#include "gtest/gtest.h"

// my code ////////////////////////////////////////////////
#include "log/log.h"
#if 0
class cfg_t {
public:
  // Member variables

  // CFG Offsets
  unsigned int   pm_offset;                      // Power Management Offset
  unsigned int   msi_offset;                     // MSI Offset
  unsigned int   pcie_cap_offset;                // PCIE Cap Offset
  unsigned int   device_cap_offset;              // Device CAP offset
  unsigned int   device_stat_cont_offset;        // Device Stat/Control Offset
  unsigned int   link_cap_offset;                // Link Cap Offset
  unsigned int   link_stat_cont_offset;          // Link Stat/Control Offset

  // CFG Register Values
  unsigned int   link_width_cap;      
  unsigned int   link_speed_cap;
  unsigned int   link_width;
  unsigned int   link_speed;
  unsigned int   link_control;
  unsigned int   pm_stat_control;
  unsigned int   pm_capabilities;
  unsigned int   msi_control;

  char*          link_stat_neg_link_speed_c;     // char* containing negotiated link speed
  unsigned int   link_stat_neg_link_speed;       // int containing negotiated link speed
  char*          link_stat_neg_link_width_c;     // char* containing negotiated link width
  unsigned int   link_stat_neg_link_width;       // int containing negotiated link speed
  const char*    cfg_fatal_text;                 // Contains text stating error condition if BMD fails during setup 
                                                 // of transfer
  // constructor and destructor
  cfg_t(void);
  ~cfg_t(void);

  // Reads CFG registers for display to GUI
  int cfg_read_regs(int g_devFile);

  // Read/Writes CFG space - not currently used
  int cfg_rdwr_reg(int g_devFile,int reg, int reg_value, int wr_en);

  // Enables specific functionality within EP configuration space (Phantom Functions, Extended Tags, Error Reporting
  int cfg_enable_functionality(int g_devFile, int dev_ctrl_phantom_func_en, int dev_ctrl_extended_tag_en, int error_reporting_en);

  // Checks link width and link speed
  int cfg_check_link_width(int g_devFile);
  int cfg_check_link_speed(int g_devFile);

  int cfg_get_capabilities(int g_devFile);
  int cfg_update_regs(int g_devFile);
};

class bmd_t {
public:
  int wr_mbps;                     // Contains Write Performance.  SUM of total performance per run (not iteration)
  int rd_mbps;                     // Contains Read Performance.  SUM of total performance per run (not iteration)
  const char* wr_result_text;      // Contains text stating success of WR DMA or error condition if one exists
  const char* rd_result_text;      // Contains text stating success of RD DMA or error condition if one exists
  const char* bmd_fatal_text;      // Contains text stating error condition if BMD fails during setup of transfer
  bool wr_success;                 // Bool declaring if Write DMA was successful
  bool rd_success;                 // Bool declaring if Read DMA was successful 
  char* wr_mbps_c;                 // Char string showing performance that is passed to GUI WR MBPS field
  char* rd_mbps_c;                 // Char string showing performance that is passed to GUI RD MBPS field

  // Constructor and destructor prototypes
  bmd_t(void);
  ~bmd_t(void);
   
  // run_xbmd sets up and runs a single DMA iteration.  It takes in a global struct containing descriptor 
  // register values needed to set up transfer
  int run_xbmd(xbmd_descriptors_t xbmd_descriptors, int ii);

  // Gets Read and Write performance values and returns a char string containing the average performance for 
  // and entire DMA run (multiple iterations)
  char* get_rd_mbps(int iter_count);
  char* get_wr_mbps(int iter_count);

  // Returns a boolean for write and/or read stating whether a DMA transfer was successful or not.  Used to identify 
  // if a failure has occurred in a single DMA transfer during a run.
  bool get_wr_success(void);
  bool get_rd_success(void);

  // Returns a const char* stating whether the transfer was successful or not.  Result is provided displayed into 
  // GUI under status fields
  const char* get_wr_result_text(void);
  const char* get_rd_result_text(void);

  // Reads BMD descriptor registers for display to GUI
  int read_bmd_regs(int g_devFile);
};

class xbmd_ep_t {
public:
  //The BMD class contains variables and member functions needed
  //to access the XBMD backend application.  Block Memory Device?
  bmd_t bmd;

  // The CFG class contains variables and member functions needed to
  // access the EP configuration space
  cfg_t cfg;

   xbmd_ep_t(void);
   ~xbmd_ep_t(void);
};

struct xbmd_descriptors_t{

  int               num_iter;               // Number of Iterations
  unsigned int      wr_enable;              // Write Enable
  unsigned int      rd_enable;              // Read Enable
  int               wr_tlp_size;            // Write TLP Size
  int               rd_tlp_size;            // Read TLP Size 
  int               num_wr_tlps;            // Number of Write TLP's
  int               num_rd_tlps;            // Number of Read TLP's
  const char*       wr_pattern_new;         // Write Pattern
  const char*       rd_pattern_new;         // Read Pattern

  char*             iter_count_t;           // Number of Iterations text
  char*             wr_bytes_to_trans;      // Number of Write Bytes to Transfer
  char*             rd_bytes_to_trans;      // Number of Read Bytes to Transfer
  int               bytes_to_trans;         // Temporary Bytes to Transfer (int)
  bool              wr_pattern_valid;       // Write Pattern Valid
  bool              rd_pattern_valid;       // Read Pattern Valid
  int               wr_pattern_length;      // Write Pattern Length
  int               rd_pattern_length;      // Read Pattern Length 

  const char*       wr_status;              // Write Status text
  const char*       rd_status;              // Read Status text 
  char*             wr_mbps;                // Write Performance text 
  char*             rd_mbps;                // Read Performance text

  bool              phantom_enable;         // Phantom Functions enable
  bool              aut_change_enable;      // Autonomous Change enable 
  bool              trans_streaming;        // Transmit Streaming enable 
  int               random_enable;          // Randomization enable 

  unsigned int      pm_offset;              // Power Management CAP Offset
  unsigned int      msi_offset;             // MSI CAP offset
  unsigned int      pcie_cap_offset;        // PCIE CAP offset
  unsigned int      device_cap_offset;      // Device CAP offset
  unsigned int      device_stat_cont_offset;// Device Status/Control offset
  unsigned int      link_cap_offset;        // Link CAP offset
  unsigned int      link_stat_cont_offset;  // Link Status/Control offset

  char*             neg_link_width_char;    // Negotiated Link Width (char*)
  char*             neg_link_speed_char;    // Negotiated Link Speed (char*)
  int               neg_link_width;         // Negotiated Link Width (int)
  int               neg_link_speed;         // Negotiated Link Spee (int)

  int               g_devFile;              // Device file number

  //Constructor - handles initialization of all variables
  xbmd_descriptors_t() {
   
    // Number of iterations
    num_iter = 1;
    iter_count_t= new char[10];

    // Write/Read TLP Size
    wr_tlp_size = 32;
    rd_tlp_size = 32;

    // Write/Read # TLP's
    num_wr_tlps = 32;               
    num_rd_tlps = 32;

    // Write/Read # bytes to trans
    wr_bytes_to_trans = new char[1];
    rd_bytes_to_trans = new char[1];
    bytes_to_trans = 000000;

    // Write/Read Pattern variables
    wr_pattern_valid = true;
    rd_pattern_valid = true;
    wr_pattern_length = 0;
    rd_pattern_length = 0;
    wr_pattern_new = "FEEDBEEF";
    rd_pattern_new = "FEEDBEEF";

    // Write/Read DMA Enable
    rd_enable = 0x00000000;
    wr_enable = 0x00000000;

    // Write/Read Performance
    rd_mbps = new char[1];
    wr_mbps = new char[1];

    // DMA additional option variables
    phantom_enable = false;
    aut_change_enable = false;
    trans_streaming = false;
    random_enable = 0;

    // CFG Space Capabilities offsets
    pm_offset                  = 0;               
    msi_offset                 = 0;
    pcie_cap_offset            = 0; 
    device_cap_offset          = 0; 
    device_stat_cont_offset    = 0; 
    link_cap_offset            = 0; 
    link_stat_cont_offset      = 0;     

    g_devFile = -1;
    //initialize all variables here with values below and then erase below values
  }
};

xbmd_ep_t xbmd_ep;/* xbmd_ep_t is our Endpoint class type which aggregates
		     the two major components of a Xilinx PCIe EP design:
		     bmd and cfg */
xbmd_descriptors_t
xbmd_descriptors;/* global structure containing all globals
		    related to the backend XBMD descriptor
		    registers.  global to allow access to
		    all variables within different callback
		    functions (handlers) */
#endif //0



TEST(ThroughputTest, Read) {
  int g_devFile = open("/dev/xdma", O_RDWR);
  ASSERT_GE(g_devFile, 0);

  ASSERT_EQ(close(g_devFile), 0);
}

int main(int argc, char* argv[]) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}

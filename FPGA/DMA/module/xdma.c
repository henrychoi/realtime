#include <linux/init.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/interrupt.h>
#include <linux/fs.h>
//#include <linux/pci-aspm.h>
//#include <linux/pci_regs.h>

#include <asm/uaccess.h>   /* copy_to_user */

#include "xdma.h"

// semaphores
enum  {
  SEM_READ,
  SEM_WRITE,
  SEM_WRITEREG,
  SEM_READREG,
  SEM_WAITFOR,
  SEM_DMA,
  NUM_SEMS
};

//semaphores
struct semaphore gSem[NUM_SEMS];

MODULE_LICENSE("Dual BSD/GPL");

#define VENDOR_ID 0x10ee // This means Xilinx
#define DEVICE_ID 0x6018 // Set this way during HW core definition

#define XDMA_REGISTER_SIZE (4*8) // 8 4-byte registers
#define HAVE_REGION        0x01  // I/O Memory region
#define HAVE_IRQ           0x02  // Interupt

//Status Flags: 
//       1 = Resouce successfully acquired
//       0 = Resource not acquired.      
#define HAVE_REGION 0x01                    // I/O Memory region
#define HAVE_IRQ    0x02                    // Interupt
#define HAVE_KREG   0x04                    // Kernel registration

int           gDrvrMajor = 241;           // Major number not dynamic.
struct pci_dev *gDev = NULL; // PCI device structure.
char            gDrvrName[]= "xdma";       // Name of driver

void XPCIe_IRQHandler(int irq, void *dev_id, struct pt_regs *regs)
{
  printk(KERN_WARNING"%s: IRQ %d", gDrvrName, irq);
}

void XPCIe_InitCard(void)
{
  printk(KERN_INFO"%s %s\n", gDrvrName, __PRETTY_FUNCTION__);
}

//Performs all cleanup functions required before releasing device
static void XPCIe_exit(void)
{
  printk(KERN_ALERT"%s %s\n", gDrvrName, __PRETTY_FUNCTION__);
}

static int XPCIe_init(void)
{
  // Find the Xilinx EP device by matching device and vendor IDs
  gDev = pci_get_device(VENDOR_ID, DEVICE_ID, gDev);
  if (NULL == gDev) {
    printk(KERN_WARNING"%s %s pci_get_device(%X,%X) failed.\n"
	   , gDrvrName, __PRETTY_FUNCTION__, VENDOR_ID, DEVICE_ID);
    return (-1);
  }

  return 0;
}

module_init(XPCIe_init);// Driver Entry Point
module_exit(XPCIe_exit);// Driver Exit Point

// file opearations /////////////////////////////////////////////////
int XPCIe_Open(struct inode *inode, struct file *filp)
{
  printk(KERN_INFO"%s: Open: module opened\n",gDrvrName);
  return 0;
}

int XPCIe_Release(struct inode *inode, struct file *filp)
{
  printk(KERN_INFO"%s: Release: module released\n",gDrvrName);
  return 0;
}

long XPCIe_Ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{
  long ret = 0;
  printk(KERN_INFO"%s %s(..., %X, %p)\n"
	 , gDrvrName, __PRETTY_FUNCTION__, cmd, (void*)arg);
  return ret;
}

ssize_t XPCIe_Read(struct file *filp, char *buf, size_t count, loff_t *f_pos)
{
  printk(KERN_INFO"%s %s(..., %zd, %p)\n"
	 , gDrvrName, __PRETTY_FUNCTION__, count, f_pos);
  return 0;
}

ssize_t XPCIe_Write(struct file *filp, const char *buf, size_t count,
		    loff_t *f_pos)
{
  printk(KERN_INFO"%s %s(..., %zd, %p)\n"
	 , gDrvrName, __PRETTY_FUNCTION__, count, f_pos);
  return 0;
}

struct file_operations XPCIe_Intf = {
 read:       XPCIe_Read,
 write:      XPCIe_Write,
 unlocked_ioctl: XPCIe_Ioctl,
 open:       XPCIe_Open,
 release:    XPCIe_Release,
};



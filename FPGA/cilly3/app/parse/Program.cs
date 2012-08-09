using System;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace parse
{
    class Program
    {
        static void Main(string[] args)
        {
            string binfn = args.Length > 0 ? args[0] : "cl_raw.bin";
            string outfn = args.Length > 1 ? args[1] : null;
            StreamWriter outf = new StreamWriter(outfn);
            Stream binf = File.OpenRead(binfn);
            outf.WriteLine(
                "n_msg,tx_state,FVAL,LVAL,new frame,new line,n_full,n_line,n_clk,remainder");

            byte[] buffer = new byte[4];
            int bytesRead = 0, n_msg = 0, rc;

            while ((rc = binf.Read(buffer, bytesRead, 4)) > 0)
            {
                bytesRead += rc;
                if (bytesRead < 4) continue;
                int tx_state = buffer[3] >> 6;
                int n_full = (buffer[3] & 0x03);
                int n_line = ((int)buffer[2] << 4) + (buffer[1] >> 4);
                int n_clk = ((int)(buffer[1] & 0xF) << 8) + buffer[0];
                int FVAL = (buffer[3] & 0x20) != 0 ? 1 : 0;
                int LVAL = (buffer[3] & 0x10) != 0 ? 1 : 0;
                int new_frame = tx_state == 1 ? ((buffer[3] & 0x08) != 0 ? 1 : 0) : -1;
                int new_line = tx_state == 1 ? ((buffer[3] & 0x04) != 0 ? 1 : 0) : -1;
                int remainder = (tx_state == 2 && LVAL == 0) ? 1 : 0;
                outf.WriteLine("{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}", n_msg
                    , tx_state, FVAL, LVAL, new_frame, new_line, n_full, n_line, n_clk
                    , remainder);
                ++n_msg;
                bytesRead = 0;
            }
            binf.Close();
            outf.Close();
            Console.WriteLine("Parsed {0} lines.", n_msg);
        }
    }
}

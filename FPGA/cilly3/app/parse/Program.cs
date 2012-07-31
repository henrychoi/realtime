﻿using System;
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
            outf.WriteLine("n_msg,tx_state,new frame,new line,FVAL,LVAL,n_full,n_line,n_clk");

            byte[] buffer = new byte[4];
            int bytesRead = 0, n_msg = 0, rc;
            int tx_state, n_full, n_line, n_clk, FVAL, LVAL;
            bool new_frame, new_line;

            while ((rc = binf.Read(buffer, bytesRead, 4)) > 0)
            {
                bytesRead += rc;
                if (bytesRead < 4) continue;
                tx_state = buffer[3] >> 6;
                n_full = (buffer[3] & 0x03);
                n_line = ((int)buffer[2] << 4) + (buffer[1] >> 4);
                n_clk = ((int)(buffer[1] & 0xF) << 8) + buffer[0];
                new_frame = (buffer[3] & 0x20) != 0;
                new_line = (buffer[3] & 0x10) != 0;
                FVAL = tx_state == 1 ? ((buffer[3] & 0x08) != 0 ? 1 : 0) : -1;
                LVAL = tx_state == 1 ? ((buffer[3] & 0x04) != 0 ? 1 : 0) : -1;
                outf.WriteLine("{0},{1},{2},{3},{4},{5},{6},{7},{8}", n_msg
                    , tx_state, new_frame ? 1 : 0, new_line ? 1:0
                    , FVAL, LVAL, n_full, n_line, n_clk);
                ++n_msg;
                bytesRead = 0;
            }
            binf.Close();
            outf.Close();
            Console.WriteLine("Parsed {0} lines.", n_msg);
        }
    }
}

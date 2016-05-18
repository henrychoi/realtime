package com.earthinyourhand.lyla1;

public interface Msgable {
    void flushTX();
    void onTargetMsg(TargetMsg m);
}

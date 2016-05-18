package com.earthinyourhand.lyla1;

import android.os.Parcel;
import android.os.Parcelable;

public class TargetMsg implements Parcelable {
    public byte typ; //See MsgType
    public int[] data = new int[2];

    public static final Parcelable.Creator<TargetMsg> CREATOR = new Parcelable.Creator<TargetMsg>() {
        @Override
        public TargetMsg createFromParcel(Parcel parcel) {
            TargetMsg m = new TargetMsg();
            m.typ = parcel.readByte();
            m.data[0] = parcel.readInt();
            m.data[1] = parcel.readInt();
            return m;
        }

        @Override
        public TargetMsg[] newArray(int size) {
            return new TargetMsg[size];
        }
    };

    @Override
    public int describeContents() { return 0; }

    @Override
    public void writeToParcel(Parcel parcel, int flags) {
        parcel.writeByte(typ);
        parcel.writeInt(data[0]);
        parcel.writeInt(data[1]);
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        TargetMsg that = (TargetMsg)o;
        return typ == that.typ
                && data[0] == that.data[0]
                && data[1] == that.data[1]
                ;
    }

}

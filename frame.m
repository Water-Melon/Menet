Str = Import('str');

@FrameParse(&data) {
    len = Str.strlen(data);
    ret = '';

    while (true) {
        if (len < 2) {
            return false;
        } fi
        lh = Str.s2b(data[0], 'int');
        ll = Str.s2b(data[1], 'int');
        if (!ret && !(lh & 0x80)) {
            return false;
        } fi
        l = (ll & 0xff) | ((lh & 0x2f) << 8);
        if (len - 2 < l) {
            return false;
        } fi
        ret += Str.split(data, 2, l);
        data = Str.split(data, l + 2);
        len -= (l + 2);
        if (lh & 0x40)
            break;
        fi
    }
    return ret;
}

@FrameGenerate(&data) {
    len = Str.strlen(data);
    frame = '';
    lh = 0x80;
    while (len) {
        if (len < 16384) {
            lh |= (0x40 | ((len >> 8) & 0xff));
            ll = len & 0xff;
            len = 0;
            frame += (Str.b2s(lh)[0] + Str.b2s(ll)[0] + data);
            data = '';
        } else {
            lh |= 0x2f;
            ll |= 0xff;
            len -= 16383;
            frame += (Str.b2s(lh)[0] + Str.b2s(ll)[0] + Str.split(data, 0, 16383));
            data = Str.split(data, 16383);
        }
        lh = 0;
    }

    return frame;
}


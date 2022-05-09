@frameParse(&data) {
    len = _mln_strlen(data);
    ret = '';

    while (true) {
        if (len < 2) {
            return false;
        } fi
        lh = _mln_s2b(data[0], 'int');
        ll = _mln_s2b(data[1], 'int');
        if (!ret && !(lh & 0x80)) {
            return false;
        } fi
        l = (ll & 0xff) | ((lh & 0x2f) << 8);
        if (len - 2 < l) {
            return false;
        } fi
        ret += _mln_split(data, 2, l);
        data = _mln_split(data, l + 2);
        len -= (l + 2);
        if (lh & 0x40)
            break;
        fi
    }
    return ret;
}

@frameGenerate(&data) {
    len = _mln_strlen(data);
    frame = '';
    lh = 0x80;
    while (len) {
        if (len < 16384) {
            lh |= (0x40 | ((len >> 8) & 0xff));
            ll = len & 0xff;
            len = 0;
            frame += (_mln_b2s(lh)[0] + _mln_b2s(ll)[0] + data);
            data = '';
        } else {
            lh |= 0x2f;
            ll |= 0xff;
            len -= 16383;
            frame += (_mln_b2s(lh)[0] + _mln_b2s(ll)[0] + _mln_split(data, 0, 16383));
            data = _mln_split(data, 16383);
        }
        lh = 0;
    }

    return frame;
}


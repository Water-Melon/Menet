#include "frame.m"

conf = mln_json_decode(EVAL_DATA);
fd = conf['fd'];

rbuf = mln_tcp_recv(fd, 3000);
if (mln_is_bool(rbuf) || mln_is_nil(rbuf)) {
    mln_tcp_close(fd);
    return;
} fi
ret = frameParse(rbuf);
if (!ret) {
    mln_tcp_close(fd);
    return;
} fi

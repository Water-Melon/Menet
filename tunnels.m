#include "frame.m"
#include "common.m"

conf = mln_json_decode(EVAL_DATA);
fd = conf['fd'];
hash = conf['hash'];

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
ret = mln_json_decode(ret);
name = ret['data'];

ret = mln_tcp_send(fd, frameGenerate(mln_json_encode([
    'code': 200,
    'msg': 'OK',
])));
if (!ret) {
    mln_tcp_close(fd);
    return;
} fi

mln_msg_queue_send('manager', mln_json_encode([
    'type': 'tunnel',
    'op': 'update',
    'from': conf['hash'],
    'data': [
        'name': name,
        'dest': nil,
    ],
]));

tunnelLoop(fd, hash, name);

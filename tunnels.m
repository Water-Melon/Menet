#include "frame.m"

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

serviceName = ret['data'];

mln_msg_queue_send('manager', mln_json_encode([
    'type': 'tunnel',
    'op': 'update',
    'from': conf['hash'],
    'data': [
        'name': serviceName,
        'dest': nil,
    ],
]));

ret = mln_msg_queue_recv(hash);
mln_print(ret);

#include "common.m"

json = Import('json');
net = Import('net');
mq = Import('mq');
sys = Import('sys');

conf = json.decode(EVAL_DATA);
fd = conf['fd'];
hash = conf['hash'];

rbuf = net.tcp_recv(fd, 3000);
if (sys.is_bool(rbuf) || sys.is_nil(rbuf)) {
    net.tcp_close(fd);
    return;
} fi
ret = FrameParse(rbuf);
if (!ret) {
    net.tcp_close(fd);
    return;
} fi
ret = json.decode(ret);
name = ret['data'];

ret = net.tcp_send(fd, FrameGenerate(json.encode([
    'code': 200,
    'msg': 'OK',
])));
if (!ret) {
    net.tcp_close(fd);
    return;
} fi

mq.send('manager', json.encode([
    'type': 'tunnel',
    'op': 'update',
    'from': conf['hash'],
    'data': [
        'name': name,
        'dest': nil,
    ],
]));

TunnelLoop(fd, hash, name, rbuf);

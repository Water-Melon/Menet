#include "common.m"

json = import('json');
net = import('net');
mq = import('mq');

conf = json.decode(EVAL_DATA);
fd = conf['fd'];
hash = conf['hash'];

rbuf = net.tcp_recv(fd, 3000);
if (sys.is_bool(rbuf) || sys.is_nil(rbuf)) {
    net.tcp_close(fd);
    return;
} fi
ret = frameParse(rbuf);
if (!ret) {
    net.tcp_close(fd);
    return;
} fi
ret = json.decode(ret);
name = ret['data'];

ret = net.tcp_send(fd, frameGenerate(json.encode([
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

tunnelLoop(fd, hash, name, rbuf);

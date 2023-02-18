#include "common.m"

Json = Import('json');
Mq = Import('mq');
Net = Import('net');
Sys = Import('sys');

conf = Json.decode(EVAL_DATA);

@BadRequest(from) {
    Mq.send(from, Json.encode([
        'code': 400,
        'msg': 'Bad Request'
    ]));
}
fd = Net.tcp_connect(conf['dest'][0], conf['dest'][1], 1000);
if (Sys.is_bool(fd) || Sys.is_nil(fd)) {
    BadRequest(conf['from']);
    return;
} fi
hash = conf['hash'];

ret = Net.tcp_send(fd, FrameGenerate(Json.encode([
    'type': 'sync',
    'from': nil,
    'to': nil,
    'data': conf['name'],
])));
if (!ret) {
    BadRequest(conf['from']);
    Net.tcp_close(fd);
    return;
} fi

rbuf = Net.tcp_recv(fd, 3000);
if (Sys.is_bool(rbuf) || Sys.is_nil(rbuf)) {
    BadRequest(conf['from']);
    Net.tcp_close(fd);
    return;
} fi
ret = FrameParse(rbuf);
if (!ret) {
    BadRequest(conf['from']);
    Net.tcp_close(fd);
    return;
} fi

Mq.send('manager', Json.encode([
    'type': 'tunnelConnected',
    'op': nil,
    'from': hash,
    'data': [
        'name': conf['name'],
        'dest': conf['dest'],
    ],
]));

ret = Mq.recv(hash);
Mq.send(conf['from'], ret);
ret = Json.decode(ret);
if (ret['code'] != 200) {
    Net.tcp_close(fd);
    return;
} fi

TunnelLoop(fd, hash, conf['name'], rbuf);

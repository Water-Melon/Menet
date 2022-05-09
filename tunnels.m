#include "frame.m"

@cleanMsg(hash) {
    cnt = 0;
    while (cnt < 30) {
        ret = _mln_msg_queue_recv(hash, 100000);
        if (!ret)
            ++cnt;
        else
            cnt = 0;
    }
}

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
        'name': serviceName,
        'dest': nil,
    ],
]));

while (true) {
    msg = mln_msg_queue_recv(hash, 10000);
    if (msg) {
        msg = mln_json_decode(msg);
        switch(msg['op']) {
            case 'remove':
                mln_tcp_close(fd);
                if (msg['from']) {
                    mln_msg_queue_send(msg['from'], mln_json_encode([
                        'code': 200,
                        'msg': "OK",
                    ]));
                } fi
                cleanMsg(hash);
                return;
            default:
                break;
        }
    } fi

    //TODO I/O and exception status update
}
